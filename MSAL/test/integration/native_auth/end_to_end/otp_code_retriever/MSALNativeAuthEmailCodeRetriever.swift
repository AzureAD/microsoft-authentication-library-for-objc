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

    struct Email: Decodable {
        let id: String
        let inbox: String
        let received: Date

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case inbox, received
        }
    }

    private let apiKey: String
    private let baseURLString: String
    private let secondsToWait = 4.0
    private let numberOfRetry = 3
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) //We ignore the timezone
        return dateFormatter
    }()
    private let maximumSecondsSinceEmailReceive = 5.0

    init(apiKey: String, baseURLString: String) {
        self.apiKey = apiKey
        self.baseURLString = baseURLString
        super.init()
    }

    func retrieveEmailOTPCode(emailAddress: String) async -> String? {
        guard emailAddress.components(separatedBy: "@").count == 2 else {
            XCTFail("Invalid email address")
            return nil
        }
        guard let lastEmail = await retrieveLastEmail(emailAddress: emailAddress, retryCounter: numberOfRetry) else {
            XCTFail("Something went wrong retrieving the last email for the address specified")
            return nil
        }
        guard let emailOTPCode = await retrieveOTPCodeForEmail(lastEmail) else {
            XCTFail("Something went wrong retrieving the OTP code")
            return nil
        }
        return emailOTPCode
    }
    
    func generateRandomEmailAddress() -> String {
        let randomId = UUID().uuidString.prefix(8)
        return "native-auth-signup-\(randomId)@mailsac.com"
    }

    private func retrieveLastEmail(emailAddress: String, retryCounter: Int) async -> Email? {
        guard retryCounter > 0, let url = URL(string: baseURLString + "addresses/\(emailAddress)/messages") else {
            return nil
        }

        try? await Task.sleep(nanoseconds: UInt64(secondsToWait * Double(NSEC_PER_SEC)))

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // DJB: remove?
        request.setValue(apiKey, forHTTPHeaderField: "Mailsac-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Unexpected response from email provider: \(code) status code")
                return nil
            }

            let emails = try JSONDecoder().decode([Email].self, from: data)

            guard let lastEmail = emails.first else {
                print("No emails found at \(emailAddress)")
                return nil
            }

            // Email should be newer than 5 seconds otherwise it could be from previous test:
            let currentDate = Date()
            let difference = currentDate.timeIntervalSince1970 - lastEmail.received.timeIntervalSince1970

            if difference < maximumSecondsSinceEmailReceive {
                print ("Email is for current test, last receive date: \(lastEmail.received) current date: \(currentDate)")
                return lastEmail
            } else {
                print ("Email is from previous tests, last receive date: \(lastEmail.received) current date: \(currentDate)")
            }

            // This retry will help with the delay in receiving the emails:
            if (retryCounter == 1) {
                print("Unexpected behavior: no email received for: \(emailAddress). Trying for last time")
            }

            return await retrieveLastEmail(emailAddress: emailAddress, retryCounter: retryCounter - 1)
        } catch {
            print(error)
            return nil
        }
    }

    private func retrieveOTPCodeForEmail(_ email: Email) async -> String? {
        guard let url = URL(string: baseURLString + "text/\(email.inbox)/\(email.id)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // DJB: Remove?
        request.setValue(apiKey, forHTTPHeaderField: "Mailsac-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            // Parse the email as plain text,
            // split the lines into an array,
            // and return the first line with only numbers, minimum 4 digits.
            return try JSONDecoder()
                .decode(String.self, from: data)
                .components(separatedBy: CharacterSet.newlines)
                .first { $0.range(of: "[0-9]{4,}$", options: .regularExpression, range: nil, locale: nil) != nil }
        } catch {
            print(error)
            return nil
        }
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
}
