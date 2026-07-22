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

/// Maps a raw ``MSALNativeAuthHALResponse`` (or transport error) into a validated, controller-facing response.
protocol MSALNativeAuthV2ResponseValidating {
    func validateAuthorizeChallenge(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        flowScenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse
    func validateInteraction(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2InteractionValidatedResponse
}

final class MSALNativeAuthV2ResponseValidator: MSALNativeAuthV2ResponseValidating {

    func validateAuthorizeChallenge(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        flowScenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(flowError(from: error, context: context))
        case .success(let response):
            if let error = response.error {
                return .error(flowError(from: error, context: context))
            }
            if let code = response.code {
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func validateInteraction(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2InteractionValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(flowError(from: error, context: context))
        case .success(let response):
            if let error = response.error {
                return .error(flowError(from: error, context: context))
            }

            if response.isReadyToComplete {
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

            MSALNativeAuthLogger.log(level: .verbose, context: context, format: "interaction: processing action '%@'", response.action ?? "nil")

            switch response.halAction {
            case .challenge:
                let method = response.methods.first
                guard let challengeHref = method?.link(for: .challenge) ?? response.href(for: .challenge) else {
                    return missingLink(.challenge, context: context)
                }
                // MFA required: the server sets challengeContext.authenticationFactor to "multiFactor"
                // and embeds the available second-factor methods. Surface them for method selection
                // rather than auto-triggering a single challenge.
                if response.authenticationFactor == "multiFactor", !response.methods.isEmpty {
                    return .mfaRequired(
                        continuationToken: continuationToken,
                        methods: response.methods,
                        challengeHref: challengeHref
                    )
                }
                return .challengeRequired(
                    continuationToken: continuationToken,
                    challengeHref: challengeHref,
                    hint: method?.hint ?? response.hint
                )
            case .verify:
                // After a password, a `challenge` link plus embedded methods means MFA is required.
                if let challengeHref = response.href(for: .challenge), !response.methods.isEmpty {
                    return .mfaRequired(
                        continuationToken: continuationToken,
                        methods: response.methods,
                        challengeHref: challengeHref
                    )
                }
                guard let verifyHref = response.href(for: .verify) else {
                    return missingLink(.verify, context: context)
                }
                // An email/OOB method carries a hint and/or a code length; a password method does not.
                if (response.codeLength ?? 0) > 0 || response.hint != nil || response.methodType == "email" {
                    return .codeRequired(
                        continuationToken: continuationToken,
                        verifyHref: verifyHref,
                        resendHref: response.href(for: .resend),
                        sentTo: response.hint ?? "",
                        codeLength: response.codeLength ?? 0
                    )
                }
                return .passwordRequired(continuationToken: continuationToken, verifyHref: verifyHref)
            case .enroll, .register:
                guard let enrollHref = response.href(for: .enroll) ?? response.href(for: .register) else {
                    return missingLink(.enroll, context: context)
                }
                return .registrationRequired(
                    continuationToken: continuationToken,
                    enrollHref: enrollHref,
                    methods: response.methods
                )
            case .activate:
                guard let activateHref = response.href(for: .activate) else {
                    return missingLink(.activate, context: context)
                }
                return .activationRequired(
                    continuationToken: continuationToken,
                    activateHref: activateHref,
                    sentTo: response.hint ?? "",
                    codeLength: response.codeLength ?? 0
                )
            case .collectAttributes:
                guard let submitHref = response.href(for: .submitAttributes) else {
                    return missingLink(.submitAttributes, context: context)
                }
                return .attributesRequired(
                    continuationToken: continuationToken,
                    attributes: response.attributes,
                    submitHref: submitHref
                )
            case .update:
                guard let updateHref = response.href(for: .update) ?? response.href(for: .self) else {
                    return missingLink(.update, context: context)
                }
                return .updateRequired(
                    continuationToken: continuationToken,
                    updateHref: updateHref
                )
            case .poll:
                guard let pollHref = response.href(for: .poll) else {
                    return missingLink(.poll, context: context)
                }
                return .pollInProgress(
                    continuationToken: continuationToken,
                    pollHref: pollHref
                )
            default:
                // No recognized action. A nil action with embedded methods is sign-in method discovery.
                if response.action == nil, !response.methods.isEmpty {
                    MSALNativeAuthLogger.log(
                        level: .verbose,
                        context: context,
                        format: "interaction: returning %d sign-in methods",
                        response.methods.count)
                    return .signInMethods(continuationToken: continuationToken, methods: response.methods)
                }
                MSALNativeAuthLogger.log(level: .error, context: context, format: "interaction: unexpected action '%@'", response.action ?? "nil")
                return .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: "Unexpected action '\(response.action ?? "nil")'"))
            }
        }
    }
}

extension MSALNativeAuthV2ResponseValidator {

    // MARK: - Error mapping

    /// The server returned an action that requires a follow-up link, but that link is absent.
    /// Fail here rather than passing a missing href down to the next request.
    private func missingLink(
        _ relation: MSALNativeAuthV2LinkRelation,
        context: MSIDRequestContext
    ) -> MSALNativeAuthV2InteractionValidatedResponse {
        MSALNativeAuthLogger.log(level: .error, context: context, format: "interaction: missing '%@' link", relation.rawValue)
        return .error(MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: "Invalid interaction response: missing '\(relation.rawValue)' link"
        ))
    }

    private func flowError(from serverError: MSALNativeAuthHALResponse.ServerError, context: MSIDRequestContext) -> MSALNativeAuthFlowError {
        let message = serverError.message
        let errorCodes = estsErrorCodes(from: message)
        let innerErrorCode = serverError.innerErrorCode
        let type: MSALNativeAuthFlowError.ErrorType

        if innerErrorCode == "invalidContinuationToken" {
            // An invalid OTP and an invalid continuation token share the inner code; the outer
            // code disambiguates (invalidGrant => the supplied OTP was wrong). A rejected
            // continuation token is SDK-managed internal state the app cannot act on, so it
            // surfaces as a general error.
            type = serverError.code == "invalidGrant" ? .invalidCode : .generalError
        } else if let message = message, message.contains("AADSTS50034") {
            type = .userNotFound
        } else if innerErrorCode == "passwordTooWeak" {
            type = .invalidPassword
        } else if innerErrorCode == "invalidUserNameOrPassword"
                    || errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.invalidCredentials.rawValue) {
            // Wrong username/password at sign in (AADSTS50126): a recoverable credentials error,
            // not an invalid one-time code.
            type = .invalidCredentials
        } else if serverError.code == "invalidGrant" {
            type = .invalidCode
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
