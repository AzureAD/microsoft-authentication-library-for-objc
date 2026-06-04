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

/// Server-backed implementation of `CredentialManagementNetworkClientProtocol`.
///
/// This layer:
/// 1. Sends requests through the MSIDHttpRequest pipeline.
/// 2. Parses HAL responses internally.
/// 3. Maintains an in-memory relation store that maps `continuationToken` → HAL link context.
/// 4. Exposes only typed domain models to callers.
///
/// HAL concepts (links, embedded resources) never escape this layer.
internal final class CredentialManagementServerNetworkClient: CredentialManagementNetworkClientProtocol
{
    private let requestSerializer: CredentialManagementRequestSerializing
    private let requestInterceptor: MSALNativeAuthRequestInterceptor?

    /// In-memory relation store: maps continuationToken → activate href.
    /// This keeps HAL link context hidden from callers.
    private var activateHrefStore: [String: String] = [:]

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
        params: EnrollmentParams,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<EnrollmentBeginResponse, MSALNativeCredentialManagementError>
    {
        let type: MSALCredentialType
        let body: Data?

        switch params
        {
        case .phone(let phoneNumber):
            type = .phone
            body = try? JSONSerialization.data(withJSONObject: ["phoneNumber": phoneNumber])
        case .password(let password):
            type = .password
            body = try? JSONSerialization.data(withJSONObject: ["password": password])
        case .passkey:
            type = .passkey
            body = nil
        }

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

        switch sendResult
        {
        case .failure(let e):
            return .failure(e)
        case .success(let response):
            return mapEnrollmentResponse(response, type: type, correlationId: correlationId)
        }
    }

    // MARK: - Activate Enrollment

    func activateEnrollment(
        params: ActivationParams,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>
    {
        let continuationToken: String
        let body: Data

        switch params
        {
        case .otp(let token, let code):
            continuationToken = token
            let bodyDict: [String: Any] = ["continuationToken": token, "oob": code]
            guard let encoded = try? JSONSerialization.data(withJSONObject: bodyDict) else
            {
                return .failure(MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: "Failed to encode OTP activation body.",
                    correlationId: correlationId
                ))
            }
            body = encoded

        case .passkey(let token, let displayName, let credentialId, let attestationObject, let clientDataJSON):
            continuationToken = token
            let bodyDict: [String: Any] = [
                "continuationToken": token,
                "displayName": displayName,
                "publicKeyCredential": [
                    "id": credentialId.base64EncodedString(),
                    "response": [
                        "attestationObject": attestationObject.base64EncodedString(),
                        "clientDataJSON": clientDataJSON.base64EncodedString()
                    ]
                ]
            ]
            guard let encoded = try? JSONSerialization.data(withJSONObject: bodyDict) else
            {
                return .failure(MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: "Failed to encode passkey activation body.",
                    correlationId: correlationId
                ))
            }
            body = encoded
        }

        // Resolve the activate href from our internal relation store
        guard let activateHref = activateHrefStore.removeValue(forKey: continuationToken) else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "No activate link found for the given continuation token.",
                correlationId: correlationId
            ))
        }

        let typedRequest = ActivateEnrollmentRequest(
            activateHref: activateHref,
            accessToken: accessToken,
            body: body,
            correlationId: correlationId
        )

        MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "Credential management: activating enrollment")

        let sendResult = await send(typedRequest)

        switch sendResult
        {
        case .failure(let e):
            return .failure(e)
        case .success(let response):
            return mapActivationResponse(response, correlationId: correlationId)
        }
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

    // MARK: - Private: Response Mapping

    /// Maps a raw enrollment response into a typed `EnrollmentBeginResponse`.
    /// Stores any HAL activate link in the internal relation store.
    private func mapEnrollmentResponse(
        _ response: CredentialManagementResponse,
        type: MSALCredentialType,
        correlationId: UUID
    ) -> Result<EnrollmentBeginResponse, MSALNativeCredentialManagementError>
    {
        guard let json = response.jsonBody else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Response body is empty or not valid JSON.",
                correlationId: correlationId
            ))
        }

        let halResource = HALResource(json: json)

        // Check if enrollment completed in one step
        let state = halResource.string(forKey: "state")
        if state == "completed" || halResource.link(rel: "activate") == nil
        {
            if let method = CredentialMethodMapper.parseMethod(from: halResource.properties)
            {
                return .success(.completed(method))
            }
            // Fallback for password
            if type == .password
            {
                let method = MSALPasswordCredentialMethod(
                    id: halResource.string(forKey: "id") ?? UUID().uuidString,
                    createdAt: Date()
                )
                return .success(.completed(method))
            }
        }

        // Multi-step: extract continuation token and store activate link
        guard let continuationToken = halResource.string(forKey: "continuationToken") else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Server did not return continuationToken.",
                correlationId: correlationId
            ))
        }

        if let activateLink = halResource.link(rel: "activate")
        {
            activateHrefStore[continuationToken] = activateLink.href
        }

        // Passkey: return creation options
        if let publicKeyDict = halResource.properties["publicKey"] as? [String: Any]
        {
            let info = PasskeyCreationInfo(
                publicKey: publicKeyDict,
                continuationToken: continuationToken
            )
            return .success(.passkeyCreationRequired(info))
        }

        // Phone/other: return challenge info
        let challengeInfo = EnrollmentChallengeInfo(
            sentTo: halResource.string(forKey: "sentTo"),
            channelType: halResource.string(forKey: "channelType"),
            codeLength: halResource.properties["codeLength"] as? Int,
            continuationToken: continuationToken
        )
        return .success(.challengeRequired(challengeInfo))
    }

    /// Maps an activation response into a typed credential method.
    private func mapActivationResponse(
        _ response: CredentialManagementResponse,
        correlationId: UUID
    ) -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>
    {
        guard let json = response.jsonBody else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Activation response body is empty or not valid JSON.",
                correlationId: correlationId
            ))
        }

        let halResource = HALResource(json: json)

        guard let method = CredentialMethodMapper.parseMethod(from: halResource.properties) else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Failed to parse registered method from activation response.",
                correlationId: correlationId
            ))
        }

        return .success(method)
    }

    // MARK: - Private: Send Pipeline

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
