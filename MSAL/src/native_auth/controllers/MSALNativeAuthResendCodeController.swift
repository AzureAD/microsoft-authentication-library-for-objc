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

protocol MSALNativeAuthResendCodeControlling {
    func resendCode(
        parameters: MSALNativeAuthResendCodeParameters,
        completion: @escaping (String?, Error?) -> Void
    )
}

final class MSALNativeAuthResendCodeController: MSALNativeAuthBaseController, MSALNativeAuthResendCodeControlling {

    // MARK: - Variables

    private typealias ResendCodeCompletionHandler = (Result<MSALNativeAuthResendCodeRequestResponse, Error>) -> Void

    private let requestProvider: MSALNativeAuthRequestProviding
    private let responseHandler: MSALNativeAuthResponseHandling

    // MARK: - Init

    init(
        clientId: String,
        requestProvider: MSALNativeAuthRequestProviding,
        responseHandler: MSALNativeAuthResponseHandling
    ) {
        self.requestProvider = requestProvider
        self.responseHandler = responseHandler
        super.init(
            clientId: clientId
        )
    }

    convenience init(config: MSALNativeAuthConfiguration) {
        self.init(
            clientId: config.clientId,
            requestProvider: MSALNativeAuthRequestProvider(config: config),
            responseHandler: MSALNativeAuthResponseHandler()
        )
    }

    // MARK: - Internal

    func resendCode(
        parameters: MSALNativeAuthResendCodeParameters,
        completion: @escaping (String?, Error?) -> Void
    ) {
        let context = MSALNativeAuthRequestContext(correlationId: parameters.correlationId)
        let telemetryEvent = makeLocalTelemetryApiEvent(
            name: MSID_TELEMETRY_EVENT_API_EVENT,
            telemetryApiId: .telemetryApiIdResendCode, context: context
        )
        startTelemetryEvent(telemetryEvent, context: context)

        func completeWithTelemetry(_ response: String?, _ error: Error?) {
            stopTelemetryEvent(telemetryEvent, context: context, error: error)
            completion(response, error)
        }

        guard let request = createRequest(parameters: parameters, context: context) else {
            return completeWithTelemetry(nil, MSALNativeAuthError.invalidRequest)
        }

        performRequest(request, context: context) { [self] result in
            switch result {
            case .success(let resendCodeResponse):
                guard verifyResponse(resendCodeResponse, context: context) else {
                    return completeWithTelemetry(nil, MSALNativeAuthError.validationError)
                }
                completeWithTelemetry(resendCodeResponse.credentialToken, nil)

            case .failure(let error):
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "ResendCode request error: \(error)"
                )
                completeWithTelemetry(nil, error)
            }
        }
    }

    // MARK: - Private

    private func createRequest(
        parameters: MSALNativeAuthResendCodeParameters,
        context: MSALNativeAuthRequestContext) -> MSALNativeAuthResendCodeRequest? {
        do {
            return try requestProvider.resendCodeRequest(
                parameters: parameters,
                context: context
            )
        } catch {
            MSALLogger.log(level: .error, context: context, format: "Error creating ResendCode Request: \(error)")
            return nil
        }
    }

    private func performRequest(_ request: MSALNativeAuthResendCodeRequest,
                                context: MSALNativeAuthRequestContext,
                                completion: @escaping ResendCodeCompletionHandler) {
        request.send { response, error in
            if let error = error {
                return completion(.failure(error))
            }
            guard let response = response as? MSALNativeAuthResendCodeRequestResponse else {
                MSALLogger.log(level: .error,
                               context: context,
                               format: "Response was not decoded properly by the serializer")
                return completion(.failure(MSALNativeAuthError.invalidResponse))
            }
            completion(.success(response))
        }
    }

    private func verifyResponse(
        _ resendCodeResponse: MSALNativeAuthResendCodeRequestResponse,
        context: MSALNativeAuthRequestContext) -> Bool {
        do {
            return try responseHandler.handle(context: context, resendCodeReponse: resendCodeResponse)
        } catch {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Response validation error: \(error)"
            )
            return false
        }
    }
}
