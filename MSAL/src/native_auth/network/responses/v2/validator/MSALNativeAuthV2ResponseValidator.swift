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
        correlationId: UUID
    ) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse
    func validateInteraction(
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        correlationId: UUID
    ) -> MSALNativeAuthV2InteractionValidatedResponse
    func validateToken(
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        correlationId: UUID
    ) -> MSALNativeAuthV2TokenValidatedResponse
}

final class MSALNativeAuthV2ResponseValidator: MSALNativeAuthV2ResponseValidating {

    func validateAuthorizeChallenge(
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        correlationId: UUID
    ) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(Self.flowError(from: error, fallbackCorrelationId: correlationId))
        case .success(let response):
            if let error = response.error {
                return .error(Self.flowError(from: error, fallbackCorrelationId: correlationId))
            }
            if let code = response.code {
                return .authorizationCode(code: code)
            }
            if let continuationToken = response.continuationToken {
                return .continuationToken(continuationToken: continuationToken, links: response.links)
            }
            return .error(MSALNativeAuthFlowError(
                type: .generalError,
                errorDescription: "authorize-challenge returned neither a continuation token nor a code",
                correlationId: response.correlationId ?? correlationId
            ))
        }
    }

    func validateInteraction(
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        correlationId: UUID
    ) -> MSALNativeAuthV2InteractionValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(Self.flowError(from: error, fallbackCorrelationId: correlationId))
        case .success(let response):
            if let error = response.error {
                return .error(Self.flowError(from: error, fallbackCorrelationId: correlationId))
            }

            if response.state == "continue" {
                guard let continuationToken = response.continuationToken else {
                    return .error(MSALNativeAuthFlowError(
                        type: .generalError,
                        errorDescription: "Missing continuation token in 'continue' response",
                        correlationId: response.correlationId ?? correlationId
                    ))
                }
                return .readyToComplete(continuationToken: continuationToken)
            }

            guard let continuationToken = response.continuationToken else {
                return .error(MSALNativeAuthFlowError(
                    type: .generalError,
                    errorDescription: "Missing continuation token in interaction response",
                    correlationId: response.correlationId ?? correlationId
                ))
            }

            // Sign-in method discovery: no action, but the available methods are embedded.
            if response.action == nil, !response.methods.isEmpty {
                return .signInMethods(continuationToken: continuationToken, methods: response.methods)
            }

            switch response.action {
            case "challenge":
                let method = response.methods.first
                return .challengeRequired(
                    continuationToken: continuationToken,
                    challengeHref: method?.links["challenge"] ?? response.href(forRelation: "challenge"),
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
                let verifyHref = response.href(forRelation: "verify")
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
                return .registrationRequired(
                    continuationToken: continuationToken,
                    enrollHref: response.href(forRelation: "enroll") ?? response.href(forRelation: "register"),
                    methods: response.methods
                )
            case "activate":
                return .activationRequired(
                    continuationToken: continuationToken,
                    activateHref: response.href(forRelation: "activate"),
                    sentTo: response.hint ?? "",
                    codeLength: response.codeLength ?? 0
                )
            case "collectAttributes":
                return .attributesRequired(
                    continuationToken: continuationToken,
                    attributes: response.attributes,
                    submitHref: response.href(forRelation: "submitAttributes") ?? response.href(forRelation: "submitattributes")
                )
            case "update":
                return .updateRequired(
                    continuationToken: continuationToken,
                    updateHref: response.href(forRelation: "update") ?? response.href(forRelation: "self")
                )
            case "poll":
                return .pollInProgress(
                    continuationToken: continuationToken,
                    pollHref: response.href(forRelation: "poll")
                )
            default:
                return .error(MSALNativeAuthFlowError(
                    type: .generalError,
                    errorDescription: "Unexpected action '\(response.action ?? "nil")'",
                    correlationId: response.correlationId ?? correlationId
                ))
            }
        }
    }

    func validateToken(
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        correlationId: UUID
    ) -> MSALNativeAuthV2TokenValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(Self.flowError(from: error, fallbackCorrelationId: correlationId))
        case .success(let response):
            if let error = response.error {
                return .error(Self.flowError(from: error, fallbackCorrelationId: correlationId))
            }
            return .success(accessToken: response.accessToken)
        }
    }

    // MARK: - Error mapping

    private static func flowError(
        from serverError: MSALNativeAuthHALResponse.ServerError,
        fallbackCorrelationId: UUID
    ) -> MSALNativeAuthFlowError {
        let message = serverError.message
        let errorCodes = Self.estsErrorCodes(from: message)
        let type: MSALNativeAuthFlowError.ErrorType

        if serverError.innerErrorCode == "invalidContinuationToken" {
            // An invalid OTP and an invalid continuation token share the inner code; the outer
            // code disambiguates (invalidGrant => the supplied OTP was wrong).
            type = serverError.code == "invalidGrant" ? .invalidCode : .invalidContinuationToken
        } else if serverError.innerErrorCode == "providerBlockedByRep" {
            // Mirrors V1 `.authMethodBlocked` (accessDenied + providerBlockedByRep sub error).
            type = .authMethodBlocked
        } else if serverError.innerErrorCode == "invalidOOBValue" {
            // Mirrors V1 `.invalidChallenge` (invalidGrant + invalidOOBValue sub error).
            type = .invalidChallenge
        } else if serverError.innerErrorCode == "userAlreadyExists"
                    || serverError.code == "userAlreadyExists" {
            type = .userAlreadyExists
        } else if let message = message, message.contains("AADSTS50034")
                    || errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue) {
            type = .userNotFound
        } else if errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.userNotHaveAPassword.rawValue) {
            // Mirrors V1 `.userDoesNotHavePassword` (AADSTS500222).
            type = .userDoesNotHavePassword
        } else if errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.invalidVerificationContact.rawValue) {
            // Mirrors V1 `.verificationContactBlocked` (AADSTS901001).
            type = .verificationContactBlocked
        } else if errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.invalidRequestParameter.rawValue) {
            // Mirrors V1 `.invalidInput` (AADSTS90100) surfaced during strong-auth registration.
            type = .invalidInput
        } else if serverError.innerErrorCode == "invalidUserNameOrPassword"
                    || errorCodes.contains(MSALNativeAuthESTSApiErrorCodes.invalidCredentials.rawValue) {
            // Wrong username/password at sign in (AADSTS50126). Mirrors the V1 `.invalidCredentials`
            // case: a recoverable credentials error distinct from an invalid one-time code or a
            // password that failed the sign-up policy.
            type = .invalidCredentials
        } else if serverError.code == "invalidGrant" {
            type = .invalidCode
        } else {
            type = .generalError
        }

        return MSALNativeAuthFlowError(
            type: type,
            errorDescription: message,
            errorCodes: errorCodes,
            correlationId: serverError.correlationId ?? fallbackCorrelationId
        )
    }

    /// Extracts the numeric ESTS error codes (e.g. `50126` from `AADSTS50126`) embedded in a
    /// server error message, mirroring the `error_codes` array the V1 flows surface.
    private static func estsErrorCodes(from message: String?) -> [Int] {
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

    private static func flowError(from error: Error, fallbackCorrelationId: UUID) -> MSALNativeAuthFlowError {
        if let flowError = error as? MSALNativeAuthFlowError {
            return flowError
        }
        return MSALNativeAuthFlowError(
            type: .generalError,
            errorDescription: (error as NSError).localizedDescription,
            correlationId: fallbackCorrelationId
        )
    }
}
