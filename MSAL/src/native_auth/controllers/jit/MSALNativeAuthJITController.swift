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

@_implementationOnly import MSAL_Private

// swiftlint:disable:next type_body_length
final class MSALNativeAuthJITController: MSALNativeAuthBaseController, MSALNativeAuthJITControlling {

    // MARK: - Variables

    private let jitRequestProvider: MSALNativeAuthJITRequestProviding
    private let jitResponseValidator: MSALNativeAuthJITResponseValidating
    private let signInController: MSALNativeAuthSignInControlling

    // MARK: - Init

    init(
        clientId: String,
        jitRequestProvider: MSALNativeAuthJITRequestProviding,
        jitResponseValidator: MSALNativeAuthJITResponseValidating,
        signInController: MSALNativeAuthSignInControlling
    ) {
        self.jitRequestProvider = jitRequestProvider
        self.jitResponseValidator = jitResponseValidator
        self.signInController = signInController
        super.init(clientId: clientId)
    }

    convenience init(config: MSALNativeAuthConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
        self.init(
            clientId: config.clientId,
            jitRequestProvider: MSALNativeAuthJITRequestProvider(
                requestConfigurator: MSALNativeAuthRequestConfigurator(config: config)),
            jitResponseValidator: MSALNativeAuthJITResponseValidator(),
            signInController: MSALNativeAuthSignInController(config: config, cacheAccessor: cacheAccessor)
        )
    }

