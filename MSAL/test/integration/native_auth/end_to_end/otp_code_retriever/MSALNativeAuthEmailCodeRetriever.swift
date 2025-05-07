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

import XCTest

class MSALNativeAuthEmailCodeRetriever: XCTestCase {

    struct Account: Encodable {
        let address: String
        let password: String

        init(_ address: String, _ password: String) {
            self.address = address
            self.password = password
        }
    }

    struct IdentifiableEmail: Decodable {
        let id: String
        let createdAt: String
        var date: Date {
            return MSALNativeAuthEmailCodeRetriever.dateFormatter.date(from: createdAt) ?? Date.distantPast
        }
    }

    struct Email: Decodable {
        let id: String
        let body: String
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id, createdAt
            case body = "text"
        }
    }

    var baseURLString: String = "https://api.mail.tm" // DJB: decide whether it makes sense to hide it or not
    private var serviceToken: String?
    private let secondsToWait = 4.0
    private let numberOfRetry = 3
    private static let dateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
//        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) //We ignore the timezone
        return dateFormatter
    }()
    private let maximumSecondsSinceEmailReceive = 10.0

    func retrieveEmailOTPCode(account: Account) async -> String? {
        guard account.address.components(separatedBy: "@").count == 2 else {
            XCTFail("Invalid email address")
            return nil
        }

        await authenticate(account: account)

        guard let lastEmailId = await retrieveLastEmailId(emailAddress: account.address, retryCounter: numberOfRetry) else {
            XCTFail("Something went wrong retrieving the last email id")
            return nil
        }
        guard let lastEmail = await retrieveLastEmail(id: lastEmailId) else {
            XCTFail("Something went wrong retrieving the last email for the address \(account.address) with id: \(lastEmailId)")
            return nil
        }
        guard let emailOTPCode = retrieveOTPCodeForEmail(lastEmail) else {
            XCTFail("Something went wrong retrieving the OTP code")
            return nil
        }
        return emailOTPCode
    }
    
    func generateRandomEmailAddress() -> String {
        let randomId = UUID().uuidString.prefix(8)
        return "native-auth-signup-\(randomId)@chefalicious.com"
    }

    private func retrieveLastEmailId(emailAddress: String, retryCounter: Int) async -> String? {
        guard retryCounter > 0, let request = request(for: "/messages") else {
            return nil
        }

        try? await Task.sleep(nanoseconds: UInt64(secondsToWait * Double(NSEC_PER_SEC)))

        // DJB: Should we check the pagination?
        guard let lastEmail = await makeRequest(request, for: [IdentifiableEmail].self)?.max(by: { $0.date < $1.date }) else {
            print("No emails found at \(emailAddress)")
            return nil
        }

        // Email should be newer than 5 seconds otherwise it could be from previous test:
        let currentDate = Date()
        let difference =  currentDate.timeIntervalSince(lastEmail.date) // currentDate.timeIntervalSince1970 - lastEmail.date.timeIntervalSince1970

        if difference < maximumSecondsSinceEmailReceive {
            print ("Email is for current test, last receive date: \(lastEmail.date) current date: \(currentDate)")
            return lastEmail.id
        } else {
            print ("Email is from previous tests, last receive date: \(lastEmail.date) current date: \(currentDate)")
        }

        // This retry will help with the delay in receiving the emails:
        if (retryCounter == 1) {
            print("Unexpected behavior: no email received for: \(emailAddress). Trying for last time")
        }

        return await retrieveLastEmailId(emailAddress: emailAddress, retryCounter: retryCounter - 1)
    }

    private func retrieveLastEmail(id: String) async -> Email? {
        guard let request = request(for: "/messages/\(id)") else {
            return nil
        }

        try? await Task.sleep(nanoseconds: UInt64(secondsToWait * Double(NSEC_PER_SEC)))
        return await makeRequest(request, for: Email.self)
    }

    private func retrieveOTPCodeForEmail(_ email: Email) -> String? {
        return email.body
            .components(separatedBy: CharacterSet.newlines)
            .first { $0.range(of: "[0-9]{4,}$", options: .regularExpression, range: nil, locale: nil) != nil }
    }

    private func legacy_retrieveOTPCodeFromMessage(local: String, domain: String, messageId: Int) async -> String? {
        guard let url = URL(string: baseURLString + "readMessage&login=\(local)&domain=\(domain)&id=\(messageId)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let dataDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            let emailLines = (dataDictionary?["textBody"] as? String)?.components(separatedBy: CharacterSet.newlines) ?? []
            // return the first line with only numbers, minimum 4 digits.
            return emailLines.first(where: {$0.range(of: "[0-9]{4,}$", options: .regularExpression, range: nil, locale: nil) != nil })
        } catch {
            print(error)
            return nil
        }
    }

    private func authenticate(account: Account) async {
        guard let url = URL(string: baseURLString + "/token") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestData = try JSONEncoder().encode(account)
            request.httpBody = requestData

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

            let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            if let token = root?["token"] as? String {
                serviceToken = token
            } else {
                print("Token not found")
            }
        } catch {
            print(error)
        }
    }

    private func request(for endpoint: String) -> URLRequest? {
        guard let serviceToken, let url = URL(string: baseURLString + endpoint) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(serviceToken)", forHTTPHeaderField: "Authorization")

        return request
    }

    private func makeRequest<T: Decodable>(_ request: URLRequest, for type: T.Type) async -> T? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Unexpected response from email provider: \(code) status code")
                return nil
            }

            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Error while making the request: \(error)")
            return nil
        }
    }
}
