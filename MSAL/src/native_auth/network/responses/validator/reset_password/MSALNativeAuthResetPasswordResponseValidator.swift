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

protocol MSALNativeAuthResetPasswordResponseValidating {
    func validate(_ result: Result<MSALNativeAuthResetPasswordStartResponse, Error>,
                  with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordStartValidatedResponse
    func validate(_ result: Result<MSALNativeAuthResetPasswordChallengeResponse, Error>,
                  with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordChallengeValidatedResponse
    func validate(_ result: Result<MSALNativeAuthResetPasswordContinueResponse, Error>,
                  with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordContinueValidatedResponse
    func validate(_ result: Result<MSALNativeAuthResetPasswordSubmitResponse, Error>,
                  with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordSubmitValidatedResponse
    func validate(_ result: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error>,
                  with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse
}

final class MSALNativeAuthResetPasswordResponseValidator: MSALNativeAuthResetPasswordResponseValidating {

    // MARK: - Start Request

    func validate(_ result: Result<MSALNativeAuthResetPasswordStartResponse, Error>,
                  with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordStartValidatedResponse {
        switch result {
        case .success(let response):
            return handleStartSuccess(response, with: context)
        case .failure(let error):
            return handleStartFailed(error, with: context)
        }
    }

    private func handleStartSuccess(_ response: MSALNativeAuthResetPasswordStartResponse,
                                    with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordStartValidatedResponse {
        if response.challengeType == .redirect {
            return .redirect(reason: response.redirectReason)
        } else if let continuationToken = response.continuationToken {
            return .success(continuationToken: continuationToken)
        } else {
            MSALNativeAuthLogger.log(level: .error,
                           context: context,
                           format: "resetpassword/start returned success with unexpected response body")

            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
    }

    private func handleStartFailed(_ error: Error,
                                   with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordStartValidatedResponse {
        guard let apiError = error as? MSALNativeAuthResetPasswordStartResponseError else {
            MSALNativeAuthLogger.logPII(level: .error,
                           context: context,
                           format: "resetpassword/start: Unable to decode error response: \(MSALLogMask.maskPII(error))")

            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }

        switch apiError.error {
        case .invalidRequest:
            if apiError.errorCodes?.first == MSALNativeAuthESTSApiErrorCodes.userNotHaveAPassword.rawValue {
                return .error(.userDoesNotHavePassword(apiError))
            } else {
                return .error(.invalidRequest(apiError))
            }
        case .unauthorizedClient:
            return .error(.unauthorizedClient(apiError))
        case .userNotFound:
            return .error(.userNotFound(apiError))
        case .unsupportedChallengeType:
            return .error(.unsupportedChallengeType(apiError))
        case .unknown:
            return .error(.unexpectedError(apiError))
        }
    }

    // MARK: - Challenge Request

    func validate(
        _ result: Result<MSALNativeAuthResetPasswordChallengeResponse, Error>,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthResetPasswordChallengeValidatedResponse {
        switch result {
        case .success(let response):
            return handleChallengeSuccess(response, with: context)
        case .failure(let error):
            return handleChallengeError(error, with: context)
        }
    }

    private func handleChallengeSuccess(
        _ response: MSALNativeAuthResetPasswordChallengeResponse,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthResetPasswordChallengeValidatedResponse {
        switch response.challengeType {
        case .redirect:
            return .redirect(reason: response.redirectReason)
        case .oob:
            if let sentTo = response.challengeTargetLabel,
               let challengeChannel = response.challengeChannel,
               let codeLength = response.codeLength,
               let continuationToken = response.continuationToken {
                let channelTargetType = MSALNativeAuthChannelType(value: challengeChannel)
                return .success(
                    sentTo,
                    channelTargetType,
                    codeLength,
                    continuationToken
                )
            } else {
                MSALNativeAuthLogger.log(level: .error, context: context, format: "Missing expected fields from backend")
                return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
            }
        case .none,
            .password:
            let errorDescription = MSALNativeAuthErrorMessage.unexpectedChallengeType
            MSALNativeAuthLogger.log(level: .error, context: context, format: errorDescription)
            return .unexpectedError(.init(errorDescription: errorDescription))
        }
    }

    private func handleChallengeError(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordChallengeValidatedResponse {
        guard let apiError = error as? MSALNativeAuthResetPasswordChallengeResponseError else {
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: context,
                format: "resetpassword/challenge: Unable to decode error response: \(MSALLogMask.maskPII(error))"
            )
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
        if apiError.error == .unknown {
            return .unexpectedError(apiError)
        }
        return .error(apiError)
    }

    // MARK: - Continue Request

    func validate(
        _ result: Result<MSALNativeAuthResetPasswordContinueResponse, Error>,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthResetPasswordContinueValidatedResponse {
        switch result {
        case .success(let response):
            return handleContinueSuccess(response)
        case .failure(let error):
            return handleContinueError(error, with: context)
        }
    }

    private func handleContinueSuccess(
        _ response: MSALNativeAuthResetPasswordContinueResponse
    ) -> MSALNativeAuthResetPasswordContinueValidatedResponse {
        guard response.challengeType != .redirect else {
            return .redirect(reason: response.redirectReason)
        }
        guard let continuationToken = response.continuationToken else {
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
        return .success(continuationToken: continuationToken)
    }

    private func handleContinueError(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordContinueValidatedResponse {
        guard let apiError = error as? MSALNativeAuthResetPasswordContinueResponseError else {
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: context,
                format: "resetpassword/continue: Unable to decode error response: \(MSALLogMask.maskPII(error))"
            )
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }

        switch apiError.error {
        case .invalidGrant:
            return apiError.subError == .invalidOOBValue ? .invalidOOB(apiError) : .error(apiError)
        case .unauthorizedClient,
             .expiredToken,
             .invalidRequest:
            return .error(apiError)
        case .verificationRequired:
            MSALNativeAuthLogger.log(level: .error, context: context, format: "verificationRequired is not supported yet")
            return .unexpectedError(nil)
        case .unknown:
            return .unexpectedError(apiError)
        }
    }

    // MARK: - Submit Request

    func validate(
        _ result: Result<MSALNativeAuthResetPasswordSubmitResponse, Error>,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthResetPasswordSubmitValidatedResponse {
        switch result {
        case .success(let response):
            return handleSubmitSuccess(response)
        case .failure(let error):
            return handleSubmitError(error, with: context)
        }
    }

    private func handleSubmitSuccess(
        _ response: MSALNativeAuthResetPasswordSubmitResponse
    ) -> MSALNativeAuthResetPasswordSubmitValidatedResponse {
        guard response.challengeType != .redirect else {
            return .redirect(reason: response.redirectReason)
        }
        guard let continuationToken = response.continuationToken, let pollInterval = response.pollInterval else {
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
        return .success(continuationToken: continuationToken, pollInterval: pollInterval)
    }

    private func handleSubmitError(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthResetPasswordSubmitValidatedResponse {
        guard let apiError = error as? MSALNativeAuthResetPasswordSubmitResponseError else {
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: context,
                format: "resetpassword/submit: Unable to decode error response: \(MSALLogMask.maskPII(error))"
            )
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }

        switch apiError.error {
        case .invalidGrant:
            if let subError = apiError.subError, subError.isAnyPasswordError {
                return .passwordError(error: apiError)
            } else {
                return .error(apiError)
            }
        case .invalidRequest,
             .unauthorizedClient,
             .expiredToken:
            return .error(apiError)
        case .unknown:
            return .unexpectedError(apiError)
        }
    }

    // MARK: - Poll Completion Request

    func validate(
        _ result: Result<MSALNativeAuthResetPasswordPollCompletionResponse, Error>,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        switch result {
        case .success(let response):
            return handlePollCompletionSuccess(response)
        case .failure(let error):
            return handlePollCompletionError(error, with: context)
        }
    }

    private func handlePollCompletionSuccess(
        _ response: MSALNativeAuthResetPasswordPollCompletionResponse
    ) -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        guard response.challengeType != .redirect else {
            return .redirect(reason: response.redirectReason)
        }
        guard let status = response.status else {
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
        // Even if the `continuationToken` is nil, the ResetPassword flow is considered successfully completed
        return .success(status: status, continuationToken: response.continuationToken)
    }

    private func handlePollCompletionError(
        _ error: Error,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthResetPasswordPollCompletionValidatedResponse {
        guard let apiError = error as? MSALNativeAuthResetPasswordPollCompletionResponseError else {
            MSALNativeAuthLogger.logPII(
                level: .error,
                context: context,
                format: "resetpassword/poll_completion: Unable to decode error response: \(MSALLogMask.maskPII(error))"
            )
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }

        switch apiError.error {
        case .invalidGrant:
            if let subError = apiError.subError, subError.isAnyPasswordError {
                return .passwordError(error: apiError)
            } else {
                return .error(apiError)
            }
        case .userNotFound,
             .invalidRequest,
             .unauthorizedClient,
             .expiredToken:
            return .error(apiError)
        case .unknown:
            return .unexpectedError(apiError)
        }
    }
}
