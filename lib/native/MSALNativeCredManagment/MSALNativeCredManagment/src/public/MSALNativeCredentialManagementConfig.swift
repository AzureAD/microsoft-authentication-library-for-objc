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

/// Configuration for the credential management client.
///
/// Use this class to configure the `MSALNativeCredentialMethodsClient` with a token provider
/// and tenant subdomain.
///
/// Example:
/// ```swift
/// let config = MSALNativeCredentialManagementConfig()
/// config.tokenProvider = MyCustomTokenProvider()
/// config.tenantSubdomain = "contoso"
/// let client = try MSALNativeCredentialMethodsClient(config: config)
/// ```
@objcMembers
public class MSALNativeCredentialManagementConfig: NSObject
{
    /// The token provider used to obtain access tokens for credential management API calls.
    ///
    /// Must be set before initializing `MSALNativeCredentialMethodsClient`.
    public var tokenProvider: MSALNativeCredentialManagementTokenProvider?

    /// The tenant subdomain for the CIAM tenant (e.g., "contoso" for contoso.ciamlogin.com).
    ///
    /// The credential management API base URL is derived from this value.
    /// Must be set before initializing `MSALNativeCredentialMethodsClient`.
    public var tenantSubdomain: String?

    public override init()
    {
        super.init()
    }
}
