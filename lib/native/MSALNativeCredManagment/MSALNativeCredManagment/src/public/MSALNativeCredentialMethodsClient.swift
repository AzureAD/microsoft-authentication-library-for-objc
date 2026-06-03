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
        guard config.baseURL != nil else
        {
            throw MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "A baseURL must be set on MSALNativeCredentialManagementConfig before initializing the client."
            )
        }
        self.config = config
        self.operationQueue = DispatchQueue(
            label: "com.microsoft.identity.credentialmanagement",
            qos: .userInitiated
        )

        self.apiClient = nil
        self.pendingActivateHref = nil
        self.pendingEnrollmentType = nil

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

        MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "listCredentialMethods: starting")

        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        guard case .success(let accessToken) = tokenResult else
        {
            return .failure(tokenResult.failureValue!)
        }

        switch getAPIClient()
        {
        case .failure(let error):
            return .failure(error)
        case .success(let client):
            return await client.listMethods(
                accessToken: accessToken,
                correlationId: correlationId
            )
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

        MSIDLogger.shared().log(
                    level: .info,
            correlationId: correlationId,
            message: "deleteCredentialMethod: type=\(credentialMethod.credentialType.rawValue)"
        )

        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        guard case .success(let accessToken) = tokenResult else
        {
            return .failure(tokenResult.failureValue!)
        }

        switch getAPIClient()
        {
        case .failure(let error):
            return .failure(error)
        case .success(let client):
            return await client.deleteMethod(
                type: credentialMethod.credentialType,
                methodId: credentialMethod.id,
                accessToken: accessToken,
                correlationId: correlationId
            )
        }
    }

    // MARK: - Internal: Properties (accessible by extensions)

    internal let config: MSALNativeCredentialManagementConfig
    internal let operationQueue: DispatchQueue
    internal var apiClient: (any CredentialManagementNetworkClientProtocol)?
    internal var pendingActivateHref: String?
    internal var pendingEnrollmentType: MSALCredentialType?
}
