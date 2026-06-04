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

// MARK: - Protocol

/// Internal protocol that unifies the server-backed client and the mock client
/// behind a single HAL-free interface.
///
/// Implementations own the transport details (HAL parsing, link tracking, serialization, etc.)
/// and expose only typed domain models to callers.
internal protocol CredentialManagementNetworkClientProtocol
{
    /// List all credential methods for the authenticated user.
    func listMethods(
        accessToken: String,
        correlationId: UUID
    ) async -> Result<[any MSALCredentialMethodProtocol], MSALNativeCredentialManagementError>

    /// Begin enrollment of a new credential method.
    ///
    /// Returns a typed `EnrollmentBeginResponse` that tells the caller whether
    /// enrollment completed, a challenge is required, or passkey creation options are available.
    func beginEnrollment(
        params: EnrollmentParams,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<EnrollmentBeginResponse, MSALNativeCredentialManagementError>

    /// Activate (complete) an enrollment that required a second step.
    ///
    /// The `continuationToken` identifies the pending enrollment. The implementation
    /// resolves any internal resource context (e.g., HAL links) from its in-memory store.
    func activateEnrollment(
        params: ActivationParams,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>

    /// Delete a credential method.
    func deleteMethod(
        type: MSALCredentialType,
        methodId: String,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<Void, MSALNativeCredentialManagementError>
}

// MARK: - Request Params

/// Typed parameters for beginning enrollment of a credential method.
internal enum EnrollmentParams
{
    case phone(phoneNumber: String)
    case password(password: String)
    case passkey
}

/// Typed parameters for activating (completing) a pending enrollment.
internal enum ActivationParams
{
    /// OTP-based activation (phone / password challenge).
    case otp(continuationToken: String, code: String)

    /// Passkey attestation-based activation.
    case passkey(
        continuationToken: String,
        displayName: String,
        credentialId: Data,
        attestationObject: Data,
        clientDataJSON: Data
    )
}

// MARK: - Response Types

/// HAL-free result of a `beginEnrollment` call.
///
/// Callers use this typed response instead of parsing raw HAL resources.
/// The HAL-specific link/resource context is managed internally by the server layer.
internal enum EnrollmentBeginResponse
{
    /// Enrollment completed in one step (e.g., password).
    case completed(any MSALCredentialMethodProtocol)

    /// A verification challenge was sent (e.g., OTP to phone).
    case challengeRequired(EnrollmentChallengeInfo)

    /// Server returned WebAuthn creation options for passkey registration.
    case passkeyCreationRequired(PasskeyCreationInfo)
}

/// Information about a verification challenge sent during enrollment.
internal struct EnrollmentChallengeInfo
{
    let sentTo: String?
    let channelType: String?
    let codeLength: Int?
    let continuationToken: String
}

/// Information needed to invoke the platform authenticator for passkey creation.
internal struct PasskeyCreationInfo
{
    let publicKey: [String: Any]
    let continuationToken: String
}
