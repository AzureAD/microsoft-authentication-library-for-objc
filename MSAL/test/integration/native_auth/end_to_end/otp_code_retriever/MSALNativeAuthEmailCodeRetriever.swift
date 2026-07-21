//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  

import Foundation

/// Retrieves email OTP codes from the mail.tm disposable-email service (https://docs.mail.tm).
///
/// mail.tm is a token-based API: an account (address + password) must exist, then a
/// bearer token is obtained and used to read messages.
///
/// The client is stateful and intended to be shared across a test suite: call `markCheckpoint()`
/// right before triggering an OTP send, then `readOtpCode()` to fetch the resulting code.
class MSALNativeAuthEmailCodeRetriever {

    private let httpClient = MailTMHTTPClient(baseURLString: MailTMConstants.baseURL)

    private var address: String?
    private var password: String?
    private var token: String?
    private var domain: String?
    private var lastCheckedTime: Date?

    // MARK: - Account setup

    /// Connects to an existing mail.tm mailbox by logging in. Returns true on success.
    @discardableResult
    func connectToExistingAccount(address: String, password: String) async -> Bool {
        return await login(address: address, password: password) != nil
    }

    /// Creates a brand-new mail.tm mailbox and authenticates to it. Returns the created address.
    /// Used by sign-up flows (currently skipped, kept for parity with the reference client).
    func createAuthenticatedAccount(password: String) async -> String? {
        guard let createdAccount = await createInbox(address: nil, password: password) else {
            return nil
        }
        guard await login(address: createdAccount, password: password) != nil else {
            return nil
        }
        return createdAccount
    }

    /// Generates a random address for sign-up flows (does not create the mailbox).
    func generateRandomEmailAddress() -> String {
        let randomId = UUID().uuidString.prefix(8).lowercased()
        return "\(MailTMConstants.signupAddressPrefix)\(randomId)@\(MailTMConstants.signupDomain)"
    }

    // MARK: - Checkpointing

    /// Records the current time so `readOtpCode()` ignores messages received earlier.
    /// Call this before triggering the action that sends the OTP email.
    func markCheckpoint() {
        let now = Date()
        lastCheckedTime = now
        print("Checkpoint marked at: \(ISO8601DateFormatter().string(from: now))")
    }

    // MARK: - mail.tm API

    private func fetchDomain() async -> String? {
        guard let result = await httpClient.sendJSON(path: MailTMConstants.Path.domains) else {
            return nil
        }
        guard result.status == MailTMConstants.Status.ok else {
            return nil
        }
        let json = result.json as? [String: Any]
        let members = json?[MailTMConstants.JSONKey.hydraMember] as? [[String: Any]]
        guard let fetched = members?.first?[MailTMConstants.JSONKey.domain] as? String else {
            return nil
        }
        domain = fetched
        print("Fetched domain: \(fetched)")
        return fetched
    }

    /// Creates a mail.tm inbox. When `address` is nil a random address on the fetched domain is used.
    private func createInbox(address requestedAddress: String?, password requestedPassword: String) async -> String? {
        var useAddress = requestedAddress
        if useAddress == nil {
            var resolvedDomain = domain
            if resolvedDomain == nil {
                resolvedDomain = await fetchDomain()
            }
            guard let resolvedDomain = resolvedDomain else {
                return nil
            }
            useAddress = "\(MailTMConstants.createInboxAddressPrefix)\(Int(Date().timeIntervalSince1970 * 1000))@\(resolvedDomain)"
        }
        guard let finalAddress = useAddress else {
            return nil
        }
        guard let result = await httpClient.sendJSON(
            path: MailTMConstants.Path.accounts,
            method: MailTMHTTPClient.HTTPMethod.post,
            jsonBody: [MailTMConstants.JSONKey.address: finalAddress, MailTMConstants.JSONKey.password: requestedPassword]
        ) else {
            return nil
        }
        // 201 created, 422 already exists — both mean the mailbox is usable.
        guard result.status == MailTMConstants.Status.created || result.status == MailTMConstants.Status.unprocessableEntity else {
            print("Failed to create mail.tm account: \(result.status) status code")
            return nil
        }
        address = finalAddress
        password = requestedPassword
        print("Account ready.")
        return finalAddress
    }

