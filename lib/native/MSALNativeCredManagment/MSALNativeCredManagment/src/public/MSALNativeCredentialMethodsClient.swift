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

/// Client for managing credential methods of an authenticated CIAM user.
///
/// This client provides APIs to list, register, and delete credential methods
/// (e.g., email, phone, passkey) for the currently signed-in user.
///
/// Example:
/// ```swift
/// let credConfig = MSALNativeCredentialManagementConfig()
/// credConfig.requestInterceptor = sharedRequestInterceptor
/// credConfig.tokenProvider = myTokenProvider
/// let credClient = try MSALNativeCredentialMethodsClient(config: credConfig)
/// credClient.listCredentialMethods(delegate: self)
/// ```
@objcMembers
public class MSALNativeCredentialMethodsClient: NSObject {

    private let config: MSALNativeCredentialManagementConfig
    private let operationQueue: DispatchQueue

    // Mock storage simulating server-side credential methods
    private var mockCredentialMethods: [MSALCredentialMethod]

    /// Initialize the credential methods client.
    ///
    /// - Parameter config: Configuration including token provider and optional interceptor.
    /// - Throws: `MSALNativeCredentialManagementError` if the configuration is invalid (e.g., no token provider set).
    public init(config: MSALNativeCredentialManagementConfig) throws
    {
        guard config.tokenProvider != nil else
        {
            throw MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "A token provider must be set on MSALNativeCredentialManagementConfig before initializing the client."
            )
        }
        self.config = config
        self.operationQueue = DispatchQueue(
            label: "com.microsoft.identity.credentialmanagement",
            qos: .userInitiated
        )

        // Seed with default credential methods for POC
        self.mockCredentialMethods = [
            MSALCredentialMethod(
                id: "fido-001",
                credentialType: "fido2",
                displayName: "Security Key (YubiKey 5)",
                isDefault: true,
                createdAt: Date(timeIntervalSinceNow: -86400 * 30),
                metadata: ["aaguid": "2fc0579f-8113-47ea-b116-bb5a8db9202a"]
            ),
            MSALCredentialMethod(
                id: "phone-001",
                credentialType: "phone",
                displayName: "+1 *** ***-4589",
                isDefault: false,
                createdAt: Date(timeIntervalSinceNow: -86400 * 60),
                metadata: nil
            ),
            MSALCredentialMethod(
                id: "password-001",
                credentialType: "password",
                displayName: "Password",
                isDefault: false,
                createdAt: Date(timeIntervalSinceNow: -86400 * 90),
                metadata: nil
            )
        ]

        super.init()
    }

    // MARK: - List Credential Methods

    /// Retrieve the list of credential methods registered for the current user.
    ///
    /// - Returns: A `Result` containing the array of credential methods or an error.
    public func listCredentialMethods() async -> Result<[MSALCredentialMethod], MSALNativeCredentialManagementError>
    {
        let correlationId = config.correlationId ?? UUID()

        return await withCheckedContinuation
        { continuation in
            self.operationQueue.async
            { [weak self] in
                guard let self = self else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Client was deallocated.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                self.acquireToken(correlationId: correlationId)
                { accessToken, tokenError in
                    if let tokenError = tokenError
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Failed to acquire access token for listing credential methods.",
                            correlationId: correlationId,
                            underlyingError: tokenError
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    guard accessToken != nil else
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Token provider returned nil access token.",
                            correlationId: correlationId
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    // Mock: return current in-memory credential methods
                    continuation.resume(returning: .success(self.mockCredentialMethods))
                }
            }
        }
    }

    // MARK: - Register Credential Method

    /// Register a new credential method.
    ///
    /// - Parameters:
    ///   - type: The credential type to register (e.g., "email", "phone", "passkey").
    ///   - parameters: Type-specific parameters (e.g., email address, phone number).
    /// - Returns: A `Result` containing the newly registered credential method or an error.
    public func registerCredentialMethod(
        type: String,
        parameters: [String: Any]?
    ) async -> Result<MSALCredentialMethod, MSALNativeCredentialManagementError>
    {
        let correlationId = config.correlationId ?? UUID()

        return await withCheckedContinuation
        { continuation in
            self.operationQueue.async
            { [weak self] in
                guard let self = self else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Client was deallocated.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                self.acquireToken(correlationId: correlationId)
                { accessToken, tokenError in
                    if let tokenError = tokenError
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Failed to acquire access token for registering credential method.",
                            correlationId: correlationId,
                            underlyingError: tokenError
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    guard accessToken != nil else
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Token provider returned nil access token.",
                            correlationId: correlationId
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    // Mock: add new credential method to in-memory storage
                    let newMethod = MSALCredentialMethod(
                        id: "\(type)-\(UUID().uuidString.prefix(8))",
                        credentialType: type,
                        displayName: (parameters?["value"] as? String) ?? type,
                        isDefault: false,
                        createdAt: Date(),
                        metadata: nil
                    )
                    self.mockCredentialMethods.append(newMethod)
                    continuation.resume(returning: .success(newMethod))
                }
            }
        }
    }

    // MARK: - Delete Credential Method

    /// Delete a credential method by its identifier.
    ///
    /// - Parameter credentialMethod: The ID of the credential method to remove.
    /// - Returns: A `Result` indicating success or containing an error.
    public func deleteCredentialMethod(
        credentialMethod: String
    ) async -> Result<Void, MSALNativeCredentialManagementError>
    {
        let correlationId = config.correlationId ?? UUID()

        return await withCheckedContinuation
        { continuation in
            self.operationQueue.async
            { [weak self] in
                guard let self = self else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Client was deallocated.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                self.acquireToken(correlationId: correlationId)
                { accessToken, tokenError in
                    if let tokenError = tokenError
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Failed to acquire access token for deleting credential method.",
                            correlationId: correlationId,
                            underlyingError: tokenError
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    guard accessToken != nil else
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Token provider returned nil access token.",
                            correlationId: correlationId
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    // Mock: remove credential method from in-memory storage
                    if let index = self.mockCredentialMethods.firstIndex(where: { $0.id == credentialMethod })
                    {
                        self.mockCredentialMethods.remove(at: index)
                        continuation.resume(returning: .success(()))
                    }
                    else
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .notFound,
                            message: "Credential method with id '\(credentialMethod)' not found.",
                            correlationId: correlationId
                        )
                        continuation.resume(returning: .failure(credError))
                    }
                }
            }
        }
    }

    // MARK: - Private: Token Acquisition

    private func acquireToken(
        correlationId: UUID,
        completion: @escaping (String?, Error?) -> Void
    )
    {
        guard let tokenProvider = config.tokenProvider else
        {
            let error = MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "Token provider is not configured.",
                correlationId: correlationId
            )
            completion(nil, error)
            return
        }

        // TODO: Replace with actual scopes for credential management API once defined
        let scopes = ["openid", "offline_access"]

        tokenProvider.getAccessToken(scopes: scopes)
        { accessToken, error in
            completion(accessToken, error)
        }
    }
}

