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

/// Internal API client that orchestrates network calls using `MSIDHttpRequest`
/// infrastructure from IdentityCore.
///
/// Architecture (follows IdentityCore pattern):
/// 1. Typed request objects define endpoint-specific data
/// 2. `CredentialManagementRequestConfigurator` wires serializers/handlers onto MSIDHttpRequest
/// 3. MSIDHttpRequest sends via URLSession with retry/telemetry
/// 4. `MSIDResponseSerializerAdapter` bridges to pure-Swift response parsing
/// 5. Response mappers transform parsed responses into domain objects
internal final class CredentialManagementAPIClient: CredentialManagementNetworkClientProtocol
{
    private let requestSerializer: CredentialManagementRequestSerializing
    private let requestInterceptor: MSALNativeAuthRequestInterceptor?

    init(requestSerializer: CredentialManagementRequestSerializing, requestInterceptor: MSALNativeAuthRequestInterceptor?)
    {
        self.requestSerializer = requestSerializer
        self.requestInterceptor = requestInterceptor
    }

    // MARK: - List Methods

    func listMethods(
        accessToken: String,
        correlationId: UUID
    ) async -> Result<[any MSALCredentialMethodProtocol], MSALNativeCredentialManagementError>
    {
        let typedRequest = ListMethodsRequest(accessToken: accessToken, correlationId: correlationId)

        MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "Credential management: listing methods")

        let sendResult = await send(typedRequest)

        switch sendResult
        {
        case .failure(let e):
            return .failure(e)
        case .success(let response):
            let mapResult = ListMethodsResponseMapper.map(response, correlationId: correlationId)
            if case .success(let methods) = mapResult
            {
                MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "Credential management: listed \(methods.count) method(s)")
            }
            return mapResult
        }
    }

    // MARK: - Begin Enrollment

    func beginEnrollment(
        type: MSALCredentialType,
        accessToken: String,
        body: Data?,
        correlationId: UUID
    ) async -> Result<HALResource, MSALNativeCredentialManagementError>
    {
        let typedRequest = BeginEnrollmentRequest(
            type: type,
            accessToken: accessToken,
            body: body,
            correlationId: correlationId
        )

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "Credential management: beginning enrollment for type '\(CredentialMethodMapper.serverType(from: type))'"
        )

        let sendResult = await send(typedRequest)
        return sendResult.flatMap { EnrollmentResponseMapper.map($0, correlationId: correlationId) }
    }

    // MARK: - Activate Enrollment

    func activateEnrollment(
        activateHref: String,
        accessToken: String,
        body: Data,
        correlationId: UUID
    ) async -> Result<HALResource, MSALNativeCredentialManagementError>
    {
        let typedRequest = ActivateEnrollmentRequest(
            activateHref: activateHref,
            accessToken: accessToken,
            body: body,
            correlationId: correlationId
        )

        MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "Credential management: activating enrollment")

        let sendResult = await send(typedRequest)
        return sendResult.flatMap { EnrollmentResponseMapper.map($0, correlationId: correlationId) }
    }

    // MARK: - Delete Method

    func deleteMethod(
        type: MSALCredentialType,
        methodId: String,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<Void, MSALNativeCredentialManagementError>
    {
        let typedRequest = DeleteMethodRequest(
            type: type,
            methodId: methodId,
            accessToken: accessToken,
            correlationId: correlationId
        )

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "Credential management: deleting method of type '\(CredentialMethodMapper.serverType(from: type))'"
        )

        let sendResult = await send(typedRequest)

        switch sendResult
        {
        case .failure(let e):
            return .failure(e)
        case .success:
            MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "Credential management: method deleted successfully")
            return .success(())
        }
    }

    // MARK: - Private: Send Pipeline

    /// Configures and sends a typed request through the MSIDHttpRequest pipeline.
    private func send(
        _ typedRequest: CredentialManagementRequestProtocol
    ) async -> Result<CredentialManagementResponse, MSALNativeCredentialManagementError>
    {
        let configurator = CredentialManagementRequestConfigurator(
            requestSerializer: requestSerializer,
            correlationId: typedRequest.correlationId,
            requestInterceptor: requestInterceptor
        )

        let configResult = configurator.configure(typedRequest)

        let msidRequest: MSIDHttpRequest
        switch configResult
        {
        case .success(let r): msidRequest = r
        case .failure(let e): return .failure(e)
        }

        return await withCheckedContinuation
        { continuation in
            msidRequest.send
            { result, error in
                if let error = error
                {
                    if let credError = error as? MSALNativeCredentialManagementError
                    {
                        continuation.resume(returning: .failure(credError))
                    }
                    else
                    {
                        continuation.resume(returning: .failure(MSALNativeCredentialManagementError(
                            type: .networkError,
                            message: "Network request failed.",
                            correlationId: typedRequest.correlationId,
                            underlyingError: error
                        )))
                    }
                }
                else if let response = result as? CredentialManagementResponse
                {
                    continuation.resume(returning: .success(response))
                }
                else
                {
                    continuation.resume(returning: .failure(MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Unexpected response type from network layer.",
                        correlationId: typedRequest.correlationId
                    )))
                }
            }
        }
    }
}
