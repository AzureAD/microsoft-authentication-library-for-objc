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

protocol MSALNativeAuthJITResponseValidating {
    func validateIntrospect(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthJITIntrospectResponse, Error>
    ) -> MSALNativeAuthJITIntrospectValidatedResponse

    func validateChallenge(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthJITChallengeResponse, Error>
    ) -> MSALNativeAuthJITChallengeValidatedResponse

    func validateContinue(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthJITContinueResponse, Error>
    ) -> MSALNativeAuthJITContinueValidatedResponse

}

final class MSALNativeAuthJITResponseValidator: MSALNativeAuthJITResponseValidating {

    func validateIntrospect(
        context: any MSIDRequestContext,
        result: Result<MSALNativeAuthJITIntrospectResponse, any Error>
    ) -> MSALNativeAuthJITIntrospectValidatedResponse {
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
                    format: "register/introspect: Invalid response, content: \(MSALLogMask.maskPII(introspectResponse))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .authMethodsRetrieved(continuationToken: continuationToken, authMethods: methods)
        case .failure(let introspectResponseError):
            guard let introspectResponseError =
                    introspectResponseError as? MSALNativeAuthJITIntrospectResponseError else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "register/introspect: Unable to decode error response: \(MSALLogMask.maskPII(introspectResponseError))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            switch introspectResponseError.error {
            case .unknown:
                return .error(.unexpectedError(introspectResponseError))
            }
        }
    }

    func validateChallenge(
        context: any MSIDRequestContext,
        result: Result<MSALNativeAuthJITChallengeResponse, Error>
    ) -> MSALNativeAuthJITChallengeValidatedResponse {
        switch result {
        case .success(let challengeResponse):
            return handleSuccessfulJITChallengeResult(context, response: challengeResponse)
        case .failure(let JITChallengeResponseError):
            guard let JITChallengeResponseError =
                    JITChallengeResponseError as? MSALNativeAuthJITChallengeResponseError else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "register/challenge: Unable to decode error response: \(MSALLogMask.maskPII(JITChallengeResponseError))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return handleFailedJITChallengeResult(error: JITChallengeResponseError)
        }
    }

    func validateContinue(
        context: MSIDRequestContext,
        result: Result<MSALNativeAuthJITContinueResponse, Error>
    ) -> MSALNativeAuthJITContinueValidatedResponse {
        switch result {
        case .success(let initiateResponse):
            guard initiateResponse.challengeType != .redirect else {
                return .error(.redirect(reason: initiateResponse.redirectReason))
            }
            if let continuationToken = initiateResponse.continuationToken {
                return .success(continuationToken: continuationToken)
            }
            MSALNativeAuthLogger.log(level: .error, context: context, format: "register/continue: challengeType and continuation token empty")
            return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
        case .failure(let responseError):
            guard let initiateResponseError = responseError as? MSALNativeAuthJITContinueResponseError else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "register/continue: Unable to decode error response: \(MSALLogMask.maskPII(responseError))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return handleFailedJITContinueResult(error: initiateResponseError)
        }
    }

    // MARK: private methods

    private func handleSuccessfulJITChallengeResult(
        _ context: MSIDRequestContext,
        response: MSALNativeAuthJITChallengeResponse) -> MSALNativeAuthJITChallengeValidatedResponse {
        switch response.challengeType {
        case "oob":
            guard let continuationToken = response.continuationToken,
                    let targetLabel = response.challengeTarget,
                    let codeLength = response.codeLength,
                    let channelType = response.challengeChannel else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "register/challenge: Invalid response with challenge type oob, response: \(MSALLogMask.maskPII(response))")
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .codeRequired(
                continuationToken: continuationToken,
                sentTo: targetLabel,
                channelType: MSALNativeAuthChannelType(value: channelType),
                codeLength: codeLength)
        case "preverified":
            guard let continuationToken = response.continuationToken else {
                MSALNativeAuthLogger.logPII(
                    level: .error,
                    context: context,
                    format: "register/challenge: Invalid response with challenge type preverified, continuation token was expected, response: \(MSALLogMask.maskPII(response))") // swiftlint:disable:this line_length
                return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody)))
            }
            return .preverified(continuationToken: continuationToken)
        case "redirect":
            return .error(.redirect(reason: response.redirectReason))
        default:
            MSALNativeAuthLogger.log(
                level: .error,
                context: context,
                format: "register/challenge: Received unexpected challenge type: \(response.challengeType)")
            return .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedChallengeType)))
        }
    }

    private func handleFailedJITChallengeResult(
        error: MSALNativeAuthJITChallengeResponseError) -> MSALNativeAuthJITChallengeValidatedResponse {
            switch error.error {
            case .invalidRequest:
                if error.errorCodes?.contains(MSALNativeAuthESTSApiErrorCodes.authMethodBlocked.rawValue) == true {
                    let customErrorDescription = MSALNativeAuthErrorMessage.verificationContactBlocked + (error.errorDescription ?? "")
                    return .error(.verificationContactBlocked(
                        MSALNativeAuthJITChallengeResponseError(
                            error: error.error,
                            errorDescription: customErrorDescription,
                            errorCodes: error.errorCodes,
                            errorURI: error.errorURI,
                            innerErrors: error.innerErrors,
                            correlationId: error.correlationId
                        )))
                } else if error.errorCodes?.contains(MSALNativeAuthESTSApiErrorCodes.invalidVerificationContact.rawValue) == true {
                    return .error(.invalidVerificationContact(error))
                } else {
                    return .error(.unexpectedError(error))
                }
            case .unknown:
                return .error(.unexpectedError(error))
            }
    }

    private func handleFailedJITContinueResult(error: MSALNativeAuthJITContinueResponseError) -> MSALNativeAuthJITContinueValidatedResponse {
        switch error.error {
        case .invalidGrant where error.subError == .invalidOOBValue:
            return .error(.invalidOOBCode(error))
        case .unknown:
            return .error(.unexpectedError(error))
        default:
            return .error(.unexpectedError(error))
        }
    }
}
