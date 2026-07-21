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
            request.requestInterceptor = MSALNativeAuthRequestInterceptorBridge(interceptor: interceptor)
        }

        return request
    }
}
