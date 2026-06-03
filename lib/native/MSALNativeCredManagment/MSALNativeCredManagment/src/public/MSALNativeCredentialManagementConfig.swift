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
import MSAL

/// Configuration for the credential management client.
///
/// Use this class to configure the `MSALNativeCredentialMethodsClient` with a token provider,
/// optional request interceptor (shared with MSAL), and API base URL.
///
/// Example:
/// ```swift
/// let credConfig = MSALNativeCredentialManagementConfig()
/// credConfig.requestInterceptor = sharedRequestInterceptor
/// credConfig.tokenProvider = MyCustomTokenProvider()
/// let credClient = try MSALNativeCredentialMethodsClient(config: credConfig)
/// ```
@objcMembers
public class MSALNativeCredentialManagementConfig: NSObject {

    /// An optional interceptor for injecting custom HTTP headers into credential management requests.
    ///
    /// Can be shared with `MSALNativeAuthPublicClientApplicationConfig.requestInterceptor`
    /// for consistent header injection across both MSAL and credential management calls.
    public var requestInterceptor: MSALNativeAuthRequestInterceptor?

    /// The token provider used to obtain access tokens for credential management API calls.
    ///
    /// - P0: Assign a custom implementation conforming to `MSALNativeCredentialManagementTokenProvider`.
    /// - P1: Assign `MSALNativeAuthTokenProvider(userAccountResult:)` for automatic MSAL-based token retrieval.
    public var tokenProvider: MSALNativeCredentialManagementTokenProvider?

    /// The base URL for the credential management API.
    ///
    /// When nil, the client derives the endpoint from the tenant configuration.
    public var baseURL: URL?

    /// Optional custom network provider for HTTP transport.
    ///
    /// When set, this replaces the default URLSession-based transport (which includes
    /// retry logic, interceptor support, and configurable timeouts modeled after MSIDHttpRequest).
    /// Use this to inject a mock provider for testing or local development.
    public var networkProvider: MSALNativeCredentialManagementNetworkProvider?

    public override init()
    {
        super.init()
    }
}
