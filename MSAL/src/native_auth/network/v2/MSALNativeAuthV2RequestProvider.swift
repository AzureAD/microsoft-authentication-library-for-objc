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
    func token(code: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

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
    func submitAttributes(href: String, attributes: [String: Any], continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest

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
    private let resolver: MSALNativeAuthV2HrefURLResolver

    init(config: MSALNativeAuthInternalConfiguration) {
        self.config = config
        self.resolver = MSALNativeAuthV2HrefURLResolver(config: config)
    }

    func authorizeChallengeStart(context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .authorizeChallenge)
        // The bootstrap authorize-challenge sends ONLY `client_id`. Including `scope` here makes
        // ESTS mint a continuation token scoped for the authorization-code path, which the
        // signup/signin/resetpassword `start` endpoints reject with AADSTS55200 ("continuation_token
        // is invalid"). `scope` is supplied later on the `token` call instead.
        return makeRequest(url: url, method: "POST", form: [
            "client_id": config.clientId
        ], context: context)
    }

    func authorizeChallengeContinue(continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .authorizeChallenge)
        // The authorize-challenge-resume call sends ONLY `continuation_token` (no client_id/scope),
        // matching the server contract; extra parameters cause AADSTS55200 / auth failures.
        return makeRequest(url: url, method: "POST", form: [
            "continuation_token": continuationToken
        ], context: context)
    }

    func token(code: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .token)
        // The authorization_code exchange sends only client_id, code and grant_type. `scope` was
        // already established during the authorize-challenge bootstrap and must not be resent here.
        // The `/token` endpoint returns a standard OAuth token response (NOT HAL), so this request
        // skips the HAL serializer and yields the raw JSON dictionary for the controller to parse
        // into an `MSIDTokenResponse` and persist to the cache (mirroring the V1 sign-in flow).
        return makeRequest(url: url, method: "POST", form: [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": config.clientId
        ], context: context, rawJSONResponse: true)
    }

    func resetPasswordStart(username: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .resetPasswordStart)
        return makeRequest(url: url, method: "POST", json: [
            "username": username,
            "continuationToken": continuationToken
        ], context: context)
    }

    func signInStart(username: String, continuationToken: String, href: String?, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try href.map { try resolver.url(forHref: $0) } ?? resolver.url(for: .signInStart)
        return makeRequest(url: url, method: "POST", json: [
            "username": username,
            "continuationToken": continuationToken
        ], context: context)
    }

    func signUpStart(username: String, continuationToken: String, href: String?, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try href.map { try resolver.url(forHref: $0) } ?? resolver.url(for: .signUpStart)
        return makeRequest(url: url, method: "POST", json: [
            "username": username,
            "continuationToken": continuationToken
        ], context: context)
    }

    func submitPassword(href: String, password: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "password": password,
            "continuationToken": continuationToken
        ], context: context)
    }

    func submitCode(href: String, code: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "code": code,
            "continuationToken": continuationToken
        ], context: context)
    }

    func submitAttributes(href: String, attributes: [String: Any], continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        var body = attributes
        body["continuationToken"] = continuationToken
        return makeRequest(url: url, method: "POST", json: body, context: context)
    }

    func registerMethod(href: String, target: String?, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        var body: [String: Any] = ["continuationToken": continuationToken]
        if let target = target {
            body["target"] = target
        }
        return makeRequest(url: url, method: "POST", json: body, context: context)
    }

    func challenge(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "continuationToken": continuationToken
        ], context: context)
    }

    func verify(href: String, otp: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "otp": otp,
            "continuationToken": continuationToken
        ], context: context)
    }

    func updatePassword(href: String, newPassword: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "PUT", json: [
            "newPassword": newPassword,
            "continuationToken": continuationToken
        ], context: context)
    }

    func poll(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "continuationToken": continuationToken
        ], context: context)
    }

    // MARK: - Request building

    private func makeRequest(
        url: URL,
        method: String,
        json: [String: Any]? = nil,
        form: [String: String]? = nil,
        context: MSALNativeAuthRequestContext,
        rawJSONResponse: Bool = false
    ) -> MSIDHttpRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        var headers: [String: String] = [:]

        if let json = json {
            headers["Content-Type"] = "application/json"
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: json)
        } else if let form = form {
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            urlRequest.httpBody = Self.encodeForm(form).data(using: .utf8)
        }

        headers["Accept"] = "application/json"
        headers["client-request-id"] = context.correlationId().uuidString

        let request = MSIDHttpRequest()
        request.urlRequest = urlRequest
        request.headers = headers
        request.context = context
        // The `/token` endpoint returns a plain OAuth response rather than HAL; leaving the response
        // serializer unset makes `MSIDHttpRequest.send` hand back the raw JSON dictionary.
        if !rawJSONResponse {
            request.responseSerializer = MSALNativeAuthV2HALResponseSerializer()
        }
        request.errorHandler = MSALNativeAuthV2ResponseErrorHandler()

        if let interceptor = config.requestInterceptor {
            request.requestInterceptor = MSALNativeAuthV2RequestInterceptorBridge(interceptor: interceptor)
        }

        return request
    }

    private static func encodeForm(_ parameters: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
    }
}

/// Bridges `MSALNativeAuthRequestInterceptor` (Swift public protocol) to `MSIDHttpRequestInterceptorProtocol` (ObjC).
private final class MSALNativeAuthV2RequestInterceptorBridge: NSObject, MSIDHttpRequestInterceptorProtocol {

    private let interceptor: MSALNativeAuthRequestInterceptor

    init(interceptor: MSALNativeAuthRequestInterceptor) {
        self.interceptor = interceptor
    }

    func addAdditionalHeaderFields(
        for requestUrl: URL?,
        with completionBlock: @escaping MSIDHttpRequestInterceptorAddHeaderCompletionBlock
    ) {
        interceptor.addAdditionalHeaderFields(requestUrl) { additionalHeaders in
            completionBlock(additionalHeaders)
        }
    }
}
