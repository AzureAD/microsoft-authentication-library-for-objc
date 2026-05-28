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

/// A built-in token provider that wraps `MSALNativeAuthUserAccountResult` to obtain
/// access tokens using the existing MSAL Native Auth cached session.
///
/// Use this provider (P1) when you want automatic token management through MSAL:
/// ```swift
/// let tokenProvider = MSALNativeAuthTokenProvider(userAccountResult: userAccountResult)
/// credConfig.tokenProvider = tokenProvider
/// ```
///
/// - Important: This provider holds a weak reference to `userAccountResult`. If the user
///   signs out or the result is deallocated, the provider will return a `sessionExpired` error.
@objcMembers
public class MSALNativeAuthTokenProvider: NSObject, MSALNativeCredentialManagementTokenProvider {

    private weak var userAccountResult: MSALNativeAuthUserAccountResult?

    /// Initialize with the user account result obtained from a successful MSAL Native Auth sign-in.
    ///
    /// - Parameter userAccountResult: The account result containing cached tokens and account info.
    public init(userAccountResult: MSALNativeAuthUserAccountResult)
    {
        self.userAccountResult = userAccountResult
        super.init()
    }

    /// Retrieve an access token by delegating to MSAL Native Auth's silent token retrieval.
    ///
    /// - Parameters:
    ///   - scopes: The scopes required by the credential management operation.
    ///   - completionBlock: Called with the access token on success, or nil and an error on failure.
    public func getAccessToken(
        scopes: [String],
        completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock
    )
    {
        guard let accountResult = userAccountResult else
        {
            let error = MSALNativeCredentialManagementError(
                type: .sessionExpired,
                message: "User account result is no longer available. The user may have signed out. "
                    + "Please re-authenticate and create a new MSALNativeAuthTokenProvider instance."
            )
            completionBlock(nil, error)
            return
        }

        let params = MSALNativeAuthGetAccessTokenParameters()
        params.scopes = scopes

        accountResult.getAccessToken(parameters: params, delegate: TokenProviderCredentialsDelegate(completionBlock: completionBlock))
    }
}

/// Internal delegate that bridges the MSAL CredentialsDelegate pattern to a completion block.
private class TokenProviderCredentialsDelegate: NSObject, CredentialsDelegate {

    private let completionBlock: MSALNativeCredentialManagementTokenCompletionBlock

    init(completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock)
    {
        self.completionBlock = completionBlock
        super.init()
    }

    @MainActor func onAccessTokenRetrieveError(error: RetrieveAccessTokenError)
    {
        let credError = MSALNativeCredentialManagementError(
            type: .unauthorized,
            message: "Failed to retrieve access token from MSAL: \(error.errorDescription ?? "Unknown error")",
            correlationId: error.correlationId
        )
        completionBlock(nil, credError)
    }

    @MainActor func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult)
    {
        completionBlock(result.accessToken, nil)
    }
}
