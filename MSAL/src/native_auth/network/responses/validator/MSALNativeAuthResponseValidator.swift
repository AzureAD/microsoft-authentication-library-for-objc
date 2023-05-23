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

    func validateSignInChallengeResponse(
        context: MSALNativeAuthRequestContext,
        result: Result<MSALNativeAuthSignInChallengeResponse, Error>
    ) -> MSALNativeAuthSignInChallengeValidatedResponse

    func validateSignInInitiateResponse(
        context: MSALNativeAuthRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse
}

final class MSALNativeAuthResponseValidator: MSALNativeAuthSignInResponseValidating {

    private let responseHandler: MSALNativeAuthResponseHandling

    init(responseHandler: MSALNativeAuthResponseHandling) {
        self.responseHandler = responseHandler
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
            return .success(tokenResult, tokenResponse)
        case .failure(let signInTokenResponseError):
            guard let signInTokenResponseError =
                    signInTokenResponseError as? MSALNativeAuthSignInTokenResponseError else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignIn Token: Error type not expected, error: \(signInTokenResponseError)")
                return .error(.invalidServerResponse)
            }
            return handleFailedSignInTokenResult(context, signInTokenResponseError)
        }
    }

    func validateSignInChallengeResponse(
        context: MSALNativeAuthRequestContext,
        result: Result<MSALNativeAuthSignInChallengeResponse, Error>
    ) -> MSALNativeAuthSignInChallengeValidatedResponse {
        switch result {
        case .success(let challengeResponse):
            return handleSuccessfulSignInChallengeResult(context, response: challengeResponse)
        case .failure(let signInChallengeResponseError):
            guard let signInChallengeResponseError =
                    signInChallengeResponseError as? MSALNativeAuthSignInChallengeResponseError else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignIn Challenge: Error type not expected, error: \(signInChallengeResponseError)")
                return .error(.invalidServerResponse)
            }
            return handleFailedSignInChallengeResult(context, error: signInChallengeResponseError)
        }
    }

    func validateSignInInitiateResponse(
        context: MSALNativeAuthRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse {
        switch result {
        case .success(let initiateResponse):
            if initiateResponse.challengeType == .redirect {
                return .error(.redirect)
            }
            if let credentialToken = initiateResponse.credentialToken {
                return .success(credentialToken: credentialToken)
            }
            MSALLogger.log(level: .error, context: context, format: "SignIn Initiate: challengeType and credential token empty")
            return .error(.invalidServerResponse)
        case .failure(let responseError):
            guard let initiateResponseError = responseError as? MSALNativeAuthSignInInitiateResponseError else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignIn Initiate: Error type not expected, error: \(responseError)")
                return .error(.invalidServerResponse)
            }
            return handleFailedSignInInitiateResult(context, error: initiateResponseError)
        }
    }

    // MARK: private methods

    private func handleSuccessfulSignInChallengeResult(
        _ context: MSALNativeAuthRequestContext,
        response: MSALNativeAuthSignInChallengeResponse) -> MSALNativeAuthSignInChallengeValidatedResponse {
        switch response.challengeType {
        case .otp:
            MSALLogger.log(
                level: .error,
                context: context,
                format: "SignIn Challenge: Received unexpected challenge type: \(response.challengeType)")
            return .error(.invalidServerResponse)
        case .oob:
            guard let credentialToken = response.credentialToken,
                    let targetLabel = response.challengeTargetLabel,
                    let codeLength = response.codeLength,
                    let channelType = response.challengeChannel else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignIn Challenge: Invalid response with challenge type oob, response: \(response)")
                return .error(.invalidServerResponse)
            }
            return .codeRequired(
                credentialToken: credentialToken,
                sentTo: targetLabel,
                channelType: channelType.toPublicChannelType(),
                codeLength: codeLength)
        case .password:
            guard let credentialToken = response.credentialToken else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "SignIn Challenge: Expected credential token not nil with credential type password")
                return .error(.invalidServerResponse)
            }
            return .passwordRequired(credentialToken: credentialToken)
        case .redirect:
            return .error(.redirect)
        }
    }

    private func handleFailedSignInChallengeResult(
        _ context: MSALNativeAuthRequestContext,
        error: MSALNativeAuthSignInChallengeResponseError) -> MSALNativeAuthSignInChallengeValidatedResponse {
            switch error.error {
            case .invalidRequest:
                return .error(.invalidRequest)
            case .invalidClient:
                return .error(.invalidClient)
            case .invalidGrant:
                return .error(.invalidToken)
            case .expiredToken:
                return .error(.expiredToken)
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType)
            }
    }

    private func handleFailedSignInTokenResult(
        _ context: MSALNativeAuthRequestContext,
        _ responseError: MSALNativeAuthSignInTokenResponseError) -> MSALNativeAuthSignInTokenValidatedResponse {
        switch responseError.error {
        case .credentialRequired:
            guard let credentialToken = responseError.credentialToken else {
                MSALLogger.log(level: .error, context: context, format: "Expected credential token not empty")
                return .error(.invalidServerResponse)
            }
            return .credentialRequired(credentialToken)
        case .invalidRequest:
            return .error(.invalidRequest)
        case .invalidClient:
            return .error(.invalidClient)
        case .invalidGrant:
            return .error(convertErrorCodeToErrorType(responseError.errorCodes?.first))
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

    private func handleFailedSignInInitiateResult(
        _ context: MSALNativeAuthRequestContext,
        error: MSALNativeAuthSignInInitiateResponseError) -> MSALNativeAuthSignInInitiateValidatedResponse {
            switch error.error {
            case .invalidRequest:
                return .error(.invalidRequest)
            case .invalidClient:
                return .error(.invalidClient)
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType)
            case .invalidGrant:
                return .error(.userNotFound)
            }
    }

    private func validateAndConvertTokenResponse(
        _ tokenResponse: MSIDTokenResponse,
        context: MSALNativeAuthRequestContext,
        msidConfiguration: MSIDConfiguration
    ) -> MSIDTokenResult? {
        do {
            // TODO: where can we retrieve real homeAccountId and displayableId?
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

    private func convertErrorCodeToErrorType(
        _ errorCode: MSALNativeAPIErrorCodes?) -> MSALNativeAuthSignInTokenValidatedErrorType {
        switch errorCode {
        case .userNotFound:
            return .userNotFound
        case .invalidCredentials:
            return .invalidPassword
        case .invalidAuthenticationType:
            return .invalidAuthenticationType
        case .invalidOTP:
            return .invalidOOBCode
        default:
            return .generalError
        }
    }
}
