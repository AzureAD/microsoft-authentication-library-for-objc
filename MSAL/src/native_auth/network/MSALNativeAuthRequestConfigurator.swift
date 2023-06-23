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

@_implementationOnly import MSAL_Private

enum MSALNativeAuthRequestConfiguratorType {
    enum SignUp {
        case start(MSALNativeAuthSignUpStartRequestParameters)
        case challenge(MSALNativeAuthSignUpChallengeRequestParameters)
        case `continue`(MSALNativeAuthSignUpContinueRequestParameters)
    }

    enum SignIn {
        case initiate(MSALNativeAuthSignInInitiateRequestParameters)
        case challenge(MSALNativeAuthSignInChallengeRequestParameters)
    }

    enum ResetPassword {
        case start(MSALNativeAuthResetPasswordStartRequestParameters)
        case challenge(MSALNativeAuthResetPasswordChallengeRequestParameters)
        case `continue`(MSALNativeAuthResetPasswordContinueRequestParameters)
        case submit(MSALNativeAuthResetPasswordSubmitRequestParameters)
        case pollCompletion(MSALNativeAuthResetPasswordPollCompletionRequestParameters)
    }

    enum Token {
        case signInWithPassword(MSALNativeAuthTokenRequestParameters)
        case refreshToken(MSALNativeAuthTokenRequestParameters)
    }

    case signUp(SignUp)
    case signIn(SignIn)
    case resetPassword(ResetPassword)
    case token(Token)
}

class MSALNativeAuthRequestConfigurator: MSIDAADRequestConfigurator {
    let config: MSALNativeAuthConfiguration

    init(config: MSALNativeAuthConfiguration) {
        self.config = config
    }

    func configure(configuratorType: MSALNativeAuthRequestConfiguratorType,
                   request: MSIDHttpRequest,
                   telemetryProvider: MSALNativeAuthTelemetryProviding) throws {
        switch configuratorType {
        case .signUp(let subType):
            try signUpConfigure(subType, request, telemetryProvider)
        case .signIn(let subType):
            try signInConfigure(subType, request, telemetryProvider)
        case .resetPassword(let subType):
            try resetPasswordConfigure(subType, request, telemetryProvider)
        case .token(let subType):
            try tokenConfigure(subType, request, telemetryProvider)
        }
    }

