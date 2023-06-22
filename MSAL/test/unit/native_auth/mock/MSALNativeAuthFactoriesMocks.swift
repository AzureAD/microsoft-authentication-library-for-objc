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

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

class MSALNativeAuthRequestControllerFactoryFail: MSALNativeAuthControllerBuildable {

    func makeSignUpController() -> MSAL.MSALNativeAuthSignUpControlling {
        MSALNativeAuthSignUpController(config: MSALNativeAuthConfigStubs.configuration)
    }

    func makeSignInController() -> MSAL.MSALNativeAuthSignInControlling {
        XCTFail("This method should not be called")
        return MSALNativeAuthSignInController(
            config: MSALNativeAuthConfigStubs.configuration
        )
    }

    func makeResetPasswordController() -> MSAL.MSALNativeAuthResetPasswordControlling {
        MSALNativeAuthResetPasswordController(
            config: MSALNativeAuthConfigStubs.configuration
        )
    }

    func makeCredentialsController() -> MSAL.MSALNativeAuthCredentialsControlling {
        MSALNativeAuthCredentialsController(
            config: MSALNativeAuthConfigStubs.configuration
        )
    }
}

class MSALNativeAuthResultFactoryMock: MSALNativeAuthResultBuildable {

    var config: MSAL.MSALNativeAuthConfiguration = MSALNativeAuthConfigStubs.configuration
    
    private(set) var makeMsidConfigurationResult: MSIDConfiguration?
    private(set) var makeNativeAuthUserAccountResult: MSALNativeAuthUserAccountResult?

    func mockMakeUserAccountResult(_ result: MSALNativeAuthUserAccountResult) {
        self.makeNativeAuthUserAccountResult = result
    }

    func makeUserAccountResult(tokenResult: MSIDTokenResult, context: MSIDRequestContext) -> MSAL.MSALNativeAuthUserAccountResult? {
        return makeNativeAuthUserAccountResult ?? .init(
            account: MSALAccount.init(msidAccount: tokenResult.account, createTenantProfile: false),
            authTokens: MSALNativeAuthTokens(
                accessToken: tokenResult.accessToken,
                refreshToken: tokenResult.refreshToken as? MSIDRefreshToken,
                rawIdToken: tokenResult.rawIdToken
            ),
            configuration: MSALNativeAuthConfigStubs.configuration,
            cacheAccessor: MSALNativeAuthCacheAccessorMock()
        )
    }

    func makeUserAccountResult(account: MSALAccount, authTokens: MSAL.MSALNativeAuthTokens) -> MSAL.MSALNativeAuthUserAccountResult? {
        return makeNativeAuthUserAccountResult ?? .init(
            account: account,
            authTokens: authTokens,
            configuration: MSALNativeAuthConfigStubs.configuration,
            cacheAccessor: MSALNativeAuthCacheAccessorMock()
        )
    }

    func mockMakeMsidConfigurationFunc(_ result: MSIDConfiguration) {
        self.makeMsidConfigurationResult = result
    }

    func makeMSIDConfiguration(scopes: [String]) -> MSIDConfiguration {
        return makeMsidConfigurationResult ?? MSALNativeAuthConfigStubs.msidConfiguration
    }
}
