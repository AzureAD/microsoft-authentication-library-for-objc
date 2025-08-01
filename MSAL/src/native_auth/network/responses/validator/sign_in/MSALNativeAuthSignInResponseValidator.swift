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
    func validateInitiate(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse

    func validateChallenge(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInChallengeResponse, Error>
    ) -> MSALNativeAuthSignInChallengeValidatedResponse

    func validateIntrospect(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInIntrospectResponse, Error>
    ) -> MSALNativeAuthSignInIntrospectValidatedResponse
}

final class MSALNativeAuthSignInResponseValidator: MSALNativeAuthSignInResponseValidating {

    func validateInitiate(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInInitiateResponse, Error>
    ) -> MSALNativeAuthSignInInitiateValidatedResponse {
        switch result {
        case .success(let initiateResponse):
            if initiateResponse.challengeType == .redirect {
                return .error(.redirect(reason: initiateResponse.redirectReason))
            }
            if let continuationToken = initiateResponse.continuationToken {
                return .success(continuationToken: continuationToken)
            }
            MSALNativeAuthLogger.log(level: .error, context: context, format: "signin/initiate: challengeType and continuation token empty")
            return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
        case .failure(let responseError):
            guard let initiateResponseError = responseError as? MSALNativeAuthSignInInitiateResponseError else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "signin/initiate: Unable to decode error response: \(MSALLogMask.maskPII(responseError))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return handleFailedSignInInitiateResult(error: initiateResponseError)
        }
    }

    func validateChallenge(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthSignInChallengeResponse, Error>
    ) -> MSALNativeAuthSignInChallengeValidatedResponse {
        switch result {
        case .success(let challengeResponse):
            return handleSuccessfulSignInChallengeResult(context, response: challengeResponse)
        case .failure(let signInChallengeResponseError):
            guard let signInChallengeResponseError =
                    signInChallengeResponseError as? MSALNativeAuthSignInChallengeResponseError else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "signin/challenge: Unable to decode error response: \(MSALLogMask.maskPII(signInChallengeResponseError))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return handleFailedSignInChallengeResult(error: signInChallengeResponseError)
        }
    }

    func validateIntrospect(
        context: any MSIDRequestContext,
        result: Result<MSALNativeAuthSignInIntrospectResponse, any Error>
    ) -> MSALNativeAuthSignInIntrospectValidatedResponse {
        switch result {
        case .success(let introspectResponse):
            guard introspectResponse.challengeType != .redirect else {
                return .error(.redirect(reason: introspectResponse.redirectReason))
            }
            guard let continuationToken = introspectResponse.continuationToken,
                  let methods = introspectResponse.methods,
                  !methods.isEmpty else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "signin/introspect: Invalid response, content: \(MSALLogMask.maskPII(introspectResponse))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .authMethodsRetrieved(continuationToken: continuationToken, authMethods: methods)
        case .failure(let introspectResponseError):
            guard let introspectResponseError =
                    introspectResponseError as? MSALNativeAuthSignInIntrospectResponseError else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "signin/introspect: Unable to decode error response: \(MSALLogMask.maskPII(introspectResponseError))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            switch introspectResponseError.error {
            case .invalidRequest:
                return .error(.invalidRequest(introspectResponseError))
            case .expiredToken:
                return .error(.expiredToken(introspectResponseError))
            case .unknown:
                return .error(.unexpectedError(introspectResponseError))
            }
        }
    }

    // MARK: private methods

    private func handleSuccessfulSignInChallengeResult(
        _ context: MSIDRequestContext,
        response: MSALNativeAuthSignInChallengeResponse) -> MSALNativeAuthSignInChallengeValidatedResponse {
        switch response.challengeType {
        case .none:
            MSALNativeAuthLogger.log(
                level: .error,
                context: context,
                format: "signin/challenge: Received unexpected challenge type: \(response.challengeType?.rawValue ?? "")")
            return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedChallengeType)))
        case .oob:
            guard let continuationToken = response.continuationToken,
                    let targetLabel = response.challengeTargetLabel,
                    let codeLength = response.codeLength,
                    let channelType = response.challengeChannel else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "signin/challenge: Invalid response with challenge type oob, response: \(MSALLogMask.maskPII(response))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .codeRequired(
                continuationToken: continuationToken,
                sentTo: targetLabel,
                channelType: MSALNativeAuthChannelType(value: channelType),
                codeLength: codeLength)
        case .password:
            guard let continuationToken = response.continuationToken else {
                MSALNativeAuthLogger.log(
                    level: .error,
                    context: context,
                    format: "signin/challenge: Expected continuation token not nil with credential type password")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .passwordRequired(continuationToken: continuationToken)
        case .redirect:
            return .error(.redirect(reason: response.redirectReason))
        }
    }

    private func handleFailedSignInChallengeResult(
        error: MSALNativeAuthSignInChallengeResponseError) -> MSALNativeAuthSignInChallengeValidatedResponse {
            switch error.error {
            case .invalidRequest:
                if error.subError == .introspectRequired {
                    return .introspectRequired
                } else {
                    return .error(.invalidRequest(error))
                }
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
