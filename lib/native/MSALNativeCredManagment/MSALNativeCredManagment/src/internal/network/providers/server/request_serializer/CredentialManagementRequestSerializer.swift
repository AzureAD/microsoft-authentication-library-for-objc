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

/// Concrete request serializer that transforms typed credential management requests
/// into `URLRequest` instances with appropriate headers.
///
/// Applies:
/// - Authorization: Bearer {token}
/// - Accept: application/hal+json
/// - client-request-id: {correlationId}
/// - Content-Type: application/json (when body present)
internal final class CredentialManagementRequestSerializer: CredentialManagementRequestSerializing
{
    private let urlResolver: CredentialManagementURLResolver

    init(urlResolver: CredentialManagementURLResolver)
    {
        self.urlResolver = urlResolver
    }

    func serialize(_ request: CredentialManagementRequestProtocol) -> URLRequest?
    {
        guard let url = urlResolver.resolve(path: request.path) else
        {
            return nil
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.httpMethod

        // Standard headers
        urlRequest.setValue("Bearer \(request.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/hal+json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(request.correlationId.uuidString, forHTTPHeaderField: "client-request-id")

        // Body
        if let body = request.body
        {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body
        }

        return urlRequest
    }
}
