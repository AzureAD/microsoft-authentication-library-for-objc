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

// MARK: - Request parameters

/// Describes a single V2 native-auth request: each concrete parameter type knows its target URL,
/// HTTP method, body, body encoding and telemetry identity. `MSALNativeAuthV2RequestConfigurator`
/// turns any of these into a fully-configured `MSIDHttpRequest` that reuses the shared AAD request
/// pipeline (device-id headers, PkeyAuth, correlation, server telemetry).
protocol MSALNativeAuthV2Requestable {
    var context: MSALNativeAuthRequestContext { get }
    var httpMethod: String { get }
    var encoding: MSALNativeAuthUrlRequestEncoding { get }
    var apiId: MSALNativeAuthTelemetryApiId { get }
    var operationType: MSALNativeAuthOperationType { get }
    /// `true` only for the `/token` endpoint, which returns a plain OAuth response (not HAL) and must
    /// keep the default raw-JSON response serializer instead of the HAL serializer.
    var expectsRawJSONResponse: Bool { get }
    var body: [AnyHashable: Any] { get }
    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL
}

extension MSALNativeAuthV2Requestable {
    var httpMethod: String { "POST" }
    var expectsRawJSONResponse: Bool { false }
}

/// The destination of a V2 request: either a well-known endpoint or a server-provided HAL `href`.
enum MSALNativeAuthV2RequestTarget {
    case endpoint(MSALNativeAuthV2Endpoint)
    case href(String)

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        switch self {
        case .endpoint(let endpoint):
            return try resolver.url(for: endpoint)
        case .href(let href):
            return try resolver.url(forHref: href)
        }
    }
}

/// `POST /authorize/challenge` (the authorization challenge that starts a flow). Sends ONLY `client_id` (form encoded).
struct MSALNativeAuthV2AuthorizeChallengeStartParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let clientId: String
    let encoding: MSALNativeAuthUrlRequestEncoding = .wwwFormUrlEncoded
    let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2AuthorizeChallenge
    let operationType: MSALNativeAuthOperationType = MSALNativeAuthV2OperationType.authorizeChallengeStart.rawValue

    var body: [AnyHashable: Any] {
        return ["client_id": clientId]
    }

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try resolver.url(for: .authorizeChallenge)
    }
}

/// `POST /authorize/challenge` resume. Sends ONLY `continuation_token` (form encoded).
struct MSALNativeAuthV2AuthorizeChallengeContinueParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let continuationToken: String
    let encoding: MSALNativeAuthUrlRequestEncoding = .wwwFormUrlEncoded
    let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2AuthorizeChallenge
    let operationType: MSALNativeAuthOperationType = MSALNativeAuthV2OperationType.authorizeChallengeContinue.rawValue

    var body: [AnyHashable: Any] {
        return ["continuation_token": continuationToken]
    }

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try resolver.url(for: .authorizeChallenge)
    }
}

/// `POST /token` authorization-code exchange. Form encoded, raw OAuth (non-HAL) response. Includes
/// `client_info=true` so ESTS returns the `client_info` blob required to persist tokens to the cache.
struct MSALNativeAuthV2TokenParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let clientId: String
    let code: String
    let scopes: [String]
    let encoding: MSALNativeAuthUrlRequestEncoding = .wwwFormUrlEncoded
    let apiId: MSALNativeAuthTelemetryApiId = .telemetryApiIdV2Token
    let operationType: MSALNativeAuthOperationType = MSALNativeAuthV2OperationType.token.rawValue
    let expectsRawJSONResponse = true

    var body: [AnyHashable: Any] {
        var form: [AnyHashable: Any] = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            MSALNativeAuthRequestParametersKey.clientInfo.rawValue: true.description
        ]
        if !scopes.isEmpty {
            form["scope"] = scopes.joined(separator: " ")
        }
        return form
    }

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try resolver.url(for: .token)
    }
}

/// The signup/signin/resetpassword `start` entry requests. JSON encoded `{username, continuationToken}`,
/// targeting either the well-known start endpoint or a server-provided `href`.
struct MSALNativeAuthV2EntryParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let target: MSALNativeAuthV2RequestTarget
    let apiId: MSALNativeAuthTelemetryApiId
    let operationType: MSALNativeAuthOperationType
    let username: String
    let continuationToken: String
    let encoding: MSALNativeAuthUrlRequestEncoding = .json

    var body: [AnyHashable: Any] {
        return ["username": username, "continuationToken": continuationToken]
    }

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try target.url(resolver: resolver)
    }
}

