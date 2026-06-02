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

extension MSALNativeCredentialMethodsClient
{
    /// Step 1: Request passkey creation options from the server.
    internal func performRegisterPasskey(
        params: MSALRegisterPasskeyParams?
    ) async -> Result<MSALPasskeyRegistrationState, MSALNativeCredentialManagementError>
    {
        let correlationId = params?.correlationId ?? UUID()

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
                            message: "Failed to acquire access token for passkey registration.",
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

                    // Mock server response: generate WebAuthn creation options
                    // In production, this would be a POST to the credential management API
                    // which returns PublicKeyCredentialCreationOptions.
                    var challengeBytes = [UInt8](repeating: 0, count: 32)
                    _ = SecRandomCopyBytes(kSecRandomDefault, challengeBytes.count, &challengeBytes)

                    let creationOptions = MSALPasskeyCreationOptions(
                        challenge: Data(challengeBytes),
                        userId: Data(UUID().uuidString.utf8),
                        userName: params?.displayName ?? "user",
                        relyingPartyIdentifier: "login.microsoft.com"
                    )

                    let continuationToken = "passkey-reg-\(UUID().uuidString)"

                    let state = MSALPasskeyRegistrationState(
                        creationOptions: creationOptions,
                        continuationToken: continuationToken,
                        client: self,
                        correlationId: correlationId
                    )

                    continuation.resume(returning: .success(state))
                }
            }
        }
    }

    /// Step 2: Submit the attestation from the platform authenticator to the server.
    internal func completePasskeyRegistration(
        attestation: MSALPasskeyAttestation,
        continuationToken: String,
        correlationId: UUID
    ) async -> Result<MSALPasskeyCredentialMethod, MSALNativeCredentialManagementError>
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

                self.acquireToken(correlationId: correlationId)
                { accessToken, tokenError in
                    if let tokenError = tokenError
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Failed to acquire access token for completing passkey registration.",
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

                    // Mock server response: validate attestation and store credential.
                    // In production, this would POST the attestation to the server
                    // which validates and returns the registered credential method.
                    let credentialIdString = attestation.credentialId.base64EncodedString()
                    let method = MSALPasskeyCredentialMethod(
                        id: "passkey-\(UUID().uuidString.prefix(8))",
                        displayName: "Passkey (\(String(credentialIdString.prefix(8)))...)",
                        createdAt: Date(),
                        credentialID: credentialIdString,
                        aaguid: nil
                    )
                    self.mockCredentialMethods.append(method)
                    continuation.resume(returning: .success(method))
                }
            }
        }
    }
}
