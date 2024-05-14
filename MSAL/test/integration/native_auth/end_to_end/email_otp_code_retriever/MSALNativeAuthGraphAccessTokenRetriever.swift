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

import Foundation

actor MSALNativeAuthGraphAccessTokenRetriever {
    
    static var accessToken: String?
    
    private let clientId: String? = ProcessInfo.processInfo.environment["mailboxClientId"]
    private let clientSecret: String? = ProcessInfo.processInfo.environment["mailboxClientSecret"]
    private let tenantId: String? = ProcessInfo.processInfo.environment["mailboxTenantId"]
    
    func retrieveAccessToken() async -> String? {
        guard Self.accessToken == nil else {
            return Self.accessToken
        }
        guard let clientId = clientId, let clientSecret = clientSecret, let tenantId = tenantId else {
            print("missing settings")
            return nil
        }
        guard let url = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token") else {
            print("invalid URL")
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyParams = [
            "client_id":clientId,
            "scope": "https://graph.microsoft.com/.default",
            "client_secret" : clientSecret,
            "grant_type":"client_credentials"
        ]
        request.httpBody = formUrlEncode(bodyParams).data(using: .utf8)
        request.httpMethod = "POST"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let dataDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return dataDictionary?["access_token"] as? String
        } catch {
            print(error)
            return nil
        }
    }
    
    private func formUrlEncode(_ parameters: [AnyHashable: Any]) -> String {
        parameters.map {
            let encodedKey = (($0.key as? String) ?? "").msidWWWFormURLEncode() ?? ""
            let encodedValue = (($0.value as? String) ?? "").msidWWWFormURLEncode() ?? ""
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }
}
