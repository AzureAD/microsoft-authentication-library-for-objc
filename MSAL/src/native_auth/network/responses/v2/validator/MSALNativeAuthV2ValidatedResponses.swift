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

/// Validated outcome of an `authorize-challenge` call.
enum MSALNativeAuthV2AuthorizeChallengeValidatedResponse: Equatable {
    /// Bootstrap: `401` carrying the continuation token and the entry links (`sign_up`/`sign_in`/`reset_password`).
    case continuationToken(continuationToken: String, links: [String: String])
    /// Completion: the authorization code to exchange for tokens.
    case authorizationCode(code: String)
    case error(MSALNativeAuthFlowError)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.continuationToken(lToken, lLinks), .continuationToken(rToken, rLinks)):
            return lToken == rToken && lLinks == rLinks
        case let (.authorizationCode(lCode), .authorizationCode(rCode)):
            return lCode == rCode
        case let (.error(lError), .error(rError)):
            return lError.kind == rError.kind
        default:
            return false
        }
    }
}

/// Validated outcome of an SSPR interaction step (resetpassword start / challenge / verify / update / poll).
///
/// A single enum represents every HAL interaction response; the validator selects the case
/// from the HAL `state` / `action` pair.
enum MSALNativeAuthV2InteractionValidatedResponse: Equatable {
    /// Sign-in method discovery: the `signin` response carries a continuation token and the
    /// available authentication methods (each with its own `challenge` link).
    case signInMethods(continuationToken: String, methods: [MSALNativeAuthHALResponse.EmbeddedMethod])
    /// `action == challenge`: a verification method is available; the SDK should auto-trigger the challenge.
    case challengeRequired(continuationToken: String, challengeHref: String?, hint: String?)
    /// `action == verify` on a password method: the user must enter their password.
    case passwordRequired(continuationToken: String, verifyHref: String?)
    /// `action == verify`: a one-time code is required from the user.
    case codeRequired(continuationToken: String, verifyHref: String?, resendHref: String?, sentTo: String, codeLength: Int)
    /// `action == verify` after a password, carrying a `challenge` link and the MFA methods.
    case mfaRequired(continuationToken: String, methods: [MSALNativeAuthHALResponse.EmbeddedMethod], challengeHref: String?)
    /// `action == enroll`/`register`: strong-auth (JIT) registration is required; pick a method to enroll.
    case registrationRequired(continuationToken: String, enrollHref: String?, methods: [MSALNativeAuthHALResponse.EmbeddedMethod])
    /// `action == activate`: a JIT enrollment code is required from the user.
    case activationRequired(continuationToken: String, activateHref: String?, sentTo: String, codeLength: Int)
    /// `action == collectAttributes`: sign-up attributes are required from the user.
    case attributesRequired(continuationToken: String, attributes: [MSALNativeAuthHALResponse.RequiredAttributeEntry], submitHref: String?)
    /// `action == update`: a new password is required from the user.
    case updateRequired(continuationToken: String, updateHref: String?)
    /// `action == poll`: the operation is still running; keep polling.
    case pollInProgress(continuationToken: String, pollHref: String?)
    /// `state == continue`: the flow is ready to complete (call `authorize-challenge`).
    case readyToComplete(continuationToken: String)
    case error(MSALNativeAuthFlowError)

    // swiftlint:disable:next cyclomatic_complexity
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.signInMethods(lToken, lMethods), .signInMethods(rToken, rMethods)):
            return lToken == rToken && lMethods == rMethods
        case let (.challengeRequired(lToken, lHref, lHint), .challengeRequired(rToken, rHref, rHint)):
            return lToken == rToken && lHref == rHref && lHint == rHint
        case let (.passwordRequired(lToken, lHref), .passwordRequired(rToken, rHref)):
            return lToken == rToken && lHref == rHref
        case let (.codeRequired(lToken, lVerify, lResend, lSent, lLen), .codeRequired(rToken, rVerify, rResend, rSent, rLen)):
            return lToken == rToken && lVerify == rVerify && lResend == rResend && lSent == rSent && lLen == rLen
        case let (.mfaRequired(lToken, lMethods, lHref), .mfaRequired(rToken, rMethods, rHref)):
            return lToken == rToken && lMethods == rMethods && lHref == rHref
        case let (.registrationRequired(lToken, lHref, lMethods), .registrationRequired(rToken, rHref, rMethods)):
            return lToken == rToken && lHref == rHref && lMethods == rMethods
        case let (.activationRequired(lToken, lHref, lSent, lLen), .activationRequired(rToken, rHref, rSent, rLen)):
            return lToken == rToken && lHref == rHref && lSent == rSent && lLen == rLen
        case let (.attributesRequired(lToken, lAttrs, lHref), .attributesRequired(rToken, rAttrs, rHref)):
            return lToken == rToken && lAttrs == rAttrs && lHref == rHref
        case let (.updateRequired(lToken, lHref), .updateRequired(rToken, rHref)):
            return lToken == rToken && lHref == rHref
        case let (.pollInProgress(lToken, lHref), .pollInProgress(rToken, rHref)):
            return lToken == rToken && lHref == rHref
        case let (.readyToComplete(lToken), .readyToComplete(rToken)):
            return lToken == rToken
        case let (.error(lError), .error(rError)):
            return lError.kind == rError.kind
        default:
            return false
        }
    }
}

/// Validated outcome of the `/token` exchange.
enum MSALNativeAuthV2TokenValidatedResponse {
    case success(accessToken: String?)
    case error(MSALNativeAuthFlowError)
}
