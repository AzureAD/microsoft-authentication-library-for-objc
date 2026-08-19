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

/// Maps a raw ``MSALNativeAuthHALResponse`` (or transport error) into a parsed, controller-facing response.
protocol MSALNativeAuthV2ResponseParsing {
    func parseAuthorizeChallenge(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        flowScenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthV2AuthorizeChallengeParsedResponse
    func parseInteraction(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2InteractionParsedResponse
}

final class MSALNativeAuthV2ResponseParser: MSALNativeAuthV2ResponseParsing {

    func parseAuthorizeChallenge(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        flowScenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthV2AuthorizeChallengeParsedResponse {
        switch result {
        case .failure(let error):
            return .error(flowError(from: error, context: context))
        case .success(let response):
            if let error = response.error {
                return .error(flowError(from: error, context: context))
            }
            if let code = (response as? MSALNativeAuthHALAuthorizationCodeResponse)?.code {
                MSALNativeAuthLogger.log(level: .verbose, context: context, format: "authorize-challenge: received authorization code")
                return .authorizationCode(code: code)
            }
            if let continuationToken = response.continuationToken {
                let relation = flowScenario.link
                guard let href = response.links[relation] else {
                    MSALNativeAuthLogger.log(level: .error, context: context, format: "authorize-challenge: missing '%@' link", relation)
                    return .error(MSALNativeAuthFlowError(
                        type: .generalError,
                        errorDescription: "Invalid authorize-challenge response: missing '\(relation)' link"
                    ))
                }
                MSALNativeAuthLogger.log(level: .verbose, context: context, format: "authorize-challenge: received continuation token")
                return .continuationToken(continuationToken: continuationToken, href: href)
            }
            MSALNativeAuthLogger.log(level: .error, context: context, format: "authorize-challenge: neither a continuation token nor a code")
            return .error(MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: "authorize-challenge returned neither a continuation token nor a code"
            ))
        }
    }

    func parseInteraction(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        switch result {
        case .failure(let error):
            return .error(flowError(from: error, context: context))
        case .success(let response):
            if response.isWebFallbackRequired {
                MSALNativeAuthLogger.log(level: .info, context: context, format: "interaction: web fallback required")
                // The URL is not returned here as the developer needs to invoke Auth UX
                return .browserRequired
            }
            if let error = response.error {
                return .error(flowError(from: error, context: context))
            }

            if response is MSALNativeAuthHALReadyToCompleteResponse {
                guard let continuationToken = response.continuationToken else {
                    MSALNativeAuthLogger.log(
                        level: .error,
                        context: context,
                        format: "interaction: missing continuation token in 'continue' response")
                    return .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token in 'continue' response"))
                }
                MSALNativeAuthLogger.log(level: .info, context: context, format: "interaction: flow ready to complete")
                return .readyToComplete(continuationToken: continuationToken)
            }

            guard let continuationToken = response.continuationToken else {
                MSALNativeAuthLogger.log(level: .error, context: context, format: "interaction: missing continuation token in interaction response")
                return .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Missing continuation token in interaction response"))
            }

            return parseInteractionResponse(response, continuationToken: continuationToken, context: context)
        }
    }

    private func parseInteractionResponse(
        _ response: MSALNativeAuthHALResponse,
        continuationToken: String,
        context: MSIDRequestContext
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        switch response {
        case let challengeResponse as MSALNativeAuthHALChallengeResponse:
            return parseChallengeResponse(challengeResponse, continuationToken: continuationToken, context: context)
        case let codeSentResponse as MSALNativeAuthHALCodeSentResponse:
            guard let verifyHref = codeSentResponse.href(for: .verify) else {
                return missingLink(.verify, context: context)
            }
            return .codeRequired(
                continuationToken: continuationToken,
                verifyHref: verifyHref,
                resendHref: codeSentResponse.href(for: .resend),
                sentTo: codeSentResponse.hint ?? "",
                channelType: MSALNativeAuthChannelType(value: codeSentResponse.methodType ?? "email"),
                codeLength: codeSentResponse.codeLength ?? 0
            )
        case let updateResponse as MSALNativeAuthHALUpdateResponse:
            guard let updateHref = updateResponse.href(for: .update) ?? updateResponse.href(for: .self) else {
                return missingLink(.update, context: context)
            }
            return .updateRequired(
                continuationToken: continuationToken,
                updateHref: updateHref
            )
        case let pollResponse as MSALNativeAuthHALPollResponse:
            guard let pollHref = pollResponse.href(for: .poll) else {
                return missingLink(.poll, context: context)
            }
            return .pollInProgress(
                continuationToken: continuationToken,
                pollHref: pollHref
            )
        default:
            MSALNativeAuthLogger.log(level: .error, context: context, format: "interaction: unexpected response type")
            return .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected interaction response"))
        }
    }

    /// A `multiFactor` challenge surfaces the available methods so the user can select one; any other
    /// challenge is a single-method challenge the SDK auto-triggers.
    private func parseChallengeResponse(
        _ challengeResponse: MSALNativeAuthHALChallengeResponse,
        continuationToken: String,
        context: MSIDRequestContext
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        if challengeResponse.authenticationFactor == "multiFactor" {
            let methods: [MSALNativeAuthV2ChallengeMethod] = challengeResponse.methods.compactMap { method in
                guard let id = method.id, let challengeHref = method.link(for: .challenge) else {
                    return nil
                }
                return MSALNativeAuthV2ChallengeMethod(
                    id: id,
                    channelType: method.type ?? "email",
                    hint: method.hint,
                    challengeHref: challengeHref
                )
            }
            guard !methods.isEmpty else {
                return missingLink(.challenge, context: context)
            }
            return .mfaRequired(continuationToken: continuationToken, methods: methods)
        }
        let method = challengeResponse.methods.first
        guard let challengeHref = method?.link(for: .challenge) ?? challengeResponse.href(for: .challenge) else {
            return missingLink(.challenge, context: context)
        }
        return .challengeRequired(
            continuationToken: continuationToken,
            challengeHref: challengeHref,
            hint: method?.hint ?? challengeResponse.hint
        )
    }
}

extension MSALNativeAuthV2ResponseParser {

    // MARK: - Error mapping

    /// The server returned an action that requires a follow-up link, but that link is absent.
    /// Fail here rather than passing a missing href down to the next request.
    private func missingLink(
        _ relation: MSALNativeAuthV2LinkRelation,
        context: MSIDRequestContext
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        MSALNativeAuthLogger.log(level: .error, context: context, format: "interaction: missing '%@' link", relation.rawValue)
        return .error(MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: "Invalid interaction response: missing '\(relation.rawValue)' link"
        ))
    }

    private func flowError(from serverError: MSALNativeAuthHALResponse.ServerError, context: MSIDRequestContext) -> MSALNativeAuthFlowError {
        let message = serverError.message
        let errorCodes = estsErrorCodes(from: message)
        let code = serverError.code
        let innerErrorCode = serverError.innerErrorCode
        let type: MSALNativeAuthFlowError.ErrorType

        if code == "invalidGrant" && innerErrorCode == "invalidOneTimeCode" {
            // Wrong one-time code (AADSTS50184); the app can prompt the user for a new code.
            type = .invalidCode
        } else if code == "invalidRequest" && innerErrorCode == "passwordTooWeak" {
            // New password fails complexity requirements (AADSTS120002).
            type = .invalidPassword
        } else if code == "invalidGrant" && innerErrorCode == "invalidUserNameOrPassword" {
            // Wrong username/password at sign in (AADSTS50126): a recoverable credentials error
            type = .invalidCredentials
        } else if code == "invalidRequest", let message = message, message.contains("AADSTS50034") {
            // Account does not exist in the directory. This response carries no inner code.
            type = .userNotFound
        } else {
            type = .generalError
        }

        logServerError(serverError, type: type, context: context)

        return MSALNativeAuthFlowError(
            type: type,
            errorDescription: message,
            errorCodes: errorCodes,
            correlationId: serverError.correlationId ?? UUID()
        )
    }

    private func logServerError(
        _ serverError: MSALNativeAuthHALResponse.ServerError,
        type: MSALNativeAuthFlowError.ErrorType,
        context: MSIDRequestContext
    ) {
        MSALNativeAuthLogger.log(
            level: .error,
            context: context,
            format: "server error mapped to '%@' (code: %@, innerErrorCode: %@)",
            String(describing: type),
            serverError.code ?? "nil",
            serverError.innerErrorCode ?? "nil")
        MSALNativeAuthLogger.logPII(
            level: .error,
            context: context,
            format: "server error message: %@",
            MSALLogMask.maskPII(serverError.message))
    }

    private func estsErrorCodes(from message: String?) -> [Int] {
        guard let message = message else {
            return []
        }
        var codes: [Int] = []
        let scanner = Scanner(string: message)
        let marker = "AADSTS"
        while !scanner.isAtEnd {
            guard scanner.scanUpToString(marker) != nil || scanner.string.hasPrefix(marker) else {
                break
            }
            guard scanner.scanString(marker) != nil else {
                break
            }
            if let code = scanner.scanInt() {
                codes.append(code)
            }
        }
        return codes
    }

    private func flowError(from error: Error, context: MSIDRequestContext) -> MSALNativeAuthFlowError {
        if let flowError = error as? MSALNativeAuthFlowError {
            return flowError
        }
        MSALNativeAuthLogger.logPII(
            level: .error,
            context: context,
            format: "transport failure: %@",
            MSALLogMask.maskPII((error as NSError).localizedDescription))
        return MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: (error as NSError).localizedDescription
        )
    }
}
