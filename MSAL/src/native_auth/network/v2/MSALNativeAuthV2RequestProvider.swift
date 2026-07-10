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

@_implementationOnly import MSAL_Private

/// Builds the `MSIDHttpRequest` objects for each step of the Native Auth V2 flows.
protocol MSALNativeAuthV2RequestProviding {

    /// Step 1: bootstrap `authorize-challenge` (no continuation token) → `401` + continuation token.
    func authorizeChallengeStart(context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Step 7: completion `authorize-challenge` (with continuation token) → authorization code.
    func authorizeChallengeContinue(continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Step 8: token exchange.
    func token(code: String, scopes: [String], context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Step 2: SSPR entry (fixed endpoint).
    func resetPasswordStart(username: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Sign in entry: posts the username to the bootstrap `sign_in` href (or the fixed endpoint).
    func signInStart(username: String, continuationToken: String, href: String?, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Sign up entry: posts the username to the bootstrap `sign_up` href (or the fixed endpoint).
    func signUpStart(username: String, continuationToken: String, href: String?, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Submit a password to a server `verify` href (sign in / MFA primary factor).
    func submitPassword(href: String, password: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Submit a one-time `code` to a server `verify` / `activate` href (sign in / sign up / MFA / JIT).
    func submitCode(href: String, code: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Submit collected attributes (sign up) to a server `submitAttributes` href.
    func submitAttributes(
        href: String,
        attributes: [String: Any],
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequest

    /// Register a strong-auth method (JIT) by posting the target to a server `enroll` href.
    func registerMethod(href: String, target: String?, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Step 3: send EOTP (server `challenge` / `resend` href).
    func challenge(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Step 4: verify OTP (server `verify` href).
    func verify(href: String, otp: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Step 5: update password (server `update` href, PUT).
    func updatePassword(href: String, newPassword: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

    /// Step 6: poll for completion (server `poll` href).
    func poll(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest
}

final class MSALNativeAuthV2RequestProvider: MSALNativeAuthV2RequestProviding {

    private let config: MSALNativeAuthInternalConfiguration
    private let configurator: MSALNativeAuthV2RequestConfigurator

    init(config: MSALNativeAuthInternalConfiguration) {
        self.config = config
        self.configurator = MSALNativeAuthV2RequestConfigurator(config: config)
    }

    func authorizeChallengeStart(context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        // The bootstrap authorize-challenge sends ONLY `client_id`. Including `scope` here makes
        // ESTS mint a continuation token scoped for the authorization-code path, which the
        // signup/signin/resetpassword `start` endpoints reject with AADSTS55200 ("continuation_token
        // is invalid"). `scope` is supplied later on the `token` call instead (see `token(code:scopes:context:)`).
        return try configurator.configure(parameters: MSALNativeAuthV2AuthorizeChallengeStartParameters(context: context, clientId: config.clientId))
    }

    func authorizeChallengeContinue(continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        // The authorize-challenge-resume call sends ONLY `continuation_token` (no client_id/scope),
        // matching the server contract; extra parameters cause AADSTS55200 / auth failures.
        return try configurator.configure(
            parameters: MSALNativeAuthV2AuthorizeChallengeContinueParameters(context: context, continuationToken: continuationToken)
        )
    }

    func token(code: String, scopes: [String], context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        // The authorization_code exchange sends client_id, code, grant_type and the requested
        // `scope` (caller scopes merged with the default OIDC scopes), mirroring the V1 sign-in
        // token call. `scope` is sent here — not on the authorize-challenge bootstrap — because
        // including it in the bootstrap makes ESTS mint a continuation token the start endpoints
        // reject with AADSTS55200.
        // The `/token` endpoint returns a standard OAuth token response (NOT HAL), so this request
        // yields the raw JSON dictionary for the controller to parse into an `MSIDTokenResponse` and
        // persist to the cache (mirroring the V1 sign-in flow).
        // `client_info=true` (added by the parameter class) asks ESTS to return the `client_info`
        // blob (uid/utid) in the token response. IdentityCore's AAD-v2/CIAM factory rejects any
        // token response without it ("Client info was not returned in the server response"), which
        // surfaces to the caller as "Unable to save tokens to the cache".
        return try configurator.configure(parameters: MSALNativeAuthV2TokenParameters(
            context: context,
            clientId: config.clientId,
            code: code,
            scopes: scopes
        ))
    }

    func resetPasswordStart(username: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2EntryParameters(
            context: context,
            target: .endpoint(.resetPasswordStart),
            apiId: .telemetryApiIdV2ResetPassword,
            operationType: MSALNativeAuthV2OperationType.resetPasswordStart.rawValue,
            username: username,
            continuationToken: continuationToken
        ))
    }

    func signInStart(username: String, continuationToken: String, href: String?, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2EntryParameters(
            context: context,
            target: href.map { .href($0) } ?? .endpoint(.signInStart),
            apiId: .telemetryApiIdV2SignIn,
            operationType: MSALNativeAuthV2OperationType.signInStart.rawValue,
            username: username,
            continuationToken: continuationToken
        ))
    }

    func signUpStart(username: String, continuationToken: String, href: String?, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2EntryParameters(
            context: context,
            target: href.map { .href($0) } ?? .endpoint(.signUpStart),
            apiId: .telemetryApiIdV2SignUp,
            operationType: MSALNativeAuthV2OperationType.signUpStart.rawValue,
            username: username,
            continuationToken: continuationToken
        ))
    }

    func submitPassword(href: String, password: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.submitPassword.rawValue,
            body: ["password": password, "continuationToken": continuationToken]
        ))
    }

    func submitCode(href: String, code: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.submitCode.rawValue,
            body: ["code": code, "continuationToken": continuationToken]
        ))
    }

    func submitAttributes(
        href: String,
        attributes: [String: Any],
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.submitAttributes.rawValue,
            body: ["attributes": attributes, "continuationToken": continuationToken]
        ))
    }

    func registerMethod(href: String, target: String?, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        var body: [AnyHashable: Any] = ["continuationToken": continuationToken]
        if let target = target {
            body["target"] = target
        }
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.registerMethod.rawValue,
            body: body
        ))
    }

    func challenge(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.challenge.rawValue,
            body: ["continuationToken": continuationToken]
        ))
    }

    func verify(href: String, otp: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.verify.rawValue,
            body: ["otp": otp, "continuationToken": continuationToken]
        ))
    }

    func updatePassword(
        href: String,
        newPassword: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "PUT",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.updatePassword.rawValue,
            body: ["newPassword": newPassword, "continuationToken": continuationToken]
        ))
    }

    func poll(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        return try configurator.configure(parameters: MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2Hal,
            operationType: MSALNativeAuthV2OperationType.poll.rawValue,
            body: ["continuationToken": continuationToken]
        ))
    }
}
