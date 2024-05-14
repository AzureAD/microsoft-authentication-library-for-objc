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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import XCTest

protocol MSALNativeAuthEmailOTPCodeRetriever {
    func retrieveEmailOTPCode(email: String, usingMockAPI: Bool) async -> String
}

class MSALNativeAuth1SecmailCodeRetriever: XCTestCase, MSALNativeAuthEmailOTPCodeRetriever {
    
    private let baseURLString = "https://www.1secmail.com/api/v1/?action="
    
    // we suppose the domain is 1secmail.com
    func retrieveEmailOTPCode(email: String, usingMockAPI: Bool) async -> String {
        guard !usingMockAPI else {
            return "1234"
        }
        guard let local = email.components(separatedBy: "@").first else {
            XCTFail("invalid email address")
            return ""
        }
        let seconds = 4.0
        try? await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
        
        guard let lastMessageId = await retrieveLastMessage(local: local) else {
            XCTFail("Something went wrong retrieving the messages for the email specified")
            return ""
        }
        guard let emailOTPCode = await retrieveOTPCodeFromMessage(local: local, messageId: lastMessageId) else {
            XCTFail("Something went wrong retrieving the OTP code")
            return ""
        }
        return emailOTPCode
    }
    
    private func retrieveLastMessage(local: String) async -> Int? {
        guard let url = URL(string: baseURLString + "getMessages&login=\(local)&domain=1secmail.com") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let dataDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
            return dataDictionary?.first?["id"] as? Int
        } catch {
            print(error)
            return nil
        }
    }
    
    private func retrieveOTPCodeFromMessage(local: String, messageId: Int) async -> String? {
        guard let url = URL(string: baseURLString + "readMessage&login=\(local)&domain=1secmail.com&id=\(messageId)") else {
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
            return (dataDictionary?["textBody"] as? String)?.components(separatedBy: CharacterSet.newlines).first(where: {$0.range(of: "[0-9]{8}", options: .regularExpression, range: nil, locale: nil) != nil })
        } catch {
            print(error)
            return nil
        }
    }
}
