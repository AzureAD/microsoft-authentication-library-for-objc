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
    func validateAuthorizeChallenge(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse
    func validateInteraction(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2InteractionValidatedResponse
    func validateToken(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2TokenValidatedResponse
}

final class MSALNativeAuthV2ResponseValidator: MSALNativeAuthV2ResponseValidating {

    func validateAuthorizeChallenge(
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(Self.flowError(from: error))
        case .success(let response):
            if let error = response.error {
                return .error(Self.flowError(from: error))
            }
            if let code = response.code {
                return .authorizationCode(code: code)
            }
            if let continuationToken = response.continuationToken {
                return .continuationToken(continuationToken: continuationToken, links: response.links)
            }
            return .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "authorize-challenge returned neither a continuation token nor a code"))
        }
    }

    func validateInteraction(
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2InteractionValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(Self.flowError(from: error))
        case .success(let response):
            if let error = response.error {
                return .error(Self.flowError(from: error))
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
                return .error(MSALNativeAuthFlowError(kind: .generalError, errorDescription: "Unexpected action '\(response.action ?? "nil")'"))
            }
        }
    }

    func validateToken(
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2TokenValidatedResponse {
        switch result {
        case .failure(let error):
            return .error(Self.flowError(from: error))
        case .success(let response):
            if let error = response.error {
                return .error(Self.flowError(from: error))
            }
            return .success(accessToken: response.accessToken)
        }
    }

    // MARK: - Error mapping

    private static func flowError(from serverError: MSALNativeAuthHALResponse.ServerError) -> MSALNativeAuthFlowError {
        let message = serverError.message
        let kind: MSALNativeAuthFlowError.Kind

        if serverError.innerErrorCode == "invalidContinuationToken" {
            // An invalid OTP and an invalid continuation token share the inner code; the outer
            // code disambiguates (invalidGrant => the supplied OTP was wrong).
            kind = serverError.code == "invalidGrant" ? .invalidCode : .invalidContinuationToken
        } else if let message = message, message.contains("AADSTS50034") {
            kind = .userNotFound
        } else if serverError.code == "invalidGrant" {
            kind = .invalidCode
        } else {
            kind = .generalError
        }

        return MSALNativeAuthFlowError(
            kind: kind,
            errorDescription: message,
            correlationId: serverError.correlationId
        )
    }

    private static func flowError(from error: Error) -> MSALNativeAuthFlowError {
        if let flowError = error as? MSALNativeAuthFlowError {
            return flowError
        }
        return MSALNativeAuthFlowError(
            kind: .generalError,
            errorDescription: (error as NSError).localizedDescription
        )
    }
}
