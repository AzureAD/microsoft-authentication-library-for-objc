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

final class MSALNativeAuthResendCodeController: MSALNativeAuthResendCodeControlling {

    // MARK: - Variables

    private typealias ResendCodeCompletionHandler = (Result<MSALNativeAuthResendCodeRequestResponse, Error>) -> Void

    private let configuration: MSALNativeAuthPublicClientApplicationConfig
    private let requestProvider: MSALNativeAuthRequestProviding
    private let responseHandler: MSALNativeAuthResponseHandling
    private let authority: MSALNativeAuthAuthority
    private let context: MSIDRequestContext
    private let factory: MSALNativeAuthResultBuildable

    // MARK: - Init

    init(
        configuration: MSALNativeAuthPublicClientApplicationConfig,
        requestProvider: MSALNativeAuthRequestProviding,
        responseHandler: MSALNativeAuthResponseHandling,
        authority: MSALNativeAuthAuthority,
        context: MSIDRequestContext,
        factory: MSALNativeAuthResultBuildable
    ) {
        self.configuration = configuration
        self.requestProvider = requestProvider
        self.responseHandler = responseHandler
        self.authority = authority
        self.context = context
        self.factory = factory
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

    func resendCode(
        parameters: MSALNativeAuthResendCodeParameters,
        completion: @escaping (String?, Error?) -> Void
    ) {
        guard let request = createRequest(parameters: parameters) else {
            return completion(nil, MSALNativeAuthError.invalidRequest)
        }

        performRequest(request) { [self] result in
            switch result {
            case .success(let resendCodeResponse):
                guard verifyResponse(resendCodeResponse) else {
                    return completion(nil, MSALNativeAuthError.validationError)
                }
                completion(resendCodeResponse.credentialToken, nil)

            case .failure(let error):
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "ResendCode request error: \(error)"
                )
                completion(nil, error)
            }
        }
    }

    // MARK: - Private

    private func createRequest(parameters: MSALNativeAuthResendCodeParameters) -> MSALNativeAuthResendCodeRequest? {
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
                                completion: @escaping ResendCodeCompletionHandler) {
        request.send { [self] response, error in
            if let error = error {
                return completion(.failure(error))
            }
            guard let response = response as? MSALNativeAuthResendCodeRequestResponse else {
                MSALLogger.log(level: .error,
                               context: self.context,
                               format: "Reponse was not decoded properly by the serializer")
                return completion(.failure(MSALNativeAuthError.invalidResponse))
            }
            completion(.success(response))
        }
    }

    private func verifyResponse(_ resendCodeResponse: MSALNativeAuthResendCodeRequestResponse) -> Bool {
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
