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

/// Builds authenticated HTTP requests for the credential management API.
///
/// Ensures consistent headers (Authorization, Accept, Content-Type, correlation ID)
/// and validates that all target URLs belong to the trusted base URL.
internal struct CredentialManagementRequestBuilder
{
    private let baseURL: URL
    private let accessToken: String
    private let correlationId: UUID

    init(baseURL: URL, accessToken: String, correlationId: UUID)
    {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.correlationId = correlationId
    }

    // MARK: - Request Factories

    func buildGET(path: String) -> Result<CredentialManagementRequest, MSALNativeCredentialManagementError>
    {
        guard let url = resolveURL(path: path) else
        {
            return .failure(untrustedURLError(path: path))
        }

        return .success(CredentialManagementRequest(
            url: url,
            method: .get,
            headers: commonHeaders()
        ))
    }

    func buildPOST(path: String, body: Data?) -> Result<CredentialManagementRequest, MSALNativeCredentialManagementError>
    {
        guard let url = resolveURL(path: path) else
        {
            return .failure(untrustedURLError(path: path))
        }

        var headers = commonHeaders()
        if body != nil
        {
            headers["Content-Type"] = "application/json"
        }

        return .success(CredentialManagementRequest(
            url: url,
            method: .post,
            headers: headers,
            body: body
        ))
    }

    func buildDELETE(path: String) -> Result<CredentialManagementRequest, MSALNativeCredentialManagementError>
    {
        guard let url = resolveURL(path: path) else
        {
            return .failure(untrustedURLError(path: path))
        }

        return .success(CredentialManagementRequest(
            url: url,
            method: .delete,
            headers: commonHeaders()
        ))
    }

    // MARK: - URL Validation

    /// Resolves a path (absolute or relative) against the base URL.
    /// Returns nil if the resolved URL does not belong to the trusted base.
    func resolveURL(path: String) -> URL?
    {
        let resolvedURL: URL

        if path.hasPrefix("http://") || path.hasPrefix("https://")
        {
            guard let url = URL(string: path) else { return nil }
            resolvedURL = url
        }
        else
        {
            guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { return nil }
            resolvedURL = url
        }

        guard resolvedURL.scheme == "https" else { return nil }
        guard resolvedURL.host == baseURL.host else { return nil }

        return resolvedURL
    }

    // MARK: - Private

    private func commonHeaders() -> [String: String]
    {
        return [
            "Authorization": "Bearer \(accessToken)",
            "Accept": "application/hal+json",
            "client-request-id": correlationId.uuidString
        ]
    }

    private func untrustedURLError(path: String) -> MSALNativeCredentialManagementError
    {
        return MSALNativeCredentialManagementError(
            type: .generalError,
            message: "URL validation failed: '\(path)' does not belong to the trusted service.",
            correlationId: correlationId
        )
    }
}
