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

class MSALNativeAuthMSGraphEmailCodeRetriever: XCTestCase, MSALNativeAuthEmailOTPCodeRetriever {
    
    var accessTokenRetriever: MSALNativeAuthGraphAccessTokenRetriever?
    private let tenantOwnerEmail: String? = ProcessInfo.processInfo.environment["mailboxTenantOwnerEmail"]
    
    func retrieveEmailOTPCode(email: String, usingMockAPI: Bool) async -> String {
        guard !usingMockAPI else {
            return "1234"
        }
        guard let tenantOwnerEmail = tenantOwnerEmail else {
            XCTFail("invalid tenantOwnerEmail address")
            return ""
        }
        let accessToken = await accessTokenRetriever?.retrieveAccessToken()
        guard let accessToken = accessToken else {
            XCTFail("accessToken not retrieved")
            return ""
        }
        let emailFormatted = email.msidWWWFormURLEncode()!
        guard let url = URL(string: "https://graph.microsoft.com/v1.0/users/\(tenantOwnerEmail)/messages?$search=\"to:\(emailFormatted)\"&$select=body,receivedDateTime") else {
            XCTFail("invalid URL")
            return ""
        }
        let seconds = 18.0
        try? await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("outlook.body-content-type=\"text\"", forHTTPHeaderField: "Prefer")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                XCTFail("Error retrieving OTP email")
                return ""
            }
            let dataDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            let emailContent = ((dataDictionary?["value"] as? [[String: Any]])?.first?["body"] as? [String: String]?)??["content"]
            return emailContent?.components(separatedBy: CharacterSet.newlines).first(where: {$0.range(of: "[0-9]{8}", options: .regularExpression, range: nil, locale: nil) != nil }) ?? ""
            
        } catch {
            print(error)
            XCTFail("Error happened during OTP email retrieving")
            return ""
        }
    }
}
