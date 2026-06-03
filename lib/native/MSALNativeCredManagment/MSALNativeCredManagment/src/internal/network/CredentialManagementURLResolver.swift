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

/// Centralized URL resolution and validation for the credential management service.
/// Used by both the MSIDHttpRequest-based transport and the custom network provider transport.
internal struct CredentialManagementURLResolver
{
    private let baseURL: URL

    init(baseURL: URL)
    {
        self.baseURL = baseURL
    }

    /// Resolves a path (absolute or relative) against the base URL.
    /// Returns nil if the resolved URL does not pass security validation.
    ///
    /// Validation rules:
    /// - Scheme must be HTTPS
    /// - Host must match the trusted base URL host
    func resolve(path: String) -> URL?
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
}

/// Shared endpoint path constants.
internal enum CredentialManagementEndpoints
{
    static let methodsPath = "/api/v1.0/me/methods"
}
