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
/// (e.g., phone, passkey, password) for the currently signed-in user.
///
/// Example:
/// ```swift
/// let credConfig = MSALNativeCredentialManagementConfig()
/// credConfig.requestInterceptor = sharedRequestInterceptor
/// credConfig.tokenProvider = myTokenProvider
/// let credClient = try MSALNativeCredentialMethodsClient(config: credConfig)
/// ```
@objcMembers
public class MSALNativeCredentialMethodsClient: NSObject {

    // MARK: - Public: Initialization

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
        self.mockCredentialMethods = []
        self.pendingRegistrationCredential = nil

        super.init()

        seedMockData()
    }

    // MARK: - Public: List Credential Methods

    /// Retrieve the list of credential methods registered for the current user.
    ///
    /// - Parameter correlationId: Optional correlation ID for request tracing. A new UUID is generated if nil.
    /// - Returns: A `Result` containing the array of credential methods or an error.
    public func listCredentialMethods(
        correlationId: UUID? = nil
    ) async -> Result<[any MSALCredentialMethodProtocol], MSALNativeCredentialManagementError>
    {
        let correlationId = correlationId ?? UUID()

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

                    continuation.resume(returning: .success(self.mockCredentialMethods))
                }
            }
        }
    }

    // MARK: - Public: Register Operations

    /// Namespace grouping for method-specific registration flows.
    ///
    /// Each credential type has its own function because registration inputs
    /// and activation flows differ per type.
    ///
    /// Usage:
    /// ```swift
    /// let params = MSALRegisterPasskeyParams(presentationAnchor: window, displayName: "My Key")
    /// let result = await client.register.passkey(params: params)
    /// // All register methods return Result<MSALCredentialMethodRegistrationResult, ...>
    /// let result = await client.register.phoneNumber(params: MSALRegisterPhoneNumberParams(phoneNumber: "+1234567890"))
    /// let result = await client.register.password(params: MSALRegisterPasswordParams(password: "secret"))
    /// ```
    public private(set) lazy var register: MSALRegisterMethods = MSALRegisterMethods(client: self)

    // MARK: - Public: Delete Credential Method

    /// Delete a credential method.
    ///
    /// - Parameter credentialMethod: The credential method to remove.
    /// - Parameter correlationId: Optional correlation ID for request tracing. A new UUID is generated if nil.
    /// - Returns: A `Result` indicating success or containing an error.
    public func deleteCredentialMethod(
        _ credentialMethod: any MSALCredentialMethodProtocol,
        correlationId: UUID? = nil
    ) async -> Result<Void, MSALNativeCredentialManagementError>
    {
        let correlationId = correlationId ?? UUID()

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

                    let methodId = credentialMethod.id
                    if let index = self.mockCredentialMethods.firstIndex(where: { $0.id == methodId })
                    {
                        self.mockCredentialMethods.remove(at: index)
                        continuation.resume(returning: .success(()))
                    }
                    else
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .notFound,
                            message: "Credential method with id '\(methodId)' not found.",
                            correlationId: correlationId
                        )
                        continuation.resume(returning: .failure(credError))
                    }
                }
            }
        }
    }

    // MARK: - Internal: Properties (accessible by extensions)

    internal let config: MSALNativeCredentialManagementConfig
    internal let operationQueue: DispatchQueue
    internal var mockCredentialMethods: [any MSALCredentialMethodProtocol]
    internal var pendingRegistrationCredential: (any MSALCredentialMethodProtocol)?
}
