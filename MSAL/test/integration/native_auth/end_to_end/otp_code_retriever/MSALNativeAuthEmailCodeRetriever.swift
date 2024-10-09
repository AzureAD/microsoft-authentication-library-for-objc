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

    private let baseURLString = "https://www.1secmail.com/api/v1/?action="
    private let secondsToWait = 4.0
    private let numberOfRetry = 3
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) //We ignore the timezone
        return dateFormatter
    }()
    private let secondsToWaitForEmail = 5.0

    func retrieveEmailOTPCode(email: String) async -> String? {
        let comps = email.components(separatedBy: "@")
        guard comps.count == 2 else {
            XCTFail("Invalid email address")
            return nil
        }
        let local = comps[0]
        let domain = comps[1]

        guard let lastMessageId = await retrieveLastMessage(local: local, domain: domain, retryCounter: numberOfRetry) else {
            XCTFail("Something went wrong retrieving the messages for the email specified")
            return nil
        }
        guard let emailOTPCode = await retrieveOTPCodeFromMessage(local: local, domain: domain, messageId: lastMessageId) else {
            XCTFail("Something went wrong retrieving the OTP code")
            return nil
        }
        return emailOTPCode
    }
    
    func generateRandomEmailAddress() -> String {
        let randomId = UUID().uuidString.prefix(8)
        return "native-auth-signup-\(randomId)@1secmail.org"
    }

    private func retrieveLastMessage(local: String, domain: String, retryCounter: Int) async -> Int? {
        guard retryCounter > 0, let url = URL(string: baseURLString + "getMessages&login=\(local)&domain=\(domain)") else {
            return nil
        }
        try? await Task.sleep(nanoseconds: UInt64(secondsToWait * Double(NSEC_PER_SEC)))
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200 else {
                print("Unexpected response from 1secmail: \(code) status code")
                return nil
            }
            guard var dataDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                return nil
            }
            if dataDictionary.count > 0 {
                dataDictionary.sort(by: {($0["id"] as? Int ?? 0) > ($1["id"] as? Int ?? 0)})
                if let emailDateString = dataDictionary.first?["date"] as? String,
                   let emailDate = dateFormatter.date(from: emailDateString) {
                    let currentDate = Date()
                    // Email should be newer than 5 seconds otherwise it could be from previous test
                    // This retry will help with the delay in receiving the emails
                    if currentDate.timeIntervalSince1970 - emailDate.timeIntervalSince1970  < secondsToWaitForEmail {
                        print ("Email is for current test, last receive date: \(emailDate) current date: \(currentDate)")
                        return dataDictionary.first?["id"] as? Int
                    } else {
                        print ("Email is from previous tests, last receive date: \(emailDate) current date: \(currentDate)")
                    }
                }
            }
            // log only for the final retry
            if (retryCounter == 1) {
                print("Unexpected behaviour: no email received for the following local: \(local)")
            }
            // no emails found, retry
            return await retrieveLastMessage(local: local, domain: domain, retryCounter: retryCounter - 1)
        } catch {
            print(error)
            return nil
        }
    }

    private func retrieveOTPCodeFromMessage(local: String, domain: String, messageId: Int) async -> String? {
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
