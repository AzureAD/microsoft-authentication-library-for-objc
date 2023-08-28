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
        _ response: MSALNativeAuthSignUpStartResponse, with context: MSIDRequestContext
    ) -> MSALNativeAuthSignUpStartValidatedResponse {
        if response.challengeType == .redirect {
            return .redirect
        } else {
            MSALLogger.log(
                level: .error,
                context: context,
                format: "Unexpected response in signup/start. SDK expects only 200 with redirect challenge_type"
            )
            return .unexpectedError
        }
    }

    private func handleStartFailed(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthSignUpStartValidatedResponse {
        guard let apiError = error as? MSALNativeAuthSignUpStartResponseError else {
            MSALLogger.log(level: .error, context: context, format: "Error type not expected")
            return .unexpectedError
        }

        switch apiError.error {
        case .verificationRequired:
            if let signUpToken = apiError.signUpToken, let unverifiedAttributes = apiError.unverifiedAttributes, !unverifiedAttributes.isEmpty {
                return .verificationRequired(signUpToken: signUpToken, unverifiedAttributes: extractAttributeNames(from: unverifiedAttributes))
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/start for verification_required error")
                return .unexpectedError
            }
        case .attributeValidationFailed:
            if let invalidAttributes = apiError.invalidAttributes, !invalidAttributes.isEmpty {
                return .attributeValidationFailed(invalidAttributes: extractAttributeNames(from: invalidAttributes))
            } else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "Missing expected fields in signup/start for attribute_validation_failed error"
                )
                return .unexpectedError
            }
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
            return .unexpectedError
        }

        switch challengeTypeIssued {
        case .redirect:
            return .redirect
        case .oob:
            if let sentTo = response.challengeTargetLabel,
               let channelType = response.challengeChannel?.toPublicChannelType(),
               let codeLength = response.codeLength,
               let signUpChallengeToken = response.signUpToken {
                return .codeRequired(sentTo, channelType, codeLength, signUpChallengeToken)
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/challenge with challenge_type = oob")
                return .unexpectedError
            }
        case .password:
            if let signUpToken = response.signUpToken {
                return .passwordRequired(signUpToken)
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/challenge with challenge_type = password")
                return .unexpectedError
            }
        case .otp:
            MSALLogger.log(level: .error, context: context, format: "ChallengeType OTP not expected for signup/challenge")
            return .unexpectedError
        }
    }

    private func handleChallengeError(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthSignUpChallengeValidatedResponse {
        guard let apiError = error as? MSALNativeAuthSignUpChallengeResponseError else {
            MSALLogger.log(level: .error, context: context, format: "Error type not expected")
            return .unexpectedError
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
            // Even if the `signInSLT` is nil, the signUp flow is considered successfully completed
            return .success(response.signinSLT)
        case .failure(let error):
            return handleContinueError(error, with: context)
        }
    }

    private func handleContinueError(_ error: Error, with context: MSIDRequestContext) -> MSALNativeAuthSignUpContinueValidatedResponse {
        guard let apiError = error as? MSALNativeAuthSignUpContinueResponseError else {
            return .unexpectedError
        }

        switch apiError.error {
        case .invalidOOBValue,
             .passwordTooWeak,
             .passwordTooShort,
             .passwordTooLong,
             .passwordRecentlyUsed,
             .passwordBanned:
            return .invalidUserInput(apiError)
        case .attributeValidationFailed:
            if let signUpToken = apiError.signUpToken, let invalidAttributes = apiError.invalidAttributes, !invalidAttributes.isEmpty {
                return .attributeValidationFailed(signUpToken: signUpToken, invalidAttributes: extractAttributeNames(from: invalidAttributes))
            } else {
                MSALLogger.log(
                    level: .error,
                    context: context,
                    format: "Missing expected fields in signup/continue for attribute_validation_failed error"
                )
                return .unexpectedError
            }
        case .credentialRequired:
            if let signUpToken = apiError.signUpToken {
                return .credentialRequired(signUpToken: signUpToken)
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/continue for credential_required error")
                return .unexpectedError
            }
        case .attributesRequired:
            if let signUpToken = apiError.signUpToken, let requiredAttributes = apiError.requiredAttributes, !requiredAttributes.isEmpty {
                return .attributesRequired(signUpToken: signUpToken, requiredAttributes: requiredAttributes.map { $0.toRequiredAttributesPublic() })
            } else {
                MSALLogger.log(level: .error, context: context, format: "Missing expected fields in signup/continue for attributes_required error")
                return .unexpectedError
            }
        // TODO: .verificationRequired is not supported by the API team yet. We treat it as an unexpectedError
        case .verificationRequired:
            MSALLogger.log(level: .error, context: context, format: "verificationRequired is not supported yet")
            return .unexpectedError
        case .invalidClient,
             .invalidGrant,
             .expiredToken,
             .invalidRequest,
             .userAlreadyExists:

            return .error(apiError)
        }
    }

    private func extractAttributeNames(from attributes: [MSALNativeAuthErrorBasicAttributes]) -> [String] {
        return attributes.map { $0.name }
    }
}
