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

    private func retrieveLastMessage(local: String, domain: String, retryCounter: Int) async -> Int? {
        guard retryCounter > 0, let url = URL(string: baseURLString + "getMessages&login=\(local)&domain=\(domain)") else {
            return nil
        }
        try? await Task.sleep(nanoseconds: UInt64(secondsToWait * Double(NSEC_PER_SEC)))
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200,
                    var dataDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
                return nil
            }
            if dataDictionary.count > 0 {
                dataDictionary.sort(by: {($0["date"] as? String ?? "") > ($1["date"] as? String ?? "")})
                return dataDictionary.first?["id"] as? Int
            } else {
                // no emails found, retry
                return await retrieveLastMessage(local: local, domain: domain, retryCounter: retryCounter - 1)
            }
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
            return (dataDictionary?["textBody"] as? String)?.components(separatedBy: CharacterSet.newlines).first(where: {$0.range(of: "[0-9]{4,}$", options: .regularExpression, range: nil, locale: nil) != nil })
        } catch {
            print(error)
            return nil
        }
    }
}
