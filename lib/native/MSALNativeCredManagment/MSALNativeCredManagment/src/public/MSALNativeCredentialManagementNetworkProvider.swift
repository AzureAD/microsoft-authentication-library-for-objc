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

/// Represents an HTTP request to the credential management API.
public struct MSALCredentialManagementHTTPRequest
{
    /// The target URL.
    public let url: URL

    /// The HTTP method (e.g., "GET", "POST", "DELETE").
    public let method: String

    /// The request headers.
    public let headers: [String: String]

    /// The request body, if any.
    public let body: Data?

    public init(url: URL, method: String, headers: [String: String], body: Data?)
    {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

/// Represents an HTTP response from the credential management API.
public struct MSALCredentialManagementHTTPResponse
{
    /// The HTTP status code.
    public let statusCode: Int

    /// The response headers.
    public let headers: [String: String]

    /// The response body data.
    public let data: Data?

    public init(statusCode: Int, headers: [String: String], data: Data?)
    {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

/// Protocol for providing custom HTTP transport to the credential management client.
///
/// Implement this protocol to inject a mock or custom HTTP layer for testing.
/// When set on `MSALNativeCredentialManagementConfig.networkProvider`, it replaces
/// the default URLSession-based transport.
///
/// Example (mock):
/// ```swift
/// class MockNetworkProvider: MSALNativeCredentialManagementNetworkProvider {
///     func performRequest(_ request: MSALCredentialManagementHTTPRequest) async throws
///         -> MSALCredentialManagementHTTPResponse {
///         // Return mock HAL+JSON responses
///     }
/// }
/// ```
public protocol MSALNativeCredentialManagementNetworkProvider
{
    /// Performs an HTTP request and returns the response.
    ///
    /// - Parameter request: The request to execute.
    /// - Returns: The HTTP response.
    /// - Throws: Network-level errors.
    func performRequest(
        _ request: MSALCredentialManagementHTTPRequest
    ) async throws -> MSALCredentialManagementHTTPResponse
}
