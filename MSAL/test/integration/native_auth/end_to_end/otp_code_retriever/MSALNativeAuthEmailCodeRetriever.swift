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

    struct Inbox: Decodable {
        let address: String
        let token: String
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

    private let apiKey: String // DJB: Not used in the free tier, but will be needed in the future
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

    func generateRandomInbox() async -> Inbox? {
        guard let url = URL(string: baseURLString + "/inbox/create") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                print("Unexpected response when creating a new inbox: \(code) status code")
                return nil
            }

            return try JSONDecoder().decode(Inbox.self, from: data)
        } catch {
            print(error)
            return nil
        }
    }

    func retrieveLastEmailOTPCode(from inbox: Inbox) async -> String? {
        guard let lastEmail = await retrieveLastEmail(inbox: inbox, retryCounter: numberOfRetry) else {
            XCTFail("Something went wrong retrieving the last email for the address specified")
            return nil
        }
        guard let emailOTPCode = retrieveOTPCodeForEmail(lastEmail) else {
            XCTFail("Something went wrong retrieving the OTP code")
            return nil
        }
        return emailOTPCode
    }

    private func retrieveLastEmail(inbox: Inbox, retryCounter: Int) async -> Email? {
        guard retryCounter > 0, var urlComponents = URLComponents(string: baseURLString + "/inbox") else {
            return nil
        }

        urlComponents.queryItems = [.init(name: "token", value: inbox.token)]

        guard let url = urlComponents.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            try await Task.sleep(nanoseconds: UInt64(secondsToWait * Double(NSEC_PER_SEC)))

            let (data, response) = try await URLSession.shared.data(for: request)

            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                print("Unexpected response from email provider: \(code) status code")
                return nil
            }

            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let emailsData = try JSONSerialization.data(withJSONObject: root?["emails"] ?? [])
            let emails = try JSONDecoder().decode([Email].self, from: emailsData)

            guard let lastEmail = emails.first else {
                print("No emails found at \(inbox.address)")
                return nil
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

            return await retrieveLastEmail(inbox: inbox, retryCounter: retryCounter - 1)
        } catch {
            print(error)
            return nil
        }
    }

    private func retrieveOTPCodeForEmail(_ email: Email) -> String? {
        return email.body
            .components(separatedBy: CharacterSet.newlines)
            .first { $0.range(of: "[0-9]{4,}$", options: .regularExpression, range: nil, locale: nil) != nil }
    }
}
