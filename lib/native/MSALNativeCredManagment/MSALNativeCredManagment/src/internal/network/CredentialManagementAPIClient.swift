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

/// Internal API client that orchestrates network calls and HAL response parsing
/// for the credential management service.
internal final class CredentialManagementAPIClient
{
    private let networkClient: CredentialManagementNetworkClient
    private let baseURL: URL

    private static let methodsPath = "/api/v1.0/me/methods"

    init(baseURL: URL, networkClient: CredentialManagementNetworkClient)
    {
        self.baseURL = baseURL
        self.networkClient = networkClient
    }

    // MARK: - List Methods

    func listMethods(
        accessToken: String,
        correlationId: UUID
    ) async -> Result<[any MSALCredentialMethodProtocol], MSALNativeCredentialManagementError>
    {
        let builder = CredentialManagementRequestBuilder(
            baseURL: baseURL,
            accessToken: accessToken,
            correlationId: correlationId
        )

        let request: CredentialManagementRequest
        switch builder.buildGET(path: Self.methodsPath)
        {
        case .success(let r): request = r
        case .failure(let e): return .failure(e)
        }

        CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "Credential management: listing methods")

        let response: CredentialManagementResponse
        do
        {
            response = try await networkClient.perform(request: request)
        }
        catch
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .networkError,
                message: "Network request failed for listing credential methods.",
                correlationId: correlationId,
                underlyingError: error
            ))
        }

        if let mappedError = CredentialManagementResponseMapper.mapError(from: response, correlationId: correlationId)
        {
            return .failure(mappedError)
        }

        let json: [String: Any]
        switch CredentialManagementResponseMapper.decodeJSON(from: response, correlationId: correlationId)
        {
        case .success(let j): json = j
        case .failure(let e): return .failure(e)
        }

        let halResource = HALResource(json: json)
        let methods = CredentialMethodMapper.parseMethods(from: halResource)

        CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "Credential management: listed \(methods.count) method(s)")

        return .success(methods)
    }

    // MARK: - Begin Enrollment

    func beginEnrollment(
        type: MSALCredentialType,
        accessToken: String,
        body: Data?,
        correlationId: UUID
    ) async -> Result<HALResource, MSALNativeCredentialManagementError>
    {
        let serverType = CredentialMethodMapper.serverType(from: type)
        let path = "\(Self.methodsPath)/\(serverType)"

        let builder = CredentialManagementRequestBuilder(
            baseURL: baseURL,
            accessToken: accessToken,
            correlationId: correlationId
        )

        let request: CredentialManagementRequest
        switch builder.buildPOST(path: path, body: body)
        {
        case .success(let r): request = r
        case .failure(let e): return .failure(e)
        }

        CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "Credential management: beginning enrollment for type '\(serverType)'")

        let response: CredentialManagementResponse
        do
        {
            response = try await networkClient.perform(request: request)
        }
        catch
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .networkError,
                message: "Network request failed for enrollment.",
                correlationId: correlationId,
                underlyingError: error
            ))
        }

        if let mappedError = CredentialManagementResponseMapper.mapError(from: response, correlationId: correlationId)
        {
            return .failure(mappedError)
        }

        let json: [String: Any]
        switch CredentialManagementResponseMapper.decodeJSON(from: response, correlationId: correlationId)
        {
        case .success(let j): json = j
        case .failure(let e): return .failure(e)
        }

        return .success(HALResource(json: json))
    }

    // MARK: - Activate Enrollment

    func activateEnrollment(
        activateHref: String,
        accessToken: String,
        body: Data,
        correlationId: UUID
    ) async -> Result<HALResource, MSALNativeCredentialManagementError>
    {
        let builder = CredentialManagementRequestBuilder(
            baseURL: baseURL,
            accessToken: accessToken,
            correlationId: correlationId
        )

        let request: CredentialManagementRequest
        switch builder.buildPOST(path: activateHref, body: body)
        {
        case .success(let r): request = r
        case .failure(let e): return .failure(e)
        }

        CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "Credential management: activating enrollment")

        let response: CredentialManagementResponse
        do
        {
            response = try await networkClient.perform(request: request)
        }
        catch
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .networkError,
                message: "Network request failed for activation.",
                correlationId: correlationId,
                underlyingError: error
            ))
        }

        if let mappedError = CredentialManagementResponseMapper.mapError(from: response, correlationId: correlationId)
        {
            return .failure(mappedError)
        }

        let json: [String: Any]
        switch CredentialManagementResponseMapper.decodeJSON(from: response, correlationId: correlationId)
        {
        case .success(let j): json = j
        case .failure(let e): return .failure(e)
        }

        return .success(HALResource(json: json))
    }

    // MARK: - Delete Method

    func deleteMethod(
        type: MSALCredentialType,
        methodId: String,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<Void, MSALNativeCredentialManagementError>
    {
        let serverType = CredentialMethodMapper.serverType(from: type)
        let path = "\(Self.methodsPath)/\(serverType)/\(methodId)"

        let builder = CredentialManagementRequestBuilder(
            baseURL: baseURL,
            accessToken: accessToken,
            correlationId: correlationId
        )

        let request: CredentialManagementRequest
        switch builder.buildDELETE(path: path)
        {
        case .success(let r): request = r
        case .failure(let e): return .failure(e)
        }

        CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "Credential management: deleting method of type '\(serverType)'")

        let response: CredentialManagementResponse
        do
        {
            response = try await networkClient.perform(request: request)
        }
        catch
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .networkError,
                message: "Network request failed for deletion.",
                correlationId: correlationId,
                underlyingError: error
            ))
        }

        if let mappedError = CredentialManagementResponseMapper.mapError(from: response, correlationId: correlationId)
        {
            return .failure(mappedError)
        }

        CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "Credential management: method deleted successfully")

        return .success(())
    }
}
