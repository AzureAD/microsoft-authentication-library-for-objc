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

        // Seed with default credential methods for POC
        self.mockCredentialMethods = [
            MSALPasskeyCredentialMethod(
                id: "fido-001",
                displayName: "Security Key (YubiKey 5)",
                createdAt: Date(timeIntervalSinceNow: -86400 * 30),
                credentialID: "abc123base64",
                aaguid: "2fc0579f-8113-47ea-b116-bb5a8db9202a"
            ),
            MSALPhoneCredentialMethod(
                id: "phone-001",
                createdAt: Date(timeIntervalSinceNow: -86400 * 60),
                phoneNumber: "+1 *** ***-4589"
            ),
            MSALPasswordCredentialMethod(
                id: "password-001",
                createdAt: Date(timeIntervalSinceNow: -86400 * 90)
            )
        ]

        super.init()
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

                    // Mock: return current in-memory credential methods
                    continuation.resume(returning: .success(self.mockCredentialMethods))
                }
            }
        }
    }

    // MARK: - Public: Register Credential Method

    /// Register a new credential method.
    ///
    /// - Parameter credentialMethod: The credential method instance to register.
    ///   Pass a concrete subclass such as `MSALPasskeyCredentialMethod` or `MSALPhoneCredentialMethod`.
    /// - Parameter correlationId: Optional correlation ID for request tracing. A new UUID is generated if nil.
    /// - Returns: A `Result` containing the registration outcome (completed or challenge required) or an error.
    public func registerCredentialMethod(
        _ credentialMethod: any MSALCredentialMethodProtocol,
        correlationId: UUID? = nil
    ) async -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
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

                    // Mock: simulate challenge required for phone, immediate for passkey/password
                    let type = credentialMethod.credentialType

                    // Assign server-generated ID and metadata
                    if let method = credentialMethod as? MSALCredentialMethod
                    {
                        method.id = "\(type.rawValue)-\(UUID().uuidString.prefix(8))"
                        method.createdAt = Date()
                    }

                    if type == .passkey || type == .password
                    {
                        self.mockCredentialMethods.append(credentialMethod)
                        continuation.resume(returning: .success(.completed(credentialMethod)))
                    }
                    else
                    {
                        // Simulate challenge required for phone
                        let sentTo = credentialMethod.displayName ?? "***"
                        let challengeState = MSALCredentialMethodChallengeState(
                            sentTo: sentTo,
                            channelType: type.rawValue,
                            codeLength: 6,
                            continuationToken: "mock-continuation-\(UUID().uuidString.prefix(8))",
                            client: self,
                            correlationId: correlationId
                        )
                        self.pendingRegistrationCredential = credentialMethod
                        continuation.resume(returning: .success(.challengeRequired(challengeState)))
                    }
                }
            }
        }
    }

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

                    // Mock: remove credential method from in-memory storage
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

    // MARK: - Internal: Challenge Handling

    internal func submitRegistrationChallenge(
        code: String,
        continuationToken: String,
        correlationId: UUID
    ) async -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>
    {
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

                // Mock: accept any non-empty code
                guard !code.isEmpty else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .invalidInput,
                        message: "Verification code cannot be empty.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                guard let credential = self.pendingRegistrationCredential else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "No pending registration found.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                self.mockCredentialMethods.append(credential)
                self.pendingRegistrationCredential = nil
                continuation.resume(returning: .success(credential))
            }
        }
    }

    internal func resendRegistrationChallenge(
        continuationToken: String,
        correlationId: UUID
    ) async -> Result<MSALCredentialMethodChallengeState, MSALNativeCredentialManagementError>
    {
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

                // Mock: return a new challenge state
                let newState = MSALCredentialMethodChallengeState(
                    sentTo: self.pendingRegistrationCredential?.displayName ?? "***",
                    channelType: self.pendingRegistrationCredential?.credentialType.rawValue,
                    codeLength: 6,
                    continuationToken: "mock-continuation-\(UUID().uuidString.prefix(8))",
                    client: self,
                    correlationId: correlationId
                )
                continuation.resume(returning: .success(newState))
            }
        }
    }

    // MARK: - Private: Properties

    private let config: MSALNativeCredentialManagementConfig
    private let operationQueue: DispatchQueue
    private var mockCredentialMethods: [any MSALCredentialMethodProtocol]
    private var pendingRegistrationCredential: (any MSALCredentialMethodProtocol)?

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
