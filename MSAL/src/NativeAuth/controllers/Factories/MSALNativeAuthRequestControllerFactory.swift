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

@_implementationOnly import MSAL_Private

protocol MSALNativeAuthRequestControllerBuildable {
    func makeSignUpController(with context: MSIDRequestContext) -> MSALNativeAuthSignUpControlling
    func makeSignUpOTPController(with context: MSIDRequestContext) -> MSALNativeAuthSignUpOTPControlling
    func makeSignInController(with context: MSIDRequestContext) -> MSALNativeAuthSignInControlling
    func makeSignInOTPController(with context: MSIDRequestContext) -> MSALNativeAuthSignInOTPControlling
    func makeResendCodeController(with context: MSIDRequestContext) -> MSALNativeAuthResendCodeControlling
    func makeVerifyCodeController(with context: MSIDRequestContext) -> MSALNativeAuthVerifyCodeControlling
}

final class MSALNativeAuthRequestControllerFactory: MSALNativeAuthRequestControllerBuildable {
    private let requestProvider: MSALNativeAuthRequestProviding
    private let cacheGateway: MSALNativeAuthCacheInterface
    private let responseHandler: MSALNativeAuthResponseHandling
    private let configuration: MSALNativeAuthPublicClientApplicationConfig
    private let authority: MSALNativeAuthAuthority

    init(
        requestProvider: MSALNativeAuthRequestProviding,
        cacheGateway: MSALNativeAuthCacheInterface,
        responseHandler: MSALNativeAuthResponseHandling,
        configuration: MSALNativeAuthPublicClientApplicationConfig,
        authority: MSALNativeAuthAuthority
    ) {
        self.requestProvider = requestProvider
        self.cacheGateway = cacheGateway
        self.responseHandler = responseHandler
        self.configuration = configuration
        self.authority = authority
    }

    func makeSignUpController(with context: MSIDRequestContext) -> MSALNativeAuthSignUpControlling {
        return MSALNativeAuthSignUpController(
            configuration: configuration,
            authority: authority,
            context: context
        )
    }

    func makeSignUpOTPController(with context: MSIDRequestContext) -> MSALNativeAuthSignUpOTPControlling {
        return MSALNativeAuthSignUpOTPController(
            configuration: configuration,
            authority: authority,
            context: context
        )
    }

    func makeSignInController(with context: MSIDRequestContext) -> MSALNativeAuthSignInControlling {
        return MSALNativeAuthSignInController(
            configuration: configuration,
            authority: authority,
            context: context
        )
    }

    func makeSignInOTPController(with context: MSIDRequestContext) -> MSALNativeAuthSignInOTPControlling {
        return MSALNativeAuthSignInOTPController(
            configuration: configuration,
            authority: authority,
            context: context
        )
    }

    func makeResendCodeController(with context: MSIDRequestContext) -> MSALNativeAuthResendCodeControlling {
        return MSALNativeAuthResendCodeController(
            configuration: configuration,
            authority: authority,
            context: context
        )
    }

    func makeVerifyCodeController(with context: MSIDRequestContext) -> MSALNativeAuthVerifyCodeControlling {
        return MSALNativeAuthVerifyCodeController(
            configuration: configuration,
            authority: authority,
            context: context
        )
    }
}
