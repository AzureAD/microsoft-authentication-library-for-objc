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
        context: MSALNativeAuthRequestContext,
        result: Result<MSALNativeAuthSignInChallengeResponse, Error>
    ) -> MSALNativeAuthSignInChallengeValidatedResponse

    func validate(
        context: MSALNativeAuthRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse
}

final class MSALNativeAuthSignInResponseValidator: MSALNativeAuthSignInResponseValidating {

    func validate(
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

    func validate(
        context: MSALNativeAuthRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse {
        switch result {
        case .success(let initiateResponse):
            if initiateResponse.challengeType == .redirect {
                return .error(.redirect)
            }
            if let credentialToken = initiateResponse.continuationToken {
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
            guard let credentialToken = response.continuationToken,
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
            guard let credentialToken = response.continuationToken else {
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
                return .error(.invalidRequest(message: error.errorDescription))
            case .unauthorizedClient:
                return .error(.invalidClient(message: error.errorDescription))
            case .invalidGrant:
                return .error(.invalidToken(message: error.errorDescription))
            case .expiredToken:
                return .error(.expiredToken(message: error.errorDescription))
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType(message: error.errorDescription))
            }
    }

    private func handleFailedSignInInitiateResult(
        _ context: MSALNativeAuthRequestContext,
        error: MSALNativeAuthSignInInitiateResponseError) -> MSALNativeAuthSignInInitiateValidatedResponse {
            switch error.error {
            case .invalidRequest:
                return .error(.invalidRequest(message: error.errorDescription))
            case .unauthorizedClient:
                return .error(.invalidClient(message: error.errorDescription))
            case .unsupportedChallengeType:
                return .error(.unsupportedChallengeType(message: error.errorDescription))
            case .invalidGrant:
                return .error(.userNotFound(message: error.errorDescription))
            }
    }
}
