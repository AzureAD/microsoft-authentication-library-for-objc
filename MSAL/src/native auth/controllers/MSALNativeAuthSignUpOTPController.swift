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

protocol MSALNativeAuthSignUpOTPControlling: MSALNativeAuthTokenRequestHandling {
    func signUp(
        parameters: MSALNativeAuthSignUpOTPParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    )
}

final class MSALNativeAuthSignUpOTPController: MSALNativeAuthBaseController, MSALNativeAuthSignUpOTPControlling {

    // MARK: - Variables

    private let requestProvider: MSALNativeAuthRequestProviding
    private let factory: MSALNativeAuthResultBuildable

    // MARK: - Init

    init(
        clientId: String,
        requestProvider: MSALNativeAuthRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        factory: MSALNativeAuthResultBuildable
    ) {
        self.requestProvider = requestProvider
        self.factory = factory

        super.init(
            clientId: clientId,
            cacheAccessor: cacheAccessor
        )
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthRequestProvider(config: config),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            factory: MSALNativeAuthResultFactory(config: config)
        )
    }

    // MARK: - Internal

    func signUp(
        parameters: MSALNativeAuthSignUpOTPParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    ) {
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdSignUp,
            context: context
        )
        startTelemetryEvent(telemetryEvent, context: context)

        guard let request = createRequest(with: parameters, context: context) else {
            complete(telemetryEvent, error: MSALNativeAuthError.invalidRequest, context: context, completion: completion)
            return
        }

        performRequest(request) { [self] result in
            switch result {
            case .success(let tokenResponse):

                // Mock API v1 returns a tokenResponse when we send a SignUp with OTP
                // TODO: Look for 403 error and return the following:

                //                let response = MSALNativeAuthResponse(
                //                    stage: .verificationRequired,
                //                    credentialToken: "flow-token-here",
                //                    authentication: nil
                //                )
                //
                //                complete(telemetryEvent, response: response, completion: completion)

                let msidConfiguration = factory.makeMSIDConfiguration(scope: parameters.scopes)

//                guard let tokenResult = handleResponse(tokenResponse, context: context, msidConfiguration: msidConfiguration) else {
//                    complete(telemetryEvent, error: MSALNativeAuthError.validationError, context: context, completion: completion)
//                    return
//                }
//
//                telemetryEvent?.setUserInformation(tokenResult.account)
//
//                cacheTokenResponse(tokenResponse, context: context, msidConfiguration: msidConfiguration)
//
//                let response = factory.makeNativeAuthResponse(
//                    stage: .completed,
//                    credentialToken: nil,
//                    tokenResult: tokenResult
//                )
//
//                complete(telemetryEvent, response: response, context: context, completion: completion)

            case .failure(let error):
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignUp OTP request error: \(error)"
                )

                complete(telemetryEvent, error: error, context: context, completion: completion)
            }
        }
    }

    // MARK: - Private

    private func createRequest(with parameters: MSALNativeAuthSignUpOTPParameters, context: MSALNativeAuthRequestContext) -> MSALNativeAuthSignUpRequest? {
        do {
            return try requestProvider.signUpOTPRequest(
                parameters: parameters,
                context: context
            )
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating SignUp OTP Request: \(error)")
            return nil
        }
    }
}