    func getJITAuthMethods(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> JITGetJITAuthMethodsControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdJITIntrospect, context: context)
        let result = await performAndValidateIntrospectRequest(continuationToken: continuationToken, context: context)
        let telemetryInfo = TelemetryInfo(event: event, context: context)
        switch result {
        case .authMethodsRetrieved(let newContinuationToken, let authMethods):
            return .init(.selectionRequired(
                authMethods: authMethods.map({$0.toPublicAuthMethod()}),
                continuationToken: newContinuationToken
            ), correlationId: telemetryInfo.context.correlationId(),
            telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
            })
        case .error(let error):
            MSALLogger.logPII(
                level: .error,
                context: telemetryInfo.context,
                format: "JIT: an error occurred after calling /introspect API: \(MSALLogMask.maskPII(error))"
            )
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.error(error: error), correlationId: context.correlationId())
        }
    }

    // swiftlint:disable:next function_parameter_count
    func requestJITChallenge(
        username: String,
        continuationToken: String,
        scopes: [String]?,
        claimsRequestJson: String?,
        authMethod: MSALAuthMethod,
        verificationContact: String?,
        context: MSALNativeAuthRequestContext
    ) async -> JITRequestChallengeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdJITChallenge, context: context)
        let result = await performAndValidateChallengeRequest(
            continuationToken: continuationToken,
            authMethod: authMethod,
            verificationContact: verificationContact,
            context: context,
            logErrorMessage: "JIT RequestChallenge: cannot create challenge request object"
        )
        switch result {
        case .error(let challengeError):
            let error = challengeError.convertToRegisterStrongAuthChallengeError(correlationId: context.correlationId())
            MSALLogger.logPII(
                level: .error,
                context: context,
                format: "JIT request challenge: received challenge error response: \(MSALLogMask.maskPII(error.errorDescription))"
            )
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(
                error: error,
                newState: RegisterStrongAuthState(
                    controller: self,
                    username: username,
                    scopes: scopes,
                    claimsRequestJson: claimsRequestJson,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId()
                )
            ), correlationId: context.correlationId())
        case .codeRequired(let newContinuationToken, let sentTo, let channelType, let codeLength):
            let state = RegisterStrongAuthVerificationRequiredState(
                controller: self,
                username: username,
                scopes: scopes,
                claimsRequestJson: claimsRequestJson,
                continuationToken: newContinuationToken,
                correlationId: context.correlationId()
            )
            return .init(
                .verificationRequired(
                    sentTo: sentTo,
                    channelTargetType: channelType,
                    codeLength: codeLength,
                    newState: state
                ),
                correlationId: context.correlationId(),
                telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                })
        }
    }

    func submitJITChallenge(
        username: String,
        challenge: String,
        continuationToken: String,
        scopes: [String]?,
        claimsRequestJson: String?,
        context: MSALNativeAuthRequestContext
    ) async -> JITSubmitChallengeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdJITContinue, context: context)
        let result = await performAndValidateContinueRequest(
            continuationToken: continuationToken,
            grantType: .oobCode,
            context: context,
            oobCode: challenge,
            logErrorMessage: "JIT RequestContinue: cannot create challenge request object"
        )
        switch result {
        case .error(let continueError):
            let error = continueError.convertToRegisterStrongAuthSubmitChallengeError(correlationId: context.correlationId())
            MSALLogger.logPII(
                level: .error,
                context: context,
                format: "JIT request continue: received continue error response: \(MSALLogMask.maskPII(error.errorDescription))"
            )
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(
                error: error,
                newState: RegisterStrongAuthVerificationRequiredState(
                    controller: self,
                    username: username,
                    scopes: scopes,
                    claimsRequestJson: claimsRequestJson,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId()
                )
            ), correlationId: context.correlationId())
        case .success(let newContinuationToken):
            let response = await signInController.signIn(username: username,
                                                         continuationToken: newContinuationToken,
                                                         scopes: scopes,
                                                         claimsRequestJson: claimsRequestJson,
                                                         telemetryId: .telemetryApiISignInAfterJIT,
                                                         context: context)
            switch response.result {
            case .success(let account):
                return .init(.completed(account), correlationId: context.correlationId())
            case .failure(let error):
                return .init(.error(error: .init(type: .generalError,
                                                 message: error.errorDescription,
                                                 correlationId: error.correlationId,
                                                 errorCodes: error.errorCodes,
                                                 errorUri: error.errorUri),
                                    newState: nil),
                             correlationId: context.correlationId())
            }
        }
    }

    // MARK: - Private

    private func performAndValidateIntrospectRequest(
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) async -> MSALNativeAuthJITIntrospectValidatedResponse {
        guard let introspectRequest = createIntrospectRequest(
            continuationToken: continuationToken,
            context: context
        ) else {
            MSALLogger.log(level: .error, context: context, format: "Unable to create signIn/introspect request")
            return .error(.invalidRequest(.init()))
        }
        let introspectResponse: Result<MSALNativeAuthJITIntrospectResponse, Error> = await performRequest(introspectRequest, context: context)
        let validationResponse = jitResponseValidator.validateIntrospect(context: context, result: introspectResponse)
        return validationResponse
    }

    private func performAndValidateChallengeRequest(
        continuationToken: String,
        authMethod: MSALAuthMethod,
        verificationContact: String?,
        context: MSALNativeAuthRequestContext,
        logErrorMessage: String,
        mfaAuthMethodId: String? = nil
    ) async -> MSALNativeAuthJITChallengeValidatedResponse {
        guard let challengeRequest = createChallengeRequest(
            continuationToken: continuationToken,
            authMethod: authMethod,
            verificationContact: verificationContact,
            context: context
        ) else {
            MSALLogger.log(level: .error, context: context, format: logErrorMessage)
            return .error(.invalidRequest(.init()))
        }
        let challengeResponse: Result<MSALNativeAuthJITChallengeResponse, Error> = await performRequest(challengeRequest, context: context)
        return jitResponseValidator.validateChallenge(context: context, result: challengeResponse)
    }

    private func performAndValidateContinueRequest(
        continuationToken: String,
        grantType: MSALNativeAuthGrantType,
        context: MSALNativeAuthRequestContext,
        oobCode: String,
        logErrorMessage: String
    ) async -> MSALNativeAuthJITContinueValidatedResponse {
        guard let continueRequest = createContinueRequest(
            continuationToken: continuationToken,
            grantType: grantType,
            context: context,
            oobCode: oobCode
        ) else {
            MSALLogger.log(level: .error, context: context, format: logErrorMessage)
            return .error(.invalidRequest(.init()))
        }

        let continueResponse: Result<MSALNativeAuthJITContinueResponse, Error> = await performRequest(continueRequest, context: context)
        return jitResponseValidator.validateContinue(context: context, result: continueResponse)
    }

    private func createIntrospectRequest(continuationToken: String, context: MSALNativeAuthRequestContext) -> MSIDHttpRequest? {
        let params = MSALNativeAuthJITIntrospectRequestParameters(context: context, continuationToken: continuationToken)
        do {
            return try jitRequestProvider.introspect(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating JIT introspect request: \(error)")
            return nil
        }
    }

    private func createChallengeRequest(
        continuationToken: String,
        authMethod: MSALAuthMethod,
        verificationContact: String?,
        context: MSALNativeAuthRequestContext
    ) -> MSIDHttpRequest? {
        do {
            let params = MSALNativeAuthJITChallengeRequestParameters(
                context: context,
                continuationToken: continuationToken,
                authMethod: authMethod,
                verificationContact: verificationContact ?? authMethod.loginHint
            )
            return try jitRequestProvider.challenge(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating JIT Challenge Request: \(error)")
            return nil
        }
    }

    private func createContinueRequest(
        continuationToken: String,
        grantType: MSALNativeAuthGrantType,
        context: MSALNativeAuthRequestContext,
        oobCode: String)
    -> MSIDHttpRequest? {
        let params = MSALNativeAuthJITContinueRequestParameters(context: context,
                                                                grantType: grantType,
                                                                continuationToken: continuationToken,
                                                                oobCode: oobCode)
        do {
            return try jitRequestProvider.continue(parameters: params, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating JIT continue request: \(error)")
            return nil
        }
    }

}
