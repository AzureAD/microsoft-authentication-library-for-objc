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

import Foundation

/// Maps a raw ``MSALNativeAuthHALResponse`` (or transport error) into a validated, controller-facing response.
protocol MSALNativeAuthV2ResponseValidating {
    func validateAuthorizeChallenge(
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        flowType: MSALNativeAuthV2FlowType
    ) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse
    func validateInteraction(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2InteractionValidatedResponse
    func validateToken(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2TokenValidatedResponse
}

final class MSALNativeAuthV2ResponseValidator: MSALNativeAuthV2ResponseValidating {

    func validateAuthorizeChallenge(
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        flowType: MSALNativeAuthV2FlowType
    ) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(flowError(from: error))
        case .success(let response):
            if let error = response.error {
                return .error(flowError(from: error))
            }
            if let code = response.code {
                return .authorizationCode(code: code)
            }
            if let continuationToken = response.continuationToken {
                let relation = flowType.link
                guard let href = response.links[relation] else {
                    return .error(MSALNativeAuthFlowError(
                        kind: .generalError,
                        errorDescription: "Invalid authorize-challenge response: missing '\(relation)' link"
                    ))
                }
                return .continuationToken(continuationToken: continuationToken, href: href)
            }
            return .error(MSALNativeAuthFlowError(
                kind: .generalError,
                errorDescription: "authorize-challenge returned neither a continuation token nor a code"
            ))
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func validateInteraction(
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2InteractionValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(flowError(from: error))
        case .success(let response):
            if let error = response.error {
                return .error(flowError(from: error))
            }

            if response.state == "continue" {
                guard let continuationToken = response.continuationToken else {
                    return .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing continuation token in 'continue' response"))
                }
                return .readyToComplete(continuationToken: continuationToken)
            }

            guard let continuationToken = response.continuationToken else {
                return .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Missing continuation token in interaction response"))
            }

            // Sign-in method discovery: no action, but the available methods are embedded.
            if response.action == nil, !response.methods.isEmpty {
                return .signInMethods(continuationToken: continuationToken, methods: response.methods)
            }

            switch response.action {
            case "challenge":
                let method = response.methods.first
                guard let challengeHref = method?.links["challenge"] ?? response.href(forRelation: "challenge") else {
                    return missingLink("challenge")
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
            case "verify":
                // After a password, a `challenge` link plus embedded methods means MFA is required.
                if let challengeHref = response.href(forRelation: "challenge"), !response.methods.isEmpty {
                    return .mfaRequired(
                        continuationToken: continuationToken,
                        methods: response.methods,
                        challengeHref: challengeHref
                    )
                }
                guard let verifyHref = response.href(forRelation: "verify") else {
                    return missingLink("verify")
                }
                // An email/OOB method carries a hint and/or a code length; a password method does not.
                if (response.codeLength ?? 0) > 0 || response.hint != nil || response.methodType == "email" {
                    return .codeRequired(
                        continuationToken: continuationToken,
                        verifyHref: verifyHref,
                        resendHref: response.href(forRelation: "resend"),
                        sentTo: response.hint ?? "",
                        codeLength: response.codeLength ?? 0
                    )
                }
                return .passwordRequired(continuationToken: continuationToken, verifyHref: verifyHref)
            case "enroll", "register":
                guard let enrollHref = response.href(forRelation: "enroll") ?? response.href(forRelation: "register") else {
                    return missingLink("enroll")
                }
                return .registrationRequired(
                    continuationToken: continuationToken,
                    enrollHref: enrollHref,
                    methods: response.methods
                )
            case "activate":
                guard let activateHref = response.href(forRelation: "activate") else {
                    return missingLink("activate")
                }
                return .activationRequired(
                    continuationToken: continuationToken,
                    activateHref: activateHref,
                    sentTo: response.hint ?? "",
                    codeLength: response.codeLength ?? 0
                )
            case "collectAttributes":
                guard let submitHref = response.href(forRelation: "submitAttributes") else {
                    return missingLink("submitAttributes")
                }
                return .attributesRequired(
                    continuationToken: continuationToken,
                    attributes: response.attributes,
                    submitHref: submitHref
                )
            case "update":
                guard let updateHref = response.href(forRelation: "update") ?? response.href(forRelation: "self") else {
                    return missingLink("update")
                }
                return .updateRequired(
                    continuationToken: continuationToken,
                    updateHref: updateHref
                )
            case "poll":
                guard let pollHref = response.href(forRelation: "poll") else {
                    return missingLink("poll")
                }
                return .pollInProgress(
                    continuationToken: continuationToken,
                    pollHref: pollHref
                )
            default:
                return .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Unexpected action '\(response.action ?? "nil")'"))
            }
        }
    }

    func validateToken(
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2TokenValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(flowError(from: error))
        case .success(let response):
            if let error = response.error {
                return .error(flowError(from: error))
            }
            return .success(accessToken: response.accessToken)
        }
    }

    // MARK: - Error mapping

    /// The server returned an action that requires a follow-up link, but that link is absent.
    /// Fail here rather than passing a missing href down to the next request.
    private func missingLink(_ relation: String) -> MSALNativeAuthV2InteractionValidatedResponse {
        return .error(MSALNativeAuthFlowError(
            kind: .generalError,
            errorDescription: "Invalid interaction response: missing '\(relation)' link"
        ))
    }

    private func flowError(from serverError: MSALNativeAuthHALResponse.ServerError) -> MSALNativeAuthFlowError {
        let message = serverError.message
        let errorCodes = estsErrorCodes(from: message)
        let kind: MSALNativeAuthFlowError.Kind

        if serverError.innerErrorCode == "invalidContinuationToken" {
            // An invalid OTP and an invalid continuation token share the inner code; the outer
            // code disambiguates (invalidGrant => the supplied OTP was wrong).
            kind = serverError.code == "invalidGrant" ? .invalidCode : .invalidContinuationToken
        } else if let message = message, message.contains("AADSTS50034") {
            kind = .userNotFound
        } else if serverError.innerErrorCode == "invalidUserNameOrPassword"
                    || errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.invalidCredentials.rawValue) {
            // Wrong username/password at sign in (AADSTS50126): a recoverable credentials error,
            // not an invalid one-time code.
            kind = .invalidPassword
        } else if serverError.code == "invalidGrant" {
            kind = .invalidCode
        } else {
            kind = .generalError
        }

        return MSALNativeAuthFlowError(
            kind: kind,
            errorDescription: message,
            errorCodes: errorCodes,
            correlationId: serverError.correlationId
        )
    }

    /// Extracts the numeric ESTS error codes (e.g. `50126` from `AADSTS50126`) embedded in a
    /// server error message.
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

    private func flowError(from error: Error) -> MSALNativeAuthFlowError {
        if let flowError = error as? MSALNativeAuthFlowError {
            return flowError
        }
        return MSALNativeAuthFlowError(
            kind: .generalError,
            errorDescription: (error as NSError).localizedDescription
        )
    }
}
