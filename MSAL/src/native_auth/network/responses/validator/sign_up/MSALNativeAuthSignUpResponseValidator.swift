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

protocol MSALNativeAuthSignUpResponseValidating {
    func validate(
        _ result: Result<MSALNativeAuthSignUpStartResponse, Error>, with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpStartValidatedResponse
    func validate(
        _ result: Result<MSALNativeAuthSignUpChallengeResponse, Error>,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpChallengeValidatedResponse
    func validate(
        _ result: Result<MSALNativeAuthSignUpContinueResponse, Error>, with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpContinueValidatedResponse
}

final class MSALNativeAuthSignUpResponseValidator: MSALNativeAuthSignUpResponseValidating {

    // MARK: - Start Request

    func validate(
        _ result: Result<MSALNativeAuthSignUpStartResponse, Error>, with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpStartValidatedResponse {
        switch result {
        case .success(let response):
            return handleStartSuccess(response, with: context)
        case .failure(let error):
            return handleStartFailed(error, with: context)
        }
    }

    private func handleStartSuccess(
        _ response: MSALNativeAuthSignUpStartResponse,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpStartValidatedResponse {
        if response.challengeType == .redirect {
            return .redirect
        } else if let continuationToken = response.continuationToken {
            return .success(continuationToken: continuationToken)
        } else {
            MSALLogger.log(level: .error, context: context, format: "signup/start returned success with unexpected response body")
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
    }

    private func handleStartFailed(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthSignUpStartValidatedResponse {
        guard let apiError = error as? MSALNativeAuthSignUpStartResponseError else {
            MSALLogger.log(level: .error, context: context, format: "signup/start: Unable to decode error response: \(error)")
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }

        switch apiError.error {
        case .invalidGrant where apiError.subError == .attributeValidationFailed:
            if let invalidAttributes = apiError.invalidAttributes, !invalidAttributes.isEmpty {
                return .attributeValidationFailed(error: apiError, invalidAttributes: extractAttributeNames(from: invalidAttributes))
            } else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "Missing expected fields in signup/start for attribute_validation_failed error"
                )
                return .unexpectedError(apiError)
            }
        case .invalidRequest where isSignUpStartInvalidRequestParameter(
            apiError,
            knownErrorDescription: MSALNativeAuthESTSApiErrorDescriptions.usernameParameterIsEmptyOrNotValid.rawValue):
            return .invalidUsername(apiError)
        case .invalidRequest where isSignUpStartInvalidRequestParameter(
            apiError,
            knownErrorDescription: MSALNativeAuthESTSApiErrorDescriptions.clientIdParameterIsEmptyOrNotValid.rawValue):
            return .unauthorizedClient(apiError)
        case .unknown:
            return .unexpectedError(apiError)
        default:
            return .error(apiError)
        }
    }

    // MARK: - Challenge Request

    func validate(
        _ result: Result<MSALNativeAuthSignUpChallengeResponse, Error>,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpChallengeValidatedResponse {
        switch result {
        case .success(let response):
            return handleChallengeSuccess(response, with: context)
        case .failure(let error):
            return handleChallengeError(error, with: context)
        }
    }

    private func handleChallengeSuccess(
        _ response: MSALNativeAuthSignUpChallengeResponse,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpChallengeValidatedResponse {
        guard let challengeTypeIssued = response.challengeType else {
            MSALLogger.log(level: .error, context: context, format: "Missing ChallengeType from backend in signup/challenge response")
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }

        switch challengeTypeIssued {
        case .redirect:
            return .redirect
        case .oob:
            if let sentTo = response.challengeTargetLabel,
               let channelType = response.challengeChannel?.toPublicChannelType(),
               let codeLength = response.codeLength,
               let continuationToken = response.continuationToken {
                return .codeRequired(sentTo, channelType, codeLength, continuationToken)
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/challenge with challenge_type = oob")
                return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
            }
        case .password:
            if let continuationToken = response.continuationToken {
                return .passwordRequired(continuationToken)
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/challenge with challenge_type = password")
                return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
            }
        case .otp:
            MSALLogger.log(level: .error, context: context, format: "ChallengeType OTP not expected for signup/challenge")
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
    }

    private func handleChallengeError(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthSignUpChallengeValidatedResponse {
        guard let apiError = error as? MSALNativeAuthSignUpChallengeResponseError else {
            MSALLogger.log(level: .error, context: context, format: "signup/challenge: Unable to decode error response: \(error)")
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }
        if apiError.error == .unknown {
            return .unexpectedError(apiError)
        }

        return .error(apiError)
    }

    // MARK: - Continue Request

    func validate(
        _ result: Result<MSALNativeAuthSignUpContinueResponse, Error>,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpContinueValidatedResponse {
        switch result {
        case .success(let response):
            // Even if the `continuationToken` is nil, the signUp flow is considered successfully completed
            return .success(continuationToken: response.continuationToken)
        case .failure(let error):
            return handleContinueError(error, with: context)
        }
    }

    private func handleContinueError(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthSignUpContinueValidatedResponse {
        guard let apiError = error as? MSALNativeAuthSignUpContinueResponseError else {
            MSALLogger.log(level: .error, context: context, format: "signup/continue: Unable to decode error response: \(error)")
            return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
        }

        switch apiError.error {
        case .invalidGrant:
            return handleInvalidGrantError(apiError, with: context)
        case .credentialRequired:
            if let continuationToken = apiError.continuationToken {
                return .credentialRequired(continuationToken: continuationToken, error: apiError)
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/continue for credential_required error")
                return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
            }
        case .attributesRequired:
            if let continuationToken = apiError.continuationToken,
                let requiredAttributes = apiError.requiredAttributes,
                !requiredAttributes.isEmpty {
                return .attributesRequired(
                    continuationToken: continuationToken,
                    requiredAttributes: requiredAttributes.map { $0.toRequiredAttributePublic() },
                    error: apiError
                )
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/continue for attributes_required error")
                return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
            }
        // TODO: .verificationRequired is not supported by the API team yet. We treat it as an unexpectedError
        case .verificationRequired:
            MSALLogger.log(level: .error, context: context, format: "verificationRequired is not supported yet")
            return .unexpectedError(nil)
        case .unauthorizedClient,
             .expiredToken,
             .userAlreadyExists,
             .invalidRequest:
            return .error(apiError)
        case .unknown:
            return .unexpectedError(apiError)
        }
    }

    private func handleInvalidGrantError(
        _ apiError: MSALNativeAuthSignUpContinueResponseError,
        with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpContinueValidatedResponse {
        guard let subError = apiError.subError else {
            return .error(apiError)
        }

        switch subError {
        case .invalidOOBValue,
             .passwordTooWeak,
             .passwordTooShort,
             .passwordTooLong,
             .passwordInvalid,
             .passwordRecentlyUsed,
             .passwordBanned:
            return .invalidUserInput(apiError)
        case .attributeValidationFailed:
            if let invalidAttributes = apiError.invalidAttributes, !invalidAttributes.isEmpty {
                return .attributeValidationFailed(error: apiError, invalidAttributes: extractAttributeNames(from: invalidAttributes))
            } else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "Missing expected fields in signup/continue for attribute_validation_failed error"
                )
                return .unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody))
            }
        case .unknown:
            return .unexpectedError(apiError)
        }
    }

    private func isSignUpStartInvalidRequestParameter(_ apiError: MSALNativeAuthSignUpStartResponseError, knownErrorDescription: String) -> Bool {
        guard let errorCode = apiError.errorCodes?.first,
              let knownErrorCode = MSALNativeAuthESTSApiErrorCodes(rawValue: errorCode),
              let errorDescription = apiError.errorDescription else {
            return false
        }
        return knownErrorCode == .invalidRequestParameter && errorDescription.contains(knownErrorDescription)
    }

    private func extractAttributeNames(from attributes: [MSALNativeAuthErrorBasicAttribute]) -> [String] {
        return attributes.map { $0.name }
    }
}
