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

protocol MSALNativeAuthSignInControlling: MSALNativeAuthTokenRequestHandling {
    
    // TODO: add parameter struct or class
    func signIn(
        username: String,
        password: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType],
        correlationId: UUID?,
        scopes: [String]?,
        delegate: SignInStartDelegate)
    
    func signIn(
        username: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType],
        correlationId: UUID?,
        scopes: [String]?,
        delegate: SignInStartDelegate)
}

final class MSALNativeAuthSignInController: MSALNativeAuthBaseController, MSALNativeAuthSignInControlling {
    
    // MARK: - Variables

    private let requestProvider: MSALNativeAuthSignInRequestProvider
    private let factory: MSALNativeAuthResultBuildable
    private let responseValidator: MSALNativeAuthSignInResponseValidating

    // MARK: - Init

    init(
        clientId: String,
        requestProvider: MSALNativeAuthSignInRequestProvider,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable,
        responseValidator: MSALNativeAuthSignInResponseValidating
    ) {
        self.requestProvider = requestProvider
        self.factory = factory
        self.responseValidator = responseValidator
        super.init(
            clientId: clientId,
            cacheAccessor: cacheAccessor
        )
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthSignInRequestProvider(config: config),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            factory: MSALNativeAuthResultFactory(config: config),
            responseValidator: MSALNativeAuthResponseValidator(responseHandler: MSALNativeAuthResponseHandler())
        )
    }

    // MARK: - Internal

    func signIn(
        username: String,
        password: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType],
        correlationId: UUID?,
        scopes: [String]?,
        delegate: SignInStartDelegate
    ) {
        let scopes = scopes ?? defaultScopes()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdSignIn,
            context: context
        )
        startTelemetryEvent(telemetryEvent, context: context)
        guard let request = createTokenRequest(username: username, password: password, challengeTypes: challengeTypes, scopes: scopes, context: context) else {

            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
            delegate.onSignInError(error: SignInStartError(type: .generalError))
            return
        }

        performRequest(request) { [self] result in
            let config = factory.makeMSIDConfiguration(scope: scopes)
            let result = responseValidator.validateSignInTokenResponse(context: context, msidConfiguration: config, result: result)
//            switch result {
//            case .success(let tokenResponse):
//                // create account from tokenResponse. it is already validated
//                delegate.onSignInCompleted(result: MSALNativeAuthUserAccount(username: username, accessToken: tokenResponse.accessToken ?? "Access token"))
//            case .credentialRequired(let credentialToken):
//
//            case .error(let errorType):
//
//            }
            
            
            
            
                // TODO: return error to the delegate, parse the error description/code
//                    //TODO: hit /challenge API
//                    //TODO: create here a new state
//                    let newState = SignInCodeSentState(flowToken: "parses flow token", signInController: self)
//                    //TODO: this should be automated
//                    currentState?.isActive = false
//                    currentState = newState
//                    // TODO: validate that all the required fields are there, and log meaningful error to the API
//                    delegate.onSignInCodeSent(newState: newState, displayName: "parsedDisplayName", codeLength: 4)
//                }
        }
    }
    func signIn(
        username: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType],
        correlationId: UUID?,
        scopes: [String]?,
        delegate: SignInStartDelegate) {
            
        }

    // MARK: - Private

    private func createTokenRequest(username: String,
                                    password: String?,
                                    challengeTypes: [MSALNativeAuthInternalChallengeType],
                                    scopes: [String],
                                    context: MSIDRequestContext) -> MSALNativeAuthSignInTokenRequest? {
        do {
            let params = MSALNativeAuthSignInTokenRequestProviderParams(
                username: username,
                credentialToken: nil,
                signInSLT: nil,
                grantType: .password,
                challengeTypes: challengeTypes,
                scopes: scopes,
                password: password,
                oobCode: nil,
                context: context)
            return try requestProvider.signInTokenRequest(parameters: params)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
            return nil
        }
    }

    private func createChallengeRequest(credentialToken: String,
                                    challengeTypes: [MSALNativeAuthInternalChallengeType],
                                        context: MSIDRequestContext) -> MSALNativeAuthSignInChallengeRequest? {
        do {
            return try requestProvider.signInChallengeRequest(credentialToken: credentialToken, challengeTypes: challengeTypes, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
            return nil
        }
    }

    private func defaultScopes() -> [String] {
        return (Array(MSALPublicClientApplication.defaultOIDCScopes()) as? [String]) ?? []
    }
}
