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
    private let defaultScope = "openid offline_access profile"

    init(config: MSALNativeAuthInternalConfiguration) {
        self.config = config
        self.resolver = MSALNativeAuthV2HrefURLResolver(config: config)
    }

    func authorizeChallengeStart(context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .authorizeChallenge)
        return makeRequest(url: url, method: "POST", form: [
            "client_id": config.clientId,
            "scope": defaultScope
        ], context: context)
    }

    func authorizeChallengeContinue(continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .authorizeChallenge)
        return makeRequest(url: url, method: "POST", form: [
            "client_id": config.clientId,
            "scope": defaultScope,
            "continuation_token": continuationToken
        ], context: context)
    }

    func token(code: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .token)
        return makeRequest(url: url, method: "POST", form: [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": config.clientId,
            "scope": defaultScope
        ], context: context)
    }

    func resetPasswordStart(username: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(for: .resetPasswordStart)
        return makeRequest(url: url, method: "POST", json: [
            "username": username,
            "continuation_token": continuationToken
        ], context: context)
    }

    func challenge(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "continuation_token": continuationToken
        ], context: context)
    }

    func verify(href: String, otp: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "otp": otp,
            "continuation_token": continuationToken
        ], context: context)
    }

    func updatePassword(href: String, newPassword: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "PUT", json: [
            "new_password": newPassword,
            "continuation_token": continuationToken
        ], context: context)
    }

    func poll(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        let url = try resolver.url(forHref: href)
        return makeRequest(url: url, method: "POST", json: [
            "continuation_token": continuationToken
        ], context: context)
    }

    // MARK: - Request building

    private func makeRequest(
        url: URL,
        method: String,
        json: [String: Any]? = nil,
        form: [String: String]? = nil,
        context: MSALNativeAuthRequestContext
    ) -> MSIDHttpRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if let json = json {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: json)
        } else if let form = form {
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = Self.encodeForm(form).data(using: .utf8)
        }

        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(context.correlationId().uuidString, forHTTPHeaderField: "client-request-id")

        let request = MSIDHttpRequest()
        request.urlRequest = urlRequest
        request.context = context
        request.responseSerializer = MSALNativeAuthV2HALResponseSerializer()
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
