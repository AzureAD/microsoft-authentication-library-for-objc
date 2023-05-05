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
        let scopes = intersectScopes(scopes)
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdSignIn,
            context: context
        )
        startTelemetryEvent(telemetryEvent, context: context)
        guard let request = createTokenRequest(
            username: username,
            password: password,
            challengeTypes: challengeTypes,
            scopes: scopes,
            context: context
        ) else {

            stopTelemetryEvent(telemetryEvent, context: context, error: MSALNativeAuthError.invalidRequest)
            delegate.onSignInError(error: SignInStartError(type: .generalError))
            return
        }

        performRequest(request) { [self] aadTokenResponse in
            let config = factory.makeMSIDConfiguration(scope: scopes)
            let result = responseValidator.validateSignInTokenResponse(
                context: context,
                msidConfiguration: config,
                result: aadTokenResponse
            )
            switch result {
            case .success(let validatedTokenResult, let tokenResponse):
                telemetryEvent?.setUserInformation(validatedTokenResult.account)
                cacheTokenResponse(tokenResponse, context: context, msidConfiguration: config)
                let account = factory.makeUserAccount(tokenResult: validatedTokenResult)
                delegate.onSignInCompleted(result: account)
            case .credentialRequired(let credentialToken):
                let challengeRequest = createChallengeRequest(
                    credentialToken: credentialToken,
                    challengeTypes: challengeTypes,
                    context: context)
                print("credential required")
                //use the credential token to call /challenge API
                //create the new state and return it to the delegate
            case .error(let errorType):
                delegate.onSignInError(error: generateSignInStartErrorFrom(signInTokenErrorType: errorType))
            }
        }
    }

    func signIn(
        username: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType],
        correlationId: UUID?,
        scopes: [String]?,
        delegate: SignInStartDelegate) {
            // call here /initiate
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

    private func createChallengeRequest(
        credentialToken: String,
        challengeTypes: [MSALNativeAuthInternalChallengeType],
        context: MSIDRequestContext
    ) -> MSALNativeAuthSignInChallengeRequest? {
        do {
            return try requestProvider.signInChallengeRequest(
                credentialToken: credentialToken,
                challengeTypes: challengeTypes,
                context: context)
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Token Request: \(error)")
            return nil
        }
    }

    private func generateSignInStartErrorFrom(
        signInTokenErrorType: MSALNativeAuthSignInTokenValidatedErrorType
    ) -> SignInStartError {
        switch signInTokenErrorType {
        case .generalError, .expiredToken, .authorizationPending, .slowDown, .invalidRequest, .invalidServerResponse:
            return SignInStartError(type: .generalError)
        case .invalidClient:
            return SignInStartError(type: .generalError, message: "Invalid Client ID")
        case .unsupportedChallengeType:
            return SignInStartError(type: .generalError, message: "Unsupported challenge type")
        case .invalidScope:
            return SignInStartError(type: .generalError, message: "Invalid scope")
        case .userNotFound:
            return SignInStartError(type: .userNotFound)
        case .invalidPassword:
            return SignInStartError(type: .invalidPassword)
        case .invalidAuthenticationType:
            return SignInStartError(type: .invalidAuthenticationType)
        }
    }

    private func intersectScopes(_ scopes: [String]?) -> [String] {
        let defaultOIDCScopes = MSALPublicClientApplication.defaultOIDCScopes()
        guard let scopes = scopes else {
            return Array(_immutableCocoaArray: defaultOIDCScopes)
        }
        let intersectedScopes = NSOrderedSet(array: scopes)
        intersectedScopes.intersects(defaultOIDCScopes)
        return Array(_immutableCocoaArray: intersectedScopes)
    }
}
