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
    func validate(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInChallengeResponse, Error>
    ) -> MSALNativeAuthSignInChallengeValidatedResponse

    func validate(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse
}

final class MSALNativeAuthSignInResponseValidator: MSALNativeAuthSignInResponseValidating {

    func validate(
        context: MSIDRequestContext,
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
                    format: "signin/challenge: Unable to decode error response: \(signInChallengeResponseError)")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return handleFailedSignInChallengeResult(error: signInChallengeResponseError)
        }
    }

    func validate(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse {
        switch result {
        case .success(let initiateResponse):
            if initiateResponse.challengeType == .redirect {
                return .error(.redirect)
            }
            if let continuationToken = initiateResponse.continuationToken {
                return .success(continuationToken: continuationToken)
            }
            MSALLogger.log(level: .error, context: context, format: "signin/initiate: challengeType and continuation token empty")
            return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
        case .failure(let responseError):
            guard let initiateResponseError = responseError as? MSALNativeAuthSignInInitiateResponseError else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "signin/initiate: Unable to decode error response: \(responseError)")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return handleFailedSignInInitiateResult(error: initiateResponseError)
        }
    }

    // MARK: private methods

    private func handleSuccessfulSignInChallengeResult(
        _ context: MSIDRequestContext,
        response: MSALNativeAuthSignInChallengeResponse) -> MSALNativeAuthSignInChallengeValidatedResponse {
        switch response.challengeType {
        case .otp:
            MSALLogger.log(
                level: .error,
                context: context,
                format: "signin/challenge: Received unexpected challenge type: \(response.challengeType)")
            return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedChallengeType)))
        case .oob:
            guard let continuationToken = response.continuationToken,
                    let targetLabel = response.challengeTargetLabel,
                    let codeLength = response.codeLength,
                    let channelType = response.challengeChannel else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "signin/challenge: Invalid response with challenge type oob, response: \(response)")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .codeRequired(
                continuationToken: continuationToken,
                sentTo: targetLabel,
                channelType: channelType.toPublicChannelType(),
                codeLength: codeLength)
        case .password:
            guard let continuationToken = response.continuationToken else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "signin/challenge: Expected continuation token not nil with credential type password")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .passwordRequired(continuationToken: continuationToken)
        case .redirect:
            return .error(.redirect)
        }
    }

    private func handleFailedSignInChallengeResult(
        error: MSALNativeAuthSignInChallengeResponseError) -> MSALNativeAuthSignInChallengeValidatedResponse {
            switch error.error {
            case .invalidRequest:
                return .error(.invalidRequest(error))
            case .unauthorizedClient:
                return .error(.unauthorizedClient(error))
            case .invalidGrant:
                return .error(.invalidToken(error))
            case .expiredToken:
                return .error(.expiredToken(error))
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType(error))
            case .unknown:
                return .error(.unexpectedError(error))
            }
    }

    private func handleFailedSignInInitiateResult(error: MSALNativeAuthSignInInitiateResponseError) -> MSALNativeAuthSignInInitiateValidatedResponse {
            switch error.error {
            case .invalidRequest:
                return .error(.invalidRequest(error))
            case .unauthorizedClient:
                return .error(.unauthorizedClient(error))
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType(error))
            case .userNotFound:
                return .error(.userNotFound(error))
            case .unknown:
                return .error(.unexpectedError(error))
            }
    }
}
