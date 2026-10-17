//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

import Foundation

/// Registers MFA accounts and retrieves and responds to pending sign-in requests.
public final class MSALNativeAuthMfaSdkManager: Sendable {
    internal let deviceTokenManager = MSALNativeAuthMfaSdkDeviceTokenManager()

    public init() {}

    // TODO: Replace these temporary local responses with registration and notification service calls.

    /// Supplies the latest APNs token and updates the push destination of existing MFA registrations.
    /// Call for every successful APNs registration callback, including when no accounts have been added yet.
    /// Supply raw token bytes and the environment matching the hosting app's signed entitlement.
    /// This does not request notification permission or register a new account.
    /// Throws if the update cannot be completed. Callers must not log the token.
    /// Retains the token/environment in memory for this manager instance. Reuse this instance for activation.
    /// Throws `MSALNativeAuthMfaSdkPushRegistrationError.invalidDeviceToken` for an empty token.
    public func updatePushRegistration(
        deviceToken: Data,
        apnsEnvironment: MSALNativeAuthMfaSdkAPNsEnvironment
    ) async throws {
        try await deviceTokenManager.update(deviceToken: deviceToken, environment: apnsEnvironment)
        // TODO: Reconcile service registrations and retry pending synchronization.
    }

    /// Registers an account using either decoded QR text or manually entered account details.
    /// Throws if registration cannot be completed. QR payloads, secret keys, and device tokens are not included in the result.
    /// QR activation requires an awaited `updatePushRegistration` on this instance first, otherwise
    /// throws `MSALNativeAuthMfaSdkPushRegistrationError.missingPushRegistration`.
    public func registerAuthMethod(
        registrationParameters: MSALNativeAuthMfaSdkRegistrationParameters
    ) async throws -> MSALNativeAuthMfaSdkRegistrationResult {
        try Task.checkCancellation()
        if registrationParameters.qrCode != nil {
            _ = try await deviceTokenManager.registration()
        }
        return MSALNativeAuthMfaSdkRegistrationResult(
            registrationId: UUID().uuidString,
            accountName: registrationParameters.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Example account"
        )
    }

    /// Retrieves pending sign-in requests. An empty array means there are no pending requests.
    /// Throws if the requests cannot be retrieved.
    public func pullPendingNotifications() async throws -> [MSALNativeAuthMfaSdkAuthSession] {
        [
            MSALNativeAuthMfaSdkAuthSession(
                guid: "1E379F3D-B2C8-4D3F-9741-1E02328C8965",
                accountName: "Example account",
                username: "user@example.com",
                firstEntropyNumber: "42"
            )
        ]
    }

    /// Submits the entered number to approve the specified sign-in request.
    /// Throws if the response cannot be completed. Callers must not log the entered number.
    public func approve(
        authSession: MSALNativeAuthMfaSdkAuthSession,
        number: String
    ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult {
        MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult(wasApproved: true)
    }

    /// Denies the specified sign-in request, or throws if the response cannot be completed.
    public func deny(
        authSession: MSALNativeAuthMfaSdkAuthSession
    ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult {
        MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult(wasApproved: false)
    }
}
