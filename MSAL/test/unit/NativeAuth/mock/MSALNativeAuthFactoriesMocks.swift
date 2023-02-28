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

class MSALNativeAuthRequestControllerFactoryFail: MSALNativeAuthRequestControllerBuildable {

    func makeSignUpController(with context: MSIDRequestContext) -> MSAL.MSALNativeAuthSignUpControlling {
        XCTFail("This method should not be called")
        return MSALNativeAuthSignUpController(
            configuration: MSALNativeAuthConfigStubs.configuration,
            authority: MSALNativeAuthNetworkStubs.authority,
            context: MSALNativeAuthRequestContextMock()
        )
    }

    func makeSignInController(with context: MSIDRequestContext) -> MSAL.MSALNativeAuthSignInControlling {
        XCTFail("This method should not be called")
        return MSALNativeAuthSignInController(
            configuration: MSALNativeAuthConfigStubs.configuration,
            authority: MSALNativeAuthNetworkStubs.authority,
            context: MSALNativeAuthRequestContextMock()
        )
    }

    func makeResendCodeController(with context: MSIDRequestContext) -> MSAL.MSALNativeAuthResendCodeControlling {
        XCTFail("This method should not be called")
        return MSALNativeAuthResendCodeController(
            configuration: MSALNativeAuthConfigStubs.configuration,
            authority: MSALNativeAuthNetworkStubs.authority,
            context: MSALNativeAuthRequestContextMock()
        )
    }

    func makeVerifyCodeController(with context: MSIDRequestContext) -> MSAL.MSALNativeAuthVerifyCodeControlling {
        XCTFail("This method should not be called")
        return MSALNativeAuthVerifyCodeController(
            configuration: MSALNativeAuthConfigStubs.configuration,
            authority: MSALNativeAuthNetworkStubs.authority,
            context: MSALNativeAuthRequestContextMock()
        )
    }
}

class MSALNativeAuthResultFactoryMock: MSALNativeAuthResultBuildable {

    private(set) var makeNativeAuthResponseResult: MSALNativeAuthResponse!
    private(set) var makeMsidConfigurationResult: MSIDConfiguration!

    func mockMakeNativeAuthResponse(_ result: MSALNativeAuthResponse) {
        self.makeNativeAuthResponseResult = result
    }

    func makeNativeAuthResponse(
        stage: MSALNativeAuthResponse.Stage,
        credentialToken: String?,
        tokenResult: MSIDTokenResult
    ) -> MSALNativeAuthResponse {
        return makeNativeAuthResponseResult
    }

    func mockMakeMsidConfigurationFunc(_ result: MSIDConfiguration) {
        self.makeMsidConfigurationResult = result
    }

    func makeMSIDConfiguration(scope: [String]) -> MSIDConfiguration {
        return makeMsidConfigurationResult
    }
}
