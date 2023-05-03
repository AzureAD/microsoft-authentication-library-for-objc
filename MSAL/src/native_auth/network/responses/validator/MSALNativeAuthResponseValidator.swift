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

protocol MSALNativeAuthSignInResponseValidating {
    func validateSignInTokenResponse(
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration,
        result: Result<MSIDAADTokenResponse, Error>
    ) -> MSALNativeAuthSignInTokenValidatedResponse
}

protocol MSALNativeAuthTokenRequestValidating {
    func validateAndConvertTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration) -> MSIDTokenResult?
}

class MSALNativeAuthResponseValidator: MSALNativeAuthSignInResponseValidating, MSALNativeAuthTokenRequestValidating {

    let responseHandler: MSALNativeAuthResponseHandling

    init(responseHandler: MSALNativeAuthResponseHandling) {
        self.responseHandler = responseHandler
    }

    func validateAndConvertTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration
    ) -> MSIDTokenResult? {
        do {
            //TODO: where we can retrieve real homeAccountId and displayableId?
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

    func validateSignInTokenResponse(
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration,
        result: Result<MSIDAADTokenResponse, Error>
    ) -> MSALNativeAuthSignInTokenValidatedResponse {
        switch result {
        case .success(let tokenResponse):
            guard let tokenResult = validateAndConvertTokenResponse(
                tokenResponse,
                context: context,
                msidConfiguration: msidConfiguration
            ) else {
                return .error(.invalidServerResponse)
            }
            return .success(tokenResult)
        case .failure(let signInTokenResponseError):
            return handleFailedResult(signInTokenResponseError)
        }
        
        func handleFailedResult(_ responseError: Error) -> MSALNativeAuthSignInTokenValidatedResponse {
            guard let responseError =
                    responseError as? MSALNativeAuthSignInTokenResponseError else {
                MSALLogger.log(
                    level: .verbose,
                    context: context,
                    format: "Error type not expected"
                )
                return .error(.invalidServerResponse)
            }
            switch responseError.error {
            case .credentialRequired:
                guard let credentialToken = responseError.credentialToken else {
                    MSALLogger.log(
                        level: .verbose,
                        context: context,
                        format: "Expected credential token not empty"
                    )
                    return .error(.invalidServerResponse)
                }
                return .credentialRequired(credentialToken)
            case .invalidRequest:
                return .error(.invalidRequest)
            case .invalidClient:
                return .error(.invalidClient)
            case .invalidGrant:
                return .error(.invalidGrant)
            case .expiredToken:
                return .error(.expiredToken)
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType)
            case .invalidScope:
                return .error(.invalidScope)
            case .authorizationPending:
                return .error(.authorizationPending)
            case .slowDown:
                return .error(.slowDown)
            }
        }
    }
}
