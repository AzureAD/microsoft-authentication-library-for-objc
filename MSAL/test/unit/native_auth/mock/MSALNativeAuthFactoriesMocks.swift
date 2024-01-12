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

class MSALNativeAuthControllerFactoryMock: MSALNativeAuthControllerBuildable {

    var signUpController = MSALNativeAuthSignUpControllerMock()
    var signInController = MSALNativeAuthSignInControllerMock()
    var resetPasswordController = MSALNativeAuthResetPasswordControllerMock()
    var credentialsController = MSALNativeAuthCredentialsControllerMock()

    func makeSignUpController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthSignUpControlling {
        return signUpController
    }

    func makeSignInController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthSignInControlling {
        return signInController
    }

    func makeResetPasswordController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthResetPasswordControlling {
        return resetPasswordController
    }

    func makeCredentialsController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthCredentialsControlling {
        return credentialsController
    }
}

class MSALNativeAuthControllerProtocolFactoryMock: MSALNativeAuthControllerBuildable {
    
    var signUpController: MSALNativeAuthSignUpControlling!
    var signInController: MSALNativeAuthSignInControlling!
    var resetPasswordController: MSALNativeAuthResetPasswordControlling!
    var credentialsController: MSALNativeAuthCredentialsControlling!
    
    init (signUpController: MSALNativeAuthSignUpControlling = MSALNativeAuthSignUpControllerMock(),
          signInController: MSALNativeAuthSignInControlling = MSALNativeAuthSignInControllerMock(),
          resetPasswordController: MSALNativeAuthResetPasswordControlling = MSALNativeAuthResetPasswordControllerMock(),
          credentialsController: MSALNativeAuthCredentialsControlling = MSALNativeAuthCredentialsControllerMock()) {
        self.signUpController = signUpController
        self.signInController = signInController
        self.resetPasswordController = resetPasswordController
        self.credentialsController = credentialsController
    }
    
    func makeSignUpController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthSignUpControlling {
        return signUpController
    }
    
    func makeSignInController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthSignInControlling {
        return signInController
    }
    
    func makeResetPasswordController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthResetPasswordControlling {
        return resetPasswordController
    }
    
    func makeCredentialsController(cacheAccessor: MSAL.MSALNativeAuthCacheInterface) -> MSAL.MSALNativeAuthCredentialsControlling {
        return credentialsController
    }
}

class MSALNativeAuthCacheAccessorFactoryMock: MSALNativeAuthCacheAccessorBuildable {
    var tokenCache: MSIDDefaultTokenCacheAccessor?
    var accountMetadataCache: MSIDAccountMetadataCacheAccessor?

    func makeCacheAccessor(tokenCache: MSIDDefaultTokenCacheAccessor, accountMetadataCache: MSIDAccountMetadataCacheAccessor) -> MSAL.MSALNativeAuthCacheAccessor {
        self.tokenCache = tokenCache
        self.accountMetadataCache = accountMetadataCache

        return MSALNativeAuthCacheAccessor(tokenCache: tokenCache, accountMetadataCache: accountMetadataCache)
    }
}
