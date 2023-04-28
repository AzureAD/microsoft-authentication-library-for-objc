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

protocol MSALNativeAuthVerifyCodeControlling: MSALNativeAuthTokenRequestHandling {
    func verifyCode(
        parameters: MSALNativeAuthVerifyCodeParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    )
}

final class MSALNativeAuthVerifyCodeController: MSALNativeAuthBaseController, MSALNativeAuthVerifyCodeControlling {

    // MARK: - Variables

    private let requestProvider: MSALNativeAuthRequestProviding
    private let factory: MSALNativeAuthResultBuildable

    // MARK: - Init

    init(
        clientId: String,
        requestProvider: MSALNativeAuthRequestProviding,
        cacheAccessor: MSALNativeAuthCacheInterface,
        responseHandler: MSALNativeAuthResponseHandling,
        context: MSIDRequestContext,
        factory: MSALNativeAuthResultBuildable
    ) {
        self.requestProvider = requestProvider
        self.factory = factory

        super.init(
            clientId: clientId,
            responseHandler: responseHandler,
            cacheAccessor: cacheAccessor
        )
    }

    convenience init(config: MSALNativeAuthConfiguration, context: MSIDRequestContext) {
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthRequestProvider(config: config),
            cacheAccessor: MSALNativeAuthCacheAccessor(),
            responseHandler: MSALNativeAuthResponseHandler(),
            context: context,
            factory: MSALNativeAuthResultFactory(config: config)
        )
    }

    // MARK: - Internal

    func verifyCode(
        parameters: MSALNativeAuthVerifyCodeParameters,
        completion: @escaping (MSALNativeAuthResponse?, Error?) -> Void
    ) {
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdVerifyCode,
            context: context
        )
        startTelemetryEvent(telemetryEvent, context: context)

        func completeWithTelemetry(_ response: MSALNativeAuthResponse?, _ error: Error?) {
            stopTelemetryEvent(telemetryEvent, context: context, error: error)
            completion(response, error)
        }

        guard let request = createRequest(with: parameters, context: context) else {
            return completeWithTelemetry(nil, MSALNativeAuthError.invalidRequest)
        }

        performRequest(request) { [self] result in
            switch result {
            case .success(let tokenResponse):
                // TODO: Scopes need to be the same ones as the ones in SignUp or SignIn
                let msidConfiguration = factory.makeMSIDConfiguration(scope: [""])

                guard let tokenResult =
                        handleResponse(tokenResponse, context: context, msidConfiguration: msidConfiguration) else {
                    return completeWithTelemetry(nil, MSALNativeAuthError.validationError)
                }

                telemetryEvent?.setUserInformation(tokenResult.account)

                cacheTokenResponse(tokenResponse, context: context, msidConfiguration: msidConfiguration)

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
                    format: "VerifyCode request error: \(error)"
                )
                completeWithTelemetry(nil, error)
            }
        }
    }

    // MARK: - Private

    private func createRequest(
        with parameters: MSALNativeAuthVerifyCodeParameters, context: MSALNativeAuthRequestContext
    ) -> MSALNativeAuthVerifyCodeRequest? {
        do {
            return try requestProvider.verifyCodeRequest(
                parameters: parameters,
                context: context
            )
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating VerifyCode Request: \(error)")
            return nil
        }
    }
}
