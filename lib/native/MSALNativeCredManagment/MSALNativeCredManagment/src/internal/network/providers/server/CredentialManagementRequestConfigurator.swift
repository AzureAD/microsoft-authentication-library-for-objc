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
/// error handler, and optional interceptor.
///
/// Follows the IdentityCore `MSIDHttpRequestConfiguratorProtocol` pattern:
/// the configurator wires all cross-cutting concerns onto a request before sending.
internal final class CredentialManagementRequestConfigurator
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

        // Serializers
        request.responseSerializer = MSIDResponseSerializerAdapter()
        request.errorResponseSerializer = MSIDResponseSerializerAdapter()

        // Error handler
        request.errorHandler = CredentialManagementErrorHandler(correlationId: correlationId)

        // Context
        let context = MSIDBasicContext()
        context.correlationId = correlationId
        request.context = context

        // Interceptor
        if let interceptor = requestInterceptor
        {
            request.requestInterceptor = CredentialManagementInterceptorBridge(interceptor: interceptor)
        }

        return .success(request)
    }
}
