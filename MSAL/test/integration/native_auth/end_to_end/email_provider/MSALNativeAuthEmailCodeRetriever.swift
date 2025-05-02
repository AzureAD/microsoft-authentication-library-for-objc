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

class MSALNativeAuthEmailProviderHelper {

    // MARK: - API models

    struct Inbox: Decodable {
        let address: String
        let token: String
    }

    struct Emails: Decodable {
        let emails: [Email]

        var last: Email? {
            emails.max(by: { $0.date < $1.date })
        }
    }

    struct Email: Decodable {
        let body: String
        let date: Date

        enum CodingKeys: String, CodingKey {
            case body, date
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            body = try container.decode(String.self, forKey: .body)
            let timestampMilliseconds = try container.decode(Double.self, forKey: .date)
            date = Date(timeIntervalSince1970: timestampMilliseconds / 1000)
        }
    }

    // MARK: - Errors

    enum EmailProviderError: Error {
        case invalidCreateInboxURL
        case invalidCreateInboxResponse
        case invalidFetchEmailURL
        case invalidFetchEmailResponse
        case attemptsExceeded
        case OTPCodeNotFound
    }

    // MARK: - Properties

    let customDomain: String

    private let apiKey: String
    private let baseURLString: String
    private var currentInbox: Inbox?

    private let secondsToWait = 4.0
    private let numberOfRetry = 3
    private let maximumSecondsSinceEmailReceive = 8.0

    // DJB: Remove?
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) //We ignore the timezone
        return dateFormatter
    }()

    init(apiKey: String, customDomain: String, baseURLString: String) {
        self.apiKey = apiKey
        self.customDomain = customDomain
        self.baseURLString = baseURLString
    }

    // MARK: - Public methods

    @discardableResult
    func createInbox(username: String) async throws -> String {
        guard var request = request(for: "/inbox/create") else {
            throw EmailProviderError.invalidCreateInboxURL
        }
        
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "domain": customDomain,
            "prefix": username.replacingOccurrences(of: "@\(customDomain)", with: "")
        ])

        if let inbox = try await makeRequest(request, for: Inbox.self) {
            currentInbox = inbox
            return inbox.address
        } else {
            throw EmailProviderError.invalidCreateInboxResponse
        }
    }

    func retrieveLastEmailOTPCode(for username: String) async throws -> String {
        if currentInbox == nil {
            try await createInbox(username: username)
        }

        let lastEmail = try await retrieveLastEmail(inbox: currentInbox!, retryCounter: numberOfRetry)
        return try retrieveOTPCodeForEmail(lastEmail)
    }

    // MARK: - Private methods

    private func retrieveLastEmail(inbox: Inbox, retryCounter: Int) async throws -> Email {
        guard retryCounter > 0 else {
            throw EmailProviderError.attemptsExceeded
        }

        guard let request = request(for: "/inbox", token: currentInbox?.token) else {
            throw EmailProviderError.invalidFetchEmailURL
        }

        try await Task.sleep(nanoseconds: UInt64(secondsToWait * Double(NSEC_PER_SEC)))

        guard let lastEmail = try await makeRequest(request, for: Emails.self)?.last else {
            print("No emails found at \(inbox.address)")
            throw EmailProviderError.invalidFetchEmailResponse
        }

        // Email should be newer than 5 seconds otherwise it could be from previous test:
        let currentDate = Date()
        let difference = currentDate.timeIntervalSince1970 - lastEmail.date.timeIntervalSince1970

        if difference < maximumSecondsSinceEmailReceive {
            print ("Email is for current test, last receive date: \(lastEmail.date) current date: \(currentDate)")
            return lastEmail
        } else {
            print ("Email is from previous tests, last receive date: \(lastEmail.date) current date: \(currentDate)")
        }

        // This retry will help with the delay in receiving the emails:
        if (retryCounter == 1) {
            print("Unexpected behavior: no email received for: \(inbox.address). Trying for last time")
        }

        return try await retrieveLastEmail(inbox: inbox, retryCounter: retryCounter - 1)
    }

    private func request(for endpoint: String, token: String? = nil) -> URLRequest? {
        guard let url = URL(string: baseURLString + endpoint) else {
            return nil
        }

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let token {
            urlComponents?.queryItems = [URLQueryItem(name: "token", value: token)]
        }

        var request = URLRequest(url: urlComponents?.url ?? url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        return request
    }

    private func makeRequest<T: Decodable>(_ request: URLRequest, for type: T.Type) async throws -> T? {
        let (data, response) = try await URLSession.shared.data(for: request)

        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            print("Unexpected response from email provider: \(code) status code")
            return nil
        }

        return try JSONDecoder().decode(type, from: data)
    }

    private func retrieveOTPCodeForEmail(_ email: Email) throws -> String {
        let code = email.body
            .components(separatedBy: CharacterSet.newlines)
            .first { $0.range(of: "[0-9]{4,}$", options: .regularExpression, range: nil, locale: nil) != nil }

        if let code {
            return code
        } else {
            throw EmailProviderError.OTPCodeNotFound
        }
    }
}
