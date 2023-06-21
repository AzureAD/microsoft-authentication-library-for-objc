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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

@objc
public class MSALNativeAuthUserAccountResult: NSObject {
    private let account: MSALAccount
    private let authTokens: MSALNativeAuthTokens

    @objc public var username: String {
        account.username ?? ""
    }
    @objc public var idToken: String? {
        authTokens.rawIdToken
    }
    @objc public var scopes: [String] {
        authTokens.accessToken?.scopes.array as? [String] ?? []
    }
    @objc public var expiresOn: Date? {
        authTokens.accessToken?.expiresOn
    }
    @objc public var accountClaims: [String: Any] {
        account.accountClaims ?? [:]
    }

    init(account: MSALAccount,
         authTokens: MSALNativeAuthTokens) {
        self.account = account
        self.authTokens = authTokens
    }

    @objc public func signOut() {

    }

    @objc public func getAccessToken(delegate: CredentialsDelegate) {
        if let accessToken = self.authTokens.accessToken {
            if !accessToken.isExpired() {
                Task {
                    await delegate.onAccessTokenRetrieveCompleted(accessToken: accessToken.accessToken)
                }
            } else {
                // TODO: Retrieve new access token based on refresh token from API
            }
        } else {
            MSALLogger.log(level: .error, context: nil, format: "Retrieve Access Token: Existing token not found")
            Task {
                await delegate.onAccessTokenRetrieveError(error: RetrieveTokenError(type: .tokenNotFound))
            }
        }
    }
}
