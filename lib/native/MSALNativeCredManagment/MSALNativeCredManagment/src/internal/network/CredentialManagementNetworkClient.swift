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

/// Protocol defining the HTTP transport interface for credential management API calls.
///
/// This protocol enables injection of mock implementations for unit testing.
internal protocol CredentialManagementNetworkClient
{
    /// Performs an HTTP request and returns the raw response.
    ///
    /// - Parameter request: The request to execute.
    /// - Returns: The response containing status code, headers, and body data.
    /// - Throws: Network-level errors (connectivity, timeout).
    func perform(request: CredentialManagementRequest) async throws -> CredentialManagementResponse
}

/// Represents an HTTP request to the credential management API.
internal struct CredentialManagementRequest
{
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?

    internal enum HTTPMethod: String
    {
        case get = "GET"
        case post = "POST"
        case delete = "DELETE"
    }

    init(url: URL, method: HTTPMethod, headers: [String: String] = [:], body: Data? = nil)
    {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

/// Represents an HTTP response from the credential management API.
internal struct CredentialManagementResponse
{
    let statusCode: Int
    let headers: [String: String]
    let data: Data?
}
