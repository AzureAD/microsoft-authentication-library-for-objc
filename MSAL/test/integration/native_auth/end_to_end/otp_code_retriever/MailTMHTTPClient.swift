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

/// Minimal async JSON HTTP client used by `MSALNativeAuthEmailCodeRetriever`.
/// Extracted (per PR #3040 review feedback) so the request-build + session +
/// status-code + JSON-decode boilerplate lives in one reusable place.
struct MailTMHTTPClient {

    enum HTTPMethod {
        static let get = "GET"
        static let post = "POST"
    }

    let baseURLString: String

    /// Sends a request to `baseURLString + path` and returns the HTTP status plus the parsed
    /// JSON body (if any). Returns nil only when the URL is malformed or the transport fails.
    /// When `authorizationToken` is non-nil the Authorization header is set to that bearer token.
    func sendJSON(
        path: String,
        method: String = HTTPMethod.get,
        authorizationToken: String? = nil,
        jsonBody: [String: Any]? = nil
    ) async -> (status: Int, json: Any?)? {
        guard let url = URL(string: baseURLString + path) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(MailTMConstants.Header.applicationJSON, forHTTPHeaderField: MailTMConstants.Header.contentType)
        if let authorizationToken = authorizationToken {
            request.setValue(MailTMConstants.Header.bearerPrefix + authorizationToken, forHTTPHeaderField: MailTMConstants.Header.authorization)
        }
        if let jsonBody = jsonBody {
            request.httpBody = try? JSONSerialization.data(withJSONObject: jsonBody)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            return (statusCode, json)
        } catch {
            print(error)
            return nil
        }
    }
}
