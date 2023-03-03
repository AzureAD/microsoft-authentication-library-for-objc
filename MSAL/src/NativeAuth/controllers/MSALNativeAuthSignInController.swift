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
        parameters: MSALNativeAuthSignInParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    )
}

final class MSALNativeAuthSignInController: MSALNativeAuthBaseController, MSALNativeAuthSignInControlling {

    // MARK: - Variables

    private let requestProvider: MSALNativeAuthRequestProviding
    private let factory: MSALNativeAuthResultBuildable

    // MARK: - Init

    init(
        configuration: MSALNativeAuthPublicClientApplicationConfig,
        requestProvider: MSALNativeAuthRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        responseHandler: MSALNativeAuthResponseHandling,
        context: MSIDRequestContext,
        factory: MSALNativeAuthResultBuildable
    ) {
        self.requestProvider = requestProvider
        self.factory = factory

        super.init(
            configuration: configuration,
            context: context,
            responseHandler: responseHandler,
            cacheAccessor: cacheAccessor
        )
    }

    convenience init(
        configuration: MSALNativeAuthPublicClientApplicationConfig,
        authority: MSALNativeAuthAuthority,
        context: MSIDRequestContext
    ) {
        self.init(
            configuration: configuration,
            requestProvider: MSALNativeAuthRequestProvider(
                clientId: configuration.clientId,
                authority: authority
            ),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            responseHandler: MSALNativeAuthResponseHandler(),
            context: context,
            factory: MSALNativeAuthResultFactory(
                authority: authority,
                configuration: configuration
            )
        )
    }

    // MARK: - Internal

    func signIn(
        parameters: MSALNativeAuthSignInParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    ) {
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdSignIn // TODO: Update local telemetry event id to differentiate sign-in with password and otp
        )
        startTelemetryEvent(telemetryEvent)

        guard let request = createRequest(with: parameters) else {
            complete(telemetryEvent, error: MSALNativeAuthError.invalidRequest, completion: completion)
            return
        }

        performRequest(request) { [self] result in

            switch result {
            case .success(let tokenResponse):
                let msidConfiguration = factory.makeMSIDConfiguration(scope: parameters.scopes)

                guard let tokenResult = handleResponse(tokenResponse, msidConfiguration: msidConfiguration) else {
                    complete(telemetryEvent, error: MSALNativeAuthError.validationError, completion: completion)
                    return
                }

                telemetryEvent?.setUserInformation(tokenResult.account)

                cacheTokenResponse(tokenResponse, msidConfiguration: msidConfiguration)

                let response = factory.makeNativeAuthResponse(
                    stage: .completed,
                    credentialToken: nil,
                    tokenResult: tokenResult
                )

                complete(telemetryEvent, response: response, completion: completion)

            case .failure(let error):
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignIn request error: \(error)"
                )

                complete(telemetryEvent, error: error, completion: completion)
            }
        }
    }

    // MARK: - Private

    private func createRequest(with parameters: MSALNativeAuthSignInParameters) -> MSALNativeAuthSignInRequest? {
        do {
            return try requestProvider.signInRequest(
                parameters: parameters,
                context: context
            )
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignIn Request: \(error)")
            return nil
        }
    }
}
