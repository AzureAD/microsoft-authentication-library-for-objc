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

protocol MSALNativeAuthSignInControlling {
    func signIn(
        parameters: MSALNativeAuthSignInParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    )
}

final class MSALNativeAuthSignInController: MSALNativeAuthBaseController, MSALNativeAuthSignInControlling {

    // MARK: - Variables

    private typealias SignInCompletionHandler = (Result<MSIDAADTokenResponse, Error>) -> Void

    private let requestProvider: MSALNativeAuthRequestProviding
    private let cacheAccessor: MSALNativeAuthCacheInterface
    private let responseHandler: MSALNativeAuthResponseHandling
    private let authority: MSALNativeAuthAuthority
    private let factory: MSALNativeAuthResultBuildable

    // MARK: - Init

    init(
        configuration: MSALNativeAuthPublicClientApplicationConfig,
        requestProvider: MSALNativeAuthRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        responseHandler: MSALNativeAuthResponseHandling,
        authority: MSALNativeAuthAuthority,
        context: MSIDRequestContext,
        factory: MSALNativeAuthResultBuildable
    ) {
        self.requestProvider = requestProvider
        self.cacheAccessor = cacheAccessor
        self.responseHandler = responseHandler
        self.authority = authority
        self.factory = factory

        super.init(configuration: configuration, context: context)
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
            authority: authority,
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
            telemetryApiId: .telemetryApiIdSignIn
        )
        startTelemetryEvent(telemetryEvent)

        func completeWithTelemetry(_ response: MSALNativeAuthResponse?, _ error: Error?) {
            stopTelemetryEvent(telemetryEvent, error: error)
            completion(response, error)
        }

        guard let request = createRequest(with: parameters) else {
            return completeWithTelemetry(nil, MSALNativeAuthError.invalidRequest)
        }

        performRequest(request) { [self] result in

            switch result {
            case .success(let tokenResponse):
                let msidConfiguration = factory.makeMSIDConfiguration(scope: parameters.scopes)

                guard let tokenResult = handleResponse(tokenResponse, msidConfiguration: msidConfiguration) else {
                    return completeWithTelemetry(nil, MSALNativeAuthError.validationError)
                }

                telemetryEvent?.setUserInformation(tokenResult.account)

                cacheTokenResponse(tokenResponse, msidConfiguration: msidConfiguration)

                let response = factory.makeNativeAuthResponse(
                    stage: .completed,
                    credentialToken: nil,
                    tokenResult: tokenResult
                )

                completeWithTelemetry(response, nil)

            case .failure(let error):
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignIn request error: \(error)"
                )

                completeWithTelemetry(nil, error)
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

    private func performRequest(_ request: MSALNativeAuthSignInRequest, completion: @escaping SignInCompletionHandler) {
        request.send { [self] response, error in

            if let error = error {
                return completion(.failure(error))
            }

            guard let responseDict = response as? [AnyHashable: Any] else {
                return completion(.failure(MSALNativeAuthError.invalidResponse))
            }

            do {
                let tokenResponse = try MSIDAADTokenResponse(jsonDictionary: responseDict)
                tokenResponse.correlationId = context.correlationId().uuidString
                completion(.success(tokenResponse))
            } catch {
                completion(.failure(MSALNativeAuthError.invalidResponse))
            }
        }
    }

    private func handleResponse(
        _ tokenResponse: MSIDTokenResponse,
        msidConfiguration: MSIDConfiguration
    ) -> MSIDTokenResult? {
        do {
            return try responseHandler.handle(
                context: context,
                accountIdentifier: .init(displayableId: "mock-displayable-id", homeAccountId: "mock-home-account"),
                tokenResponse: tokenResponse,
                configuration: msidConfiguration,
                validateAccount: true
            )
        } catch {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Response validation error: \(error)"
            )
            return nil
        }
    }

    private func cacheTokenResponse(_ tokenResponse: MSIDTokenResponse, msidConfiguration: MSIDConfiguration) {
        do {
            try cacheAccessor.saveTokensAndAccount(
                tokenResult: tokenResponse,
                configuration: msidConfiguration,
                context: context
            )
        } catch {

            // Note, if there's an error saving result, we log it, but we don't return an error
            // This is by design because even if we fail to cache, we still should return tokens back to the app

            MSALLogger.log(
                level: .error,
                context: context,
                format: "Error caching response: \(error)"
            )
        }
    }
}
