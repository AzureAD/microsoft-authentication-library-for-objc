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

/// WebAuthn creation options returned by the server for passkey registration.
///
/// Use these values to configure `ASAuthorizationPlatformPublicKeyCredentialProvider`
/// and create a credential registration request.
@objcMembers
public class MSALPasskeyCreationOptions: NSObject
{
    /// The WebAuthn challenge (random bytes from the server).
    public let challenge: Data

    /// The user identifier assigned by the server.
    public let userId: Data

    /// The user display name (e.g., email or friendly name) for the passkey prompt.
    public let userName: String

    /// The relying party identifier (e.g., "login.microsoft.com").
    public let relyingPartyIdentifier: String

    internal init(
        challenge: Data,
        userId: Data,
        userName: String,
        relyingPartyIdentifier: String
    )
    {
        self.challenge = challenge
        self.userId = userId
        self.userName = userName
        self.relyingPartyIdentifier = relyingPartyIdentifier
        super.init()
    }
}

/// State object returned after requesting passkey registration from the server.
///
/// Contains the WebAuthn creation options needed to invoke the platform authenticator,
/// and a `complete(attestation:)` method to finalize registration.
///
/// Usage:
/// ```swift
/// let result = await client.register.passkey(params: params)
/// switch result {
/// case .success(let state):
///     // Use state.creationOptions to drive ASAuthorization
///     let credential = try await performPlatformPasskeyCreation(with: state.creationOptions)
///     let finalResult = await state.complete(attestation: attestation)
/// case .failure(let error):
///     // handle error
/// }
/// ```
public class MSALPasskeyRegistrationState
{
    /// The WebAuthn creation options to use with the platform authenticator.
    public let creationOptions: MSALPasskeyCreationOptions

    // MARK: - Internal

    private let continuationToken: String
    private weak var client: MSALNativeCredentialMethodsClient?
    private let correlationId: UUID

    internal init(
        creationOptions: MSALPasskeyCreationOptions,
        continuationToken: String,
        client: MSALNativeCredentialMethodsClient,
        correlationId: UUID
    )
    {
        self.creationOptions = creationOptions
        self.continuationToken = continuationToken
        self.client = client
        self.correlationId = correlationId
    }

    /// Complete passkey registration by submitting the attestation from the platform authenticator.
    ///
    /// - Parameter attestation: The attestation data from the credential creation response.
    /// - Returns: A `Result` containing the registered passkey credential method or an error.
    public func complete(
        attestation: MSALPasskeyAttestation
    ) async -> Result<MSALPasskeyCredentialMethod, MSALNativeCredentialManagementError>
    {
        guard let client = client else
        {
            let error = MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Client was deallocated.",
                correlationId: correlationId
            )
            return .failure(error)
        }

        return await client.completePasskeyRegistration(
            attestation: attestation,
            continuationToken: continuationToken,
            correlationId: correlationId
        )
    }
}

/// Attestation data from the platform authenticator after passkey creation.
///
/// Populate this from the `ASAuthorizationPlatformPublicKeyCredentialRegistration` response.
@objcMembers
public class MSALPasskeyAttestation: NSObject
{
    /// The credential ID assigned by the authenticator.
    public let credentialId: Data

    /// The raw attestation object (CBOR-encoded).
    public let rawAttestationObject: Data

    /// The raw client data JSON.
    public let rawClientDataJSON: Data

    public init(
        credentialId: Data,
        rawAttestationObject: Data,
        rawClientDataJSON: Data
    )
    {
        self.credentialId = credentialId
        self.rawAttestationObject = rawAttestationObject
        self.rawClientDataJSON = rawClientDataJSON
        super.init()
    }
}
