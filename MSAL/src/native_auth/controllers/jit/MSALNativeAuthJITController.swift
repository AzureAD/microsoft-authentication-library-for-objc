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

    convenience init(config: MSALNativeAuthInternalConfiguration, cacheAccessor: MSALNativeAuthCacheInterface) {
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
            let state = RegisterStrongAuthState(
                controller: self,
                continuationToken: newContinuationToken,
                correlationId: telemetryInfo.context.correlationId()
            )
            return .init(.selectionRequired(
                authMethods: authMethods.map({$0.toPublicAuthMethod()}),
                newState: state
            ), correlationId: telemetryInfo.context.correlationId(),
            telemetryUpdate: { [weak self] result in
                self?.stopTelemetryEvent(telemetryInfo.event, context: telemetryInfo.context, delegateDispatcherResult: result)
            })
        case .error(let error):
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: telemetryInfo.context,
                format: "RegisterStrongAuth: an error occurred after calling /introspect API: \(MSALLogMask.maskPII(error))"
            )
            stopTelemetryEvent(telemetryInfo, error: error)
            return .init(.error(error: error), correlationId: context.correlationId())
        }
    }

    func requestJITChallenge(
        continuationToken: String,
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
            logErrorMessage: "Request RegisterStrongAuth Challenge: cannot create challenge request object"
        )
        return await handleChallengeResponse(
            result,
            continuationToken: continuationToken,
            event: event,
            context: context)
    }

    func submitJITChallenge(
        challenge: String?,
        continuationToken: String,
        grantType: MSALNativeAuthGrantType,
        context: MSALNativeAuthRequestContext
    ) async -> JITSubmitChallengeControllerResponse {
        let event = makeAndStartTelemetryEvent(id: .telemetryApiIdJITContinue, context: context)
        let result = await performAndValidateContinueRequest(
            continuationToken: continuationToken,
            grantType: grantType,
            context: context,
            oobCode: challenge,
            logErrorMessage: "Request RegisterStrongAuth Continue: cannot create challenge request object"
        )
        return await handleSubmitChallengeResponse(
            result,
            continuationToken: continuationToken,
            event: event,
            context: context
        )
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
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Unable to create register/introspect request")
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
        logErrorMessage: String
    ) async -> MSALNativeAuthJITChallengeValidatedResponse {
        guard let challengeRequest = createChallengeRequest(
            continuationToken: continuationToken,
            authMethod: authMethod,
            verificationContact: verificationContact,
            context: context
        ) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: logErrorMessage)
            return .error(.invalidRequest(.init()))
        }
        let challengeResponse: Result<MSALNativeAuthJITChallengeResponse, Error> = await performRequest(challengeRequest, context: context)
        return jitResponseValidator.validateChallenge(context: context, result: challengeResponse)
    }

    private func performAndValidateContinueRequest(
        continuationToken: String,
        grantType: MSALNativeAuthGrantType,
        context: MSALNativeAuthRequestContext,
        oobCode: String?,
        logErrorMessage: String
    ) async -> MSALNativeAuthJITContinueValidatedResponse {
        guard let continueRequest = createContinueRequest(
            continuationToken: continuationToken,
            grantType: grantType,
            context: context,
            oobCode: oobCode
        ) else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: logErrorMessage)
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
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating RegisterStrongAuth Introspect Request: \(error)")
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
            var currentVerificationContact = authMethod.loginHint
            if let verificationContact, !verificationContact.isEmpty {
                currentVerificationContact = verificationContact
            }
            let params = MSALNativeAuthJITChallengeRequestParameters(
                context: context,
                continuationToken: continuationToken,
                authMethod: authMethod,
                verificationContact: currentVerificationContact
            )
            return try jitRequestProvider.challenge(parameters: params, context: context)
        } catch {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating RegisterStrongAuth Challenge Request: \(error)")
            return nil
        }
    }

    private func createContinueRequest(
        continuationToken: String,
        grantType: MSALNativeAuthGrantType,
        context: MSALNativeAuthRequestContext,
        oobCode: String?)
    -> MSIDHttpRequest? {
        let params = MSALNativeAuthJITContinueRequestParameters(context: context,
                                                                grantType: grantType,
                                                                continuationToken: continuationToken,
                                                                oobCode: oobCode)
        do {
            return try jitRequestProvider.continue(parameters: params, context: context)
        } catch {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "Error creating RegisterStrongAuth Continue Request: \(error)")
            return nil
        }
    }

    // swiftlint:disable:next function_body_length
    private func handleSubmitChallengeResponse(
        _ response: MSALNativeAuthJITContinueValidatedResponse,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> JITSubmitChallengeControllerResponse {
        switch response {
        case .error(let continueError):
            let error = continueError.convertToRegisterStrongAuthSubmitChallengeError(correlationId: context.correlationId())
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: context,
                format: "Request RegisterStrongAuth Continue: received continue error response: \(MSALLogMask.maskPII(error.errorDescription))"
            )
            let newState = error.type == .browserRequired ? nil :
                RegisterStrongAuthVerificationRequiredState(
                    controller: self,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId()
                )
            stopTelemetryEvent(event, context: context, error: error)
            return .init(.error(
                error: error,
                newState: newState
            ), correlationId: context.correlationId())
        case .success(let newContinuationToken):
            stopTelemetryEvent(event, context: context)
            let signInEvent = makeAndStartTelemetryEvent(id: .telemetryApiISignInAfterJIT, context: context)
            let response = await signInController.signIn(username: nil,
                                                         grantType: .continuationToken,
                                                         continuationToken: newContinuationToken,
                                                         scopes: nil,
                                                         claimsRequestJson: nil,
                                                         telemetryId: .telemetryApiISignInAfterJIT,
                                                         context: context)
            switch response.result {
            case .completed(let account):
                return .init(.completed(account), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(signInEvent, context: context, delegateDispatcherResult: result)
                })
            case .jitAuthMethodsSelectionRequired(_, _):
                return .init(.error(error: .init(type: .generalError,
                                                 message: "Unexpected result received when trying to signIn: strong authentication method registration required.", // swiftlint:disable:this line_length
                                                 correlationId: context.correlationId(),
                                                 errorCodes: [],
                                                 errorUri: nil),
                                    newState: nil),
                             correlationId: context.correlationId())
            case .error(let error):
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

    // swiftlint:disable:next function_body_length
    private func handleChallengeResponse(
        _ response: MSALNativeAuthJITChallengeValidatedResponse,
        continuationToken: String,
        event: MSIDTelemetryAPIEvent?,
        context: MSALNativeAuthRequestContext
    ) async -> JITRequestChallengeControllerResponse {
        switch response {
        case .error(let challengeError):
            let error = challengeError.convertToRegisterStrongAuthChallengeError(correlationId: context.correlationId())
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: context,
                format: "Request RegisterStrongAuth Challenge: received challenge error response: \(MSALLogMask.maskPII(error.errorDescription))"
            )
            stopTelemetryEvent(event, context: context, error: error)
            let newState = error.type == .browserRequired ? nil :
                RegisterStrongAuthState(
                    controller: self,
                    continuationToken: continuationToken,
                    correlationId: context.correlationId()
                )
            return .init(.error(
                error: error,
                newState: newState
            ), correlationId: context.correlationId())
        case .codeRequired(let newContinuationToken, let sentTo, let channelType, let codeLength):
            let state = RegisterStrongAuthVerificationRequiredState(
                controller: self,
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
        case .preverified(let newContinuationToken):
            stopTelemetryEvent(event, context: context)
            let continueResponse = await submitJITChallenge(challenge: nil,
                                                            continuationToken: newContinuationToken,
                                                            grantType: .continuationToken,
                                                            context: context)
            switch continueResponse.result {
            case .completed(let account):
                return .init(.completed(account), correlationId: context.correlationId(), telemetryUpdate: { [weak self] result in
                    self?.stopTelemetryEvent(event, context: context, delegateDispatcherResult: result)
                })
            case .error(let error, _):
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
}