    private func login(address loginAddress: String, password loginPassword: String) async -> String? {
        guard let result = await httpClient.sendJSON(
            path: MailTMConstants.Path.token,
            method: MailTMHTTPClient.HTTPMethod.post,
            jsonBody: [MailTMConstants.JSONKey.address: loginAddress, MailTMConstants.JSONKey.password: loginPassword]
        ) else {
            return nil
        }
        guard result.status == MailTMConstants.Status.ok else {
            print("Failed to get token from mail.tm: \(result.status) status code")
            return nil
        }
        let json = result.json as? [String: Any]
        guard let receivedToken = json?[MailTMConstants.JSONKey.token] as? String else {
            return nil
        }
        token = receivedToken
        address = loginAddress
        password = loginPassword
        print("Authentication token received.")
        return receivedToken
    }

    private func getMessageSource(messageId: String) async -> String? {
        guard let token = token else {
            return nil
        }
        guard let result = await httpClient.sendJSON(
            path: MailTMConstants.Path.sources + messageId,
            authorizationToken: token
        ) else {
            return nil
        }
        guard result.status == MailTMConstants.Status.ok else {
            return nil
        }
        let json = result.json as? [String: Any]
        guard let source = json?[MailTMConstants.JSONKey.data] as? String else {
            print("'data' field not found in message source response.")
            return nil
        }
        return extractOTPCode(from: source)
    }

    /// Reads messages (newest checked first), skipping any received at or before the checkpoint,
    /// and returns the first OTP code found. On a successful read the checkpoint is advanced to the
    /// matched message's timestamp so subsequent reads (including retry flows) only consider newer
    /// messages and never return the same stale OTP again.
    func readOtpCode(maxRetries: Int = 3) async -> String? {
        guard token != nil else {
            print("Call connectToExistingAccount()/login() before reading messages")
            return nil
        }
        let executor = RetryExecutor(delays: MailTMConstants.progressiveDelays)
        let code = await executor.execute(maxAttempts: maxRetries) {
            await self.attemptReadOtpCode()
        }
        if code == nil {
            print("Failed to find OTP code after \(maxRetries) attempts")
        }
        return code
    }

    /// Performs a single polling pass: returns the first fresh OTP code (advancing the checkpoint)
    /// or nil when no new message yields a code yet.
    private func attemptReadOtpCode() async -> String? {
        guard let messages = await fetchMessages() else {
            return nil
        }
        for message in messages {
            let messageTime = messageDate(from: message)
            if let checkpoint = lastCheckedTime, messageTime <= checkpoint {
                continue
            }
            guard let messageId = message[MailTMConstants.JSONKey.id] as? String else {
                continue
            }
            if let code = await getMessageSource(messageId: messageId) {
                lastCheckedTime = messageTime
                return code
            }
        }
        return nil
    }

    // MARK: - Message fetching & parsing

    private func fetchMessages() async -> [[String: Any]]? {
        guard let token = token else {
            return nil
        }
        guard let result = await httpClient.sendJSON(
            path: MailTMConstants.Path.messages,
            authorizationToken: token
        ) else {
            return nil
        }
        guard result.status == MailTMConstants.Status.ok else {
            return nil
        }
        let json = result.json as? [String: Any]
        guard var messages = json?[MailTMConstants.JSONKey.hydraMember] as? [[String: Any]] else {
            return nil
        }
        // Newest first so the most recent OTP is considered before older ones.
        messages.sort(by: { messageDate(from: $0) > messageDate(from: $1) })
        return messages
    }

    /// Extracts the OTP code from the raw email source.
    /// Prefers the explicit "Account verification code: <digits>" wording (mirroring the reference client),
    /// then falls back to the first standalone 4-8 digit sequence.
    private func extractOTPCode(from source: String) -> String? {
        if let match = firstMatch(in: source, pattern: MailTMConstants.OTPPattern.explicit, group: 1) {
            return match
        }
        return firstMatch(in: source, pattern: MailTMConstants.OTPPattern.fallback, group: 1)
    }

    private func firstMatch(in text: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > group,
              let matchRange = Range(match.range(at: group), in: text) else {
            return nil
        }
        return String(text[matchRange])
    }

    private func messageDate(from message: [String: Any]) -> Date {
        let dateString = (message[MailTMConstants.JSONKey.updatedAt] as? String) ?? (message[MailTMConstants.JSONKey.createdAt] as? String)
        guard let dateString = dateString, let date = parseISO8601(dateString) else {
            return .distantPast
        }
        return date
    }

    /// Parses an ISO 8601 timestamp, tolerating both fractional-seconds (e.g. `...34.391Z`, which
    /// mail.tm returns) and whole-second forms.
    private func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }
}