/// A HAL follow-up request driven by a server-provided `href` (challenge, verify, submit*, register,
/// update-password, poll). JSON encoded with a caller-supplied body.
struct MSALNativeAuthV2HrefParameters: MSALNativeAuthV2Requestable {
    let context: MSALNativeAuthRequestContext
    let href: String
    let httpMethod: String
    let apiId: MSALNativeAuthTelemetryApiId
    let operationType: MSALNativeAuthOperationType
    let body: [AnyHashable: Any]
    let encoding: MSALNativeAuthUrlRequestEncoding = .json

    func url(resolver: MSALNativeAuthV2HrefURLResolver) throws -> URL {
        return try resolver.url(forHref: href)
    }
}

// MARK: - Request configurator

/// Builds a fully-configured `MSIDHttpRequest` for any `MSALNativeAuthV2Requestable`. Subclassing
/// `MSIDAADRequestConfigurator` gives V2 the standard device-id (`x-client-*`) headers, app metadata,
/// PkeyAuth, `Accept: application/json`, correlation headers and the authority network-host rewrite.
/// On top of that it attaches the V2 HAL / raw-JSON response serializer, the V2 error handler, server
/// telemetry and the request interceptor.
final class MSALNativeAuthV2RequestConfigurator: MSIDAADRequestConfigurator {

    private let config: MSALNativeAuthInternalConfiguration
    private let resolver: MSALNativeAuthV2HrefURLResolver

    init(config: MSALNativeAuthInternalConfiguration) {
        self.config = config
        self.resolver = MSALNativeAuthV2HrefURLResolver(config: config)
    }

    func configure(parameters: MSALNativeAuthV2Requestable) throws -> MSIDHttpRequest {
        let url = try parameters.url(resolver: resolver)

        let request = MSIDHttpRequest()
        // Capture the default raw-JSON response serializer before the base `configure(_:)` swaps it for
        // the AAD serializer, so the `/token` endpoint (a plain OAuth response, not HAL) can restore it.
        let rawJSONResponseSerializer = request.responseSerializer

        request.context = parameters.context
        // `MSIDHttpRequest.parameters` is typed `[String: String]` for AAD form posts, but V2 HAL bodies
        // can contain nested JSON (e.g. the sign-up `attributes` object). Assign via KVC so the nested
        // dictionary is preserved and JSON-serialized as-is by `MSALNativeAuthUrlRequestSerializer`.
        request.setValue(parameters.body, forKey: "parameters")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = parameters.httpMethod
        request.urlRequest = urlRequest

        request.requestSerializer = MSALNativeAuthUrlRequestSerializer(
            context: parameters.context,
            encoding: parameters.encoding
        )

        // Reuse the shared AAD request pipeline.
        configure(request)

        // `MSIDAADRequestConfigurator` writes the standard headers onto `urlRequest`, but the native
        // auth request serializer rebuilds `allHTTPHeaderFields` from `request.headers` at send time.
        // Copy the configured headers across so the device/PkeyAuth/correlation headers survive
        // serialization and reach the wire. (Server-telemetry headers are applied post-serialization by
        // `MSIDHttpRequest.send`, so they survive regardless.)
        if let configuredHeaders = request.urlRequest?.allHTTPHeaderFields {
            request.headers = configuredHeaders
        }

        request.serverTelemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: MSALNativeAuthCurrentRequestTelemetry(
                apiId: parameters.apiId,
                operationType: parameters.operationType,
                platformFields: nil
            ),
            context: parameters.context
        )

        if parameters.expectsRawJSONResponse {
            request.responseSerializer = rawJSONResponseSerializer
        } else {
            request.responseSerializer = MSALNativeAuthV2HALResponseSerializer()
        }
        request.errorHandler = MSALNativeAuthV2ResponseErrorHandler()

        if let interceptor = config.requestInterceptor {
            request.requestInterceptor = MSALNativeAuthV2RequestInterceptorBridge(interceptor: interceptor)
        }

        return request
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
