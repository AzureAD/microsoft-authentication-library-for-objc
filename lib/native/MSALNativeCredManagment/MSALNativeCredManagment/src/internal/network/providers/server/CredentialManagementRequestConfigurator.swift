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
import MSAL
@_implementationOnly import MSAL_Private

/// Configures an `MSIDHttpRequest` with the credential management serializers,
/// error handler, server telemetry, and optional interceptor.
///
/// Subclasses `MSIDAADRequestConfigurator` so the request goes through the same
/// AAD pipeline as MSAL native auth: device-id headers, correlation-id headers,
/// PKeyAuth/Accept headers, and network-host resolution are applied via
/// `super.configure(_:)` before the credential-management-specific serializers
/// and telemetry are attached.
internal final class CredentialManagementRequestConfigurator: MSIDAADRequestConfigurator
{
    private let requestSerializer: CredentialManagementRequestSerializing
    private let correlationId: UUID
    private let requestInterceptor: MSALNativeAuthRequestInterceptor?

    init(
        requestSerializer: CredentialManagementRequestSerializing,
        correlationId: UUID,
        requestInterceptor: MSALNativeAuthRequestInterceptor?
    )
    {
        self.requestSerializer = requestSerializer
        self.correlationId = correlationId
        self.requestInterceptor = requestInterceptor
        super.init()
    }

    /// Configures an `MSIDHttpRequest` from a typed request.
    /// Returns the configured request or an error if URL validation fails.
    func configure(
        _ typedRequest: CredentialManagementRequestProtocol
    ) -> Result<MSIDHttpRequest, MSALNativeCredentialManagementError>
    {
        guard let urlRequest = requestSerializer.serialize(typedRequest) else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "URL validation failed: '\(typedRequest.path)' does not belong to the trusted service.",
                correlationId: typedRequest.correlationId
            ))
        }

        let request = MSIDHttpRequest()
        request.urlRequest = urlRequest

        // Context (MSIDRequestContext) carrying correlation id, SDK name/version and app metadata.
        let context = CredentialManagementRequestContext(correlationId: correlationId)
        request.context = context

        // Interceptor
        if let interceptor = requestInterceptor
        {
            request.requestInterceptor = CredentialManagementInterceptorBridge(interceptor: interceptor)
        }

        // Apply the shared AAD pipeline (device-id, correlation-id, PKeyAuth/Accept headers, host resolution).
        configure(request)

        // Credential Management endpoints require `application/hal+json`
        if var urlReq = request.urlRequest
        {
            urlReq.setValue("application/hal+json", forHTTPHeaderField: "Accept")
            request.urlRequest = urlReq
        }

        // Override with credential-management-specific serializers and error handling
        // (AAD configurator sets JSON serializers/AAD error handler which we replace).
        request.responseSerializer = MSIDResponseSerializerAdapter()
        request.errorResponseSerializer = MSIDResponseSerializerAdapter()
        request.errorHandler = CredentialManagementErrorHandler(correlationId: correlationId)

        // Server telemetry (x-client-current-telemetry / x-client-last-telemetry headers).
        let currentTelemetry = CredentialManagementCurrentRequestTelemetry(
            apiId: typedRequest.telemetryApiId,
            operationType: typedRequest.telemetryOperationType
        )
        request.serverTelemetry = CredentialManagementServerTelemetry(
            currentRequestTelemetry: currentTelemetry,
            context: context
        )

        return .success(request)
    }
}
