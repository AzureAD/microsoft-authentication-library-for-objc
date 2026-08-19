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

/// Parsed outcome of an `authorize-challenge` call.
enum MSALNativeAuthV2AuthorizeChallengeParsedResponse: Equatable {
    /// `401` carrying the continuation token and the resolved entry link for the flow
    /// (`sign_up` / `sign_in` / `reset_password`).
    case continuationToken(continuationToken: String, href: String)
    /// Completion: the authorization code to exchange for tokens.
    case authorizationCode(code: String)
    case error(MSALNativeAuthFlowError)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.continuationToken(lToken, lHref), .continuationToken(rToken, rHref)):
            return lToken == rToken && lHref == rHref
        case let (.authorizationCode(lCode), .authorizationCode(rCode)):
            return lCode == rCode
        case let (.error(lError), .error(rError)):
            return lError.type == rError.type
        default:
            return false
        }
    }
}

/// A verification method offered in a HAL `_embedded.methods` array, carrying the href the SDK
/// must follow to trigger that method's challenge.
struct MSALNativeAuthV2ChallengeMethod: Equatable {
    let id: String
    /// The method's channel (e.g. "email").
    let channelType: String
    let hint: String?
    let challengeHref: String
}

/// Parsed outcome of an SSPR interaction step (resetpassword start / challenge / verify / update / poll).
///
/// A single enum represents every HAL interaction response; the parser selects the case
/// from the HAL `state` / `action` pair.
enum MSALNativeAuthV2InteractionParsedResponse: Equatable {
    /// `action == challenge`: a verification method is available; the SDK should auto-trigger the challenge.
    case challengeRequired(continuationToken: String, challengeHref: String, hint: String?)
    /// `action == challenge` with `challengeContext.authenticationFactor == multiFactor`: multi-factor
    /// authentication is required and the user must select one of the available methods.
    case mfaRequired(continuationToken: String, methods: [MSALNativeAuthV2ChallengeMethod])
    /// `action == verify`: the server selected a method that must now be verified. 
    case verificationRequired(
        continuationToken: String,
        verifyHref: String,
        resendHref: String?,
        sentTo: String,
        channelType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    /// `action == update`: a new password is required from the user.
    case updateRequired(continuationToken: String, updateHref: String)
    /// `action == poll`: the operation is still running; keep polling.
    case pollInProgress(continuationToken: String, pollHref: String)
    /// `state == continue`: the flow is ready to complete (call `authorize-challenge`).
    case readyToComplete(continuationToken: String)
    /// `error == redirect_to_web` / `state == webFallbackRequired`: the flow must continue in a browser.
    case browserRequired
    case error(MSALNativeAuthFlowError)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.challengeRequired(lToken, lHref, lHint), .challengeRequired(rToken, rHref, rHint)):
            return lToken == rToken && lHref == rHref && lHint == rHint
        case let (.mfaRequired(lToken, lMethods), .mfaRequired(rToken, rMethods)):
            return lToken == rToken && lMethods == rMethods
        case let (
            .verificationRequired(lToken, lVerify, lResend, lSent, lChannel, lLen),
            .verificationRequired(rToken, rVerify, rResend, rSent, rChannel, rLen)
        ):
            return lToken == rToken && lVerify == rVerify && lResend == rResend && lSent == rSent && lChannel.value == rChannel.value && lLen == rLen
        case let (.updateRequired(lToken, lHref), .updateRequired(rToken, rHref)):
            return lToken == rToken && lHref == rHref
        case let (.pollInProgress(lToken, lHref), .pollInProgress(rToken, rHref)):
            return lToken == rToken && lHref == rHref
        case let (.readyToComplete(lToken), .readyToComplete(rToken)):
            return lToken == rToken
        case (.browserRequired, .browserRequired):
            return true
        case let (.error(lError), .error(rError)):
            return lError.type == rError.type
        default:
            return false
        }
    }
}