    private func signUpConfigure(_ subType: MSALNativeAuthRequestConfiguratorType.SignUp,
                                 _ request: MSIDHttpRequest,
                                 _ telemetryProvider: MSALNativeAuthTelemetryProviding) throws {
        switch subType {
        case .start(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthSignUpStartResponse>()
            let telemetry = telemetryProvider.telemetryForSignUp(type: .signUpStart)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignUpStartResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .challenge(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthSignUpChallengeResponse>()
            let telemetry = telemetryProvider.telemetryForSignUp(type: .signUpChallenge)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignUpChallengeResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .continue(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthSignUpContinueResponse>()
            let telemetry = telemetryProvider.telemetryForSignUp(type: .signUpContinue)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignUpContinueResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        }
    }

    private func signInConfigure(_ subType: MSALNativeAuthRequestConfiguratorType.SignIn,
                                 _ request: MSIDHttpRequest,
                                 _ telemetryProvider: MSALNativeAuthTelemetryProviding) throws {
        switch subType {
        case .initiate(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthSignInInitiateResponse>()
            let telemetry = telemetryProvider.telemetryForSignIn(type: .signInInitiate)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignInInitiateResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .challenge(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthSignInChallengeResponse>()
            let telemetry = telemetryProvider.telemetryForSignIn(type: .signInChallenge)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignInChallengeResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        }
    }

    private func resetPasswordConfigure(_ subType: MSALNativeAuthRequestConfiguratorType.ResetPassword,
                                        _ request: MSIDHttpRequest,
                                        _ telemetryProvider: MSALNativeAuthTelemetryProviding) throws {
        switch subType {
        case .start(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResetPasswordStartResponse>()
            let telemetry = telemetryProvider.telemetryForResetPassword(type: .resetPasswordStart)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthResetPasswordStartResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .challenge(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResetPasswordChallengeResponse>()
            let telemetry = telemetryProvider.telemetryForResetPassword(type: .resetPasswordChallenge)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthResetPasswordChallengeResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .continue(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResetPasswordContinueResponse>()
            let telemetry = telemetryProvider.telemetryForResetPassword(type: .resetPasswordContinue)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthResetPasswordContinueResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .submit(let parameters):
            let responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResetPasswordSubmitResponse>()
            let telemetry = telemetryProvider.telemetryForResetPassword(type: .resetPasswordSubmit)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthResetPasswordSubmitResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .pollCompletion(let parameters):
            let responseSerializer =
            MSALNativeAuthResponseSerializer<MSALNativeAuthResetPasswordPollCompletionResponse>()
            let telemetry = telemetryProvider.telemetryForResetPassword(type: .resetPasswordPollCompletion)
            let errorHandler =
            MSALNativeAuthResponseErrorHandler<MSALNativeAuthResetPasswordPollCompletionResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          responseSerializer: responseSerializer,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        }
    }

    private func tokenConfigure(_ subType: MSALNativeAuthRequestConfiguratorType.Token,
                                _ request: MSIDHttpRequest,
                                _ telemetryProvider: MSALNativeAuthTelemetryProviding) throws {
        switch subType {
        case .signInWithPassword(let parameters):
            let telemetry = telemetryProvider.telemetryForToken(type: .signInWithPassword)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthTokenResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        case .refreshToken(let parameters):
            let telemetry = telemetryProvider.telemetryForToken(type: .refreshToken)
            let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthTokenResponseError>()
            try configure(request: request,
                          parameters: parameters,
                          telemetry: telemetry,
                          errorHandler: errorHandler)
        }
    }

    private func configure<R: Decodable, E: Decodable & Error>(
        request: MSIDHttpRequest,
        parameters: MSALNativeAuthRequestable,
        responseSerializer: MSALNativeAuthResponseSerializer<R>,
        telemetry: MSALNativeAuthCurrentRequestTelemetry,
        errorHandler: MSALNativeAuthResponseErrorHandler<E>
    ) throws {
        try configure(request: request,
                      parameters: parameters,
                      telemetry: telemetry,
                      errorHandler: errorHandler)
        request.responseSerializer = responseSerializer
    }

    // For the SignInToken endpoint the Response serialiser should not be set
    // Because we cannot have optional Generic Types parameters at call time
    // especially with Decodable we have to have another method name
    // This might be removed in the future if the response from the /token endpoint changes
    private func configure<E: Decodable & Error>(
        request: MSIDHttpRequest,
        parameters: MSALNativeAuthRequestable,
        telemetry: MSALNativeAuthCurrentRequestTelemetry,
        errorHandler: MSALNativeAuthResponseErrorHandler<E>
    ) throws {
        try configureAllRequests(request: request, parameters: parameters)
        request.requestSerializer = MSALNativeAuthUrlRequestSerializer(
            context: parameters.context,
            encoding: .wwwFormUrlEncoded
        )
        request.serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetry,
            context: parameters.context
        )
        request.errorHandler = errorHandler
    }

    private func configureAllRequests(request: MSIDHttpRequest,
                                      parameters: MSALNativeAuthRequestable) throws {
        request.context = parameters.context
        request.parameters = parameters.makeRequestBody(config: config)

        do {
            let endpointUrl = try parameters.makeEndpointUrl(config: config)
            request.urlRequest = URLRequest(url: endpointUrl)
            request.urlRequest?.httpMethod = MSALParameterStringForHttpMethod(.POST)
        } catch {
            MSALLogger.log(
                level: .error,
                context: parameters.context,
                format: "Endpoint could not be created: \(error)"
            )
            throw MSALNativeAuthInternalError.invalidRequest
        }
        configure(request)
    }
}
