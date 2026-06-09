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

/// Client for managing credential methods of an authenticated CIAM user.
///
/// This client provides APIs to list, register, and delete credential methods
/// (e.g., passkey) for the currently signed-in user.
///
/// Example:
/// ```swift
/// let config = MSALNativeCredentialManagementConfig()
/// config.tokenProvider = myTokenProvider
/// config.tenantSubdomain = "contoso"
/// let client = try MSALNativeCredentialMethodsClient(config: config)
///
/// let result = await client.listCredentialMethods()
/// ```
@objcMembers
public class MSALNativeCredentialMethodsClient: NSObject
{
    // MARK: - Public: Initialization

    /// Initialize the credential methods client.
    ///
    /// - Parameter config: Configuration including token provider and tenant subdomain.
    /// - Throws: `MSALNativeCredentialManagementError` if the configuration is invalid
    ///   (e.g., no token provider or tenant subdomain set).
    public init(config: MSALNativeCredentialManagementConfig) throws
    {
        guard config.tokenProvider != nil else
        {
            throw MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "A token provider must be set on MSALNativeCredentialManagementConfig before initializing the client."
            )
        }
        guard config.tenantSubdomain != nil else
        {
            throw MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "A tenantSubdomain must be set on MSALNativeCredentialManagementConfig before initializing the client."
            )
        }
        self.config = config
        super.init()
    }

    // MARK: - Public: List Credential Methods

    /// Retrieve the list of credential methods registered for the current user.
    ///
    /// - Parameter correlationId: Optional correlation ID for request tracing.
    ///   A new UUID is generated if nil.
    /// - Returns: A `Result` containing the array of credential methods or an error.
    public func listCredentialMethods(
        correlationId: UUID? = nil
    ) async -> Result<[any MSALCredentialMethodProtocol], MSALNativeCredentialManagementError>
    {
        fatalError("Not implemented — stub only")
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
    /// ```
    public private(set) lazy var register: MSALRegisterMethods = MSALRegisterMethods(client: self)

    // MARK: - Public: Delete Credential Method

    /// Delete a credential method.
    ///
    /// - Parameters:
    ///   - credentialMethod: The credential method to remove.
    ///   - correlationId: Optional correlation ID for request tracing.
    ///     A new UUID is generated if nil.
    /// - Returns: A `Result` indicating success or containing an error.
    public func deleteCredentialMethod(
        _ credentialMethod: any MSALCredentialMethodProtocol,
        correlationId: UUID? = nil
    ) async -> Result<Void, MSALNativeCredentialManagementError>
    {
        fatalError("Not implemented — stub only")
    }

    // MARK: - Internal

    internal let config: MSALNativeCredentialManagementConfig
}
