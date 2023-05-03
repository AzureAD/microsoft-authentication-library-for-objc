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

enum MSALNativeAuthSignInTokenValidatedErrorType {
    case generalError
    case expiredToken
    case invalidClient
    case invalidRequest
    case invalidServerResponse
    case unsupportedChallengeType
    case invalidScope
    case authorizationPending
    case slowDown
}

enum MSALNativeAuthSignInTokenValidatedResponse {
    case success(MSIDTokenResult)
    case credentialRequired(String)
    case error(MSALNativeAuthSignInTokenValidatedErrorType)
}

protocol MSALNativeAuthSignInResponseValidating {
    // TODO: inject the response validator to validate the MSIDAADTokenResponse
    func validateSignInTokenResponse(result: Result<MSIDAADTokenResponse, Error>) -> MSALNativeAuthSignInTokenValidatedResponse
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

    func validateSignInTokenResponse(result: Result<MSIDAADTokenResponse, Error>) -> MSALNativeAuthSignInTokenValidatedResponse {
        switch result {
        case .success(let tokenResponse):
            print("something")
        case .failure(let signInTokenResponseError):
            guard let signInTokenResponseError = signInTokenResponseError as? MSALNativeAuthSignInTokenResponseError else {
                return .error(.invalidServerResponse)
            }
        }
        return .error(.invalidServerResponse)
    }
}
