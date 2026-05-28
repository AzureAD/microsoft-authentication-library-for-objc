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
    /// - Parameter delegate: Receives the result or error callback on the main thread.
    public func listCredentialMethods(delegate: MSALCredentialMethodsListDelegate)
    {
        let correlationId = config.correlationId ?? UUID()

        operationQueue.async
        { [weak self] in
            guard let self = self else { return }

            self.acquireToken(correlationId: correlationId)
            { accessToken, error in
                if let error = error
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Failed to acquire access token for listing credential methods.",
                        correlationId: correlationId,
                        underlyingError: error
                    )
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodsListError(error: credError)
                    }
                    return
                }

                guard let accessToken = accessToken else
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Token provider returned nil access token.",
                        correlationId: correlationId
                    )
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodsListError(error: credError)
                    }
                    return
                }

                // Mock: return current in-memory credential methods
                _ = accessToken
                let methods = self.mockCredentialMethods
                DispatchQueue.main.async
                {
                    delegate.onCredentialMethodsListCompleted(methods: methods)
                }
            }
        }
    }

    // MARK: - Register Credential Method

    /// Begin registration of a new credential method.
    ///
    /// - Parameters:
    ///   - type: The credential type to register (e.g., "email", "phone", "passkey").
    ///   - parameters: Type-specific parameters (e.g., email address, phone number).
    ///   - delegate: Receives state transitions (challenge required, completed, error) on the main thread.
    public func registerCredentialMethod(
        type: String,
        parameters: [String: Any]?,
        delegate: MSALCredentialMethodRegisterDelegate
    )
    {
        let correlationId = config.correlationId ?? UUID()

        operationQueue.async
        { [weak self] in
            guard let self = self else { return }

            self.acquireToken(correlationId: correlationId)
            { accessToken, error in
                if let error = error
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Failed to acquire access token for registering credential method.",
                        correlationId: correlationId,
                        underlyingError: error
                    )
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodRegistrationError(error: credError)
                    }
                    return
                }

                guard accessToken != nil else
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Token provider returned nil access token.",
                        correlationId: correlationId
                    )
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodRegistrationError(error: credError)
                    }
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
                DispatchQueue.main.async
                {
                    delegate.onCredentialMethodRegistrationCompleted(method: newMethod)
                }
            }
        }
    }

    // MARK: - Delete Credential Method

    /// Delete a credential method by its identifier.
    ///
    /// - Parameters:
    ///   - credentialMethodId: The ID of the credential method to remove.
    ///   - delegate: Receives completion or error callback on the main thread.
    public func deleteCredentialMethod(
        credentialMethodId: String,
        delegate: MSALCredentialMethodDeleteDelegate
    )
    {
        let correlationId = config.correlationId ?? UUID()

        operationQueue.async
        { [weak self] in
            guard let self = self else { return }

            self.acquireToken(correlationId: correlationId)
            { accessToken, error in
                if let error = error
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Failed to acquire access token for deleting credential method.",
                        correlationId: correlationId,
                        underlyingError: error
                    )
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodDeleteError(error: credError)
                    }
                    return
                }

                guard accessToken != nil else
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Token provider returned nil access token.",
                        correlationId: correlationId
                    )
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodDeleteError(error: credError)
                    }
                    return
                }

                // Mock: remove credential method from in-memory storage
                if let index = self.mockCredentialMethods.firstIndex(where: { $0.id == credentialMethodId })
                {
                    self.mockCredentialMethods.remove(at: index)
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodDeleteCompleted()
                    }
                }
                else
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .notFound,
                        message: "Credential method with id '\(credentialMethodId)' not found.",
                        correlationId: correlationId
                    )
                    DispatchQueue.main.async
                    {
                        delegate.onCredentialMethodDeleteError(error: credError)
                    }
                }
            }
        }
    }

    // MARK: - Internal: Challenge Handling

    internal func submitRegistrationChallenge(
        code: String,
        continuationToken: String,
        delegate: MSALCredentialMethodRegisterDelegate
    )
    {
        let correlationId = config.correlationId ?? UUID()

        operationQueue.async
        { [weak self] in
            guard self != nil else { return }

            // TODO: Implement network call to submit challenge verification
            let credError = MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Challenge submission not yet implemented.",
                correlationId: correlationId
            )
            DispatchQueue.main.async
            {
                delegate.onCredentialMethodRegistrationError(error: credError)
            }
        }
    }

    internal func resendRegistrationChallenge(
        continuationToken: String,
        delegate: MSALCredentialMethodRegisterDelegate
    )
    {
        let correlationId = config.correlationId ?? UUID()

        operationQueue.async
        { [weak self] in
            guard self != nil else { return }

            // TODO: Implement network call to resend challenge
            let credError = MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Challenge resend not yet implemented.",
                correlationId: correlationId
            )
            DispatchQueue.main.async
            {
                delegate.onCredentialMethodRegistrationError(error: credError)
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

