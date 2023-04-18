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
    
    // TODO: add ad-hoc method for OTP and pwd?
    func signIn(
        username: String,
        password: String?,
        challengeTypes: [MSALNativeAuthInternalChallengeType],
        correlationId: UUID?,
        scopes: [String]?,
        delegate: SignInStartDelegate
    )
}

final class MSALNativeAuthSignInController: MSALNativeAuthBaseController, MSALNativeAuthSignInControlling {

    // MARK: - Variables

    private let requestProvider: MSALNativeAuthSignInRequestProvider
    private let factory: MSALNativeAuthResultBuildable
    // TODO: is this the right place to keep the state? What if we add it to publicClientApplication class?
    // add it to the super class?
    private weak var currentState: MSALNativeAuthBaseState?

    // MARK: - Init

    init(
        clientId: String,
        requestProvider: MSALNativeAuthSignInRequestProvider,
        cacheAccessor: MSALNativeAuthCacheInterface,
        responseHandler: MSALNativeAuthResponseHandling,
        context: MSIDRequestContext,
        factory: MSALNativeAuthResultBuildable
    ) {
        self.requestProvider = requestProvider
        self.factory = factory

        super.init(
            clientId: clientId,
            context: context,
            responseHandler: responseHandler,
            cacheAccessor: cacheAccessor
        )
    }

    convenience init(config: MSALNativeAuthConfiguration, context: MSIDRequestContext) {
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthSignInRequestProvider(config: config),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            responseHandler: MSALNativeAuthResponseHandler(),
            context: context,
            factory: MSALNativeAuthResultFactory(config: config)
        )
    }

    // MARK: - Internal
    
    func signIn(username: String, password: String?, challengeTypes: [MSALNativeAuthInternalChallengeType], correlationId: UUID?, scopes: [String]?, delegate: SignInStartDelegate) {
        // start telemetry ?
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdSignIn // TODO: Add signIn token
        )
        startTelemetryEvent(telemetryEvent)
        guard let request = createTokenRequest(username: username, password: password, challengeTypes: challengeTypes, scopes: scopes) else {

            stopTelemetryEvent(telemetryEvent, error: MSALNativeAuthError.invalidRequest)
            delegate.onSignInError(error: SignInStartError(type: .generalError))
            return
        }

        performRequest(request) { [self] result in
            switch result {
            case .success(let tokenResponse):
                delegate.onSignInCompleted(result: MSALNativeAuthUserAccount(username: username, accessToken: tokenResponse.accessToken ?? "use guard here"))
            case .failure(let signInTokenResponseError):
                // this should be MSALNativeAuthSignInTokenResponseError
                guard let signInTokenResponseError = signInTokenResponseError as? MSALNativeAuthSignInTokenResponseError else {
                    delegate.onSignInError(error: SignInStartError(type: .generalError))
                    return
                }
                // TODO: return error to the delegate, parse the error description/code
                switch signInTokenResponseError.error {
                case .invalidRequest:
                    <#code#>
                case .invalidClient:
                    <#code#>
                case .invalidGrant:
                    <#code#>
                case .expiredToken:
                    <#code#>
                case .unsupportedChallengeType:
                    <#code#>
                case .invalidScope:
                    <#code#>
                case .authorizationPending:
                    <#code#>
                case .slowDown:
                    <#code#>
                case .credentialRequired:
                    //TODO: hit /challenge API
                    //TODO: create here a new state
                    let newState = SignInCodeSentState(flowToken: "parses flow token", signInController: self)
                    //TODO: this should be automated
                    currentState?.isActive = false
                    currentState = newState
                    delegate.onSignInCodeSent(newState: newState, displayName: "parsedDisplayName", codeLength: 4)
                }
            }
        }
    }

    // MARK: - Private

    private func createTokenRequest(username: String,
                                    password: String?,
                                    challengeTypes: [MSALNativeAuthInternalChallengeType],
                                    scopes: [String]?) -> MSALNativeAuthSignInTokenRequest? {
        // TODO: do we need SDK default scope or we can omit it from the request?
        do {
            // TODO: create parameter class?
            return try requestProvider.signInTokenRequest(username: username, credentialToken: nil, signInSLT: nil, grantType: .password, challengeTypes: challengeTypes, scopes: scopes ?? [""], password: password, oobCode: nil, context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
            return nil
        }
    }
}
