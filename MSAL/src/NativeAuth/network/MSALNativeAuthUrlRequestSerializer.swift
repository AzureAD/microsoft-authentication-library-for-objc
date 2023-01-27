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

@_implementationOnly import MSAL_Private

final class MSALNativeAuthUrlRequestSerializer: NSObject, MSIDRequestSerialization {

    private let context: MSIDRequestContext

    init(context: MSIDRequestContext) {
        self.context = context
    }

    func serialize(
        with request: URLRequest,
        parameters: [AnyHashable: Any],
        headers: [AnyHashable: Any]
    ) -> URLRequest {

        var request = request
        var requestHeaders: [String: String] = [:]

        // Convert entries from `headers` to a dictionary [String: String]

        headers.forEach {
            if let key = $0.key as? String, let value = $0.value as? String {
                requestHeaders[key] = value
            } else {
                MSALLogger.log(level: .error, context: context, format: "Header serialization failed")
            }
        }

        if JSONSerialization.isValidJSONObject(parameters) {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: parameters)
                request.httpBody = jsonData
            } catch {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "HTTP body request serialization failed with error: \(error.localizedDescription)"
                )
            }
        } else {
            MSALLogger.log(level: .error, context: context, format: "HTTP body request serialization failed")
        }

        requestHeaders["Content-Type"] = "application/json"
        request.allHTTPHeaderFields = requestHeaders

        return request
    }
}
