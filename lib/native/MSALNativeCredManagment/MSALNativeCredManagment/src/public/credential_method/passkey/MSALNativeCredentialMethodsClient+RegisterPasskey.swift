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
import AuthenticationServices

extension MSALNativeCredentialMethodsClient
{
    /// Performs the full passkey registration flow:
    /// 1. Acquires an access token.
    /// 2. Requests WebAuthn creation options from the server (mocked).
    /// 3. Invokes the platform authenticator via ASAuthorization.
    /// 4. Submits the attestation back to the server (mocked).
    /// 5. Returns the registered credential method.
    internal func performRegisterPasskey(
        params: MSALRegisterPasskeyParams
    ) async -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    {
        let correlationId = params.correlationId ?? UUID()

        // Step 1: Acquire access token
        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        switch tokenResult
        {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        // Step 2: Request creation options from the server (mock)
        let creationOptions = requestCreationOptions(displayName: params.displayName)

        // Step 3: Invoke platform authenticator
        let handler = MSALPasskeyAuthorizationHandler(anchor: params.presentationAnchor)
        let attestation: MSALPasskeyAttestation
        do
        {
            attestation = try await handler.performRegistration(options: creationOptions)
        }
        catch
        {
            let credError = MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Passkey creation was cancelled or failed.",
                correlationId: correlationId,
                underlyingError: error
            )
            return .failure(credError)
        }

        // Step 4: Submit attestation to server (mock)
        return submitAttestation(attestation, correlationId: correlationId)
    }

    // MARK: - Private Helpers

    /// Requests WebAuthn creation options from the server.
    /// In production, this would be a POST to the credential management API.
    private func requestCreationOptions(displayName: String?) -> MSALPasskeyCreationOptions
    {
        var challengeBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, challengeBytes.count, &challengeBytes)

        return MSALPasskeyCreationOptions(
            challenge: Data(challengeBytes),
            userId: Data(UUID().uuidString.utf8),
            userName: displayName ?? "user",
            relyingPartyIdentifier: "login.microsoft.com"
        )
    }

    /// Submits the attestation to the server for validation.
    /// In production, this would POST the attestation and receive the registered credential.
    private func submitAttestation(
        _ attestation: MSALPasskeyAttestation,
        correlationId: UUID
    ) -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    {
        let credentialIdString = attestation.credentialId.base64EncodedString()
        let method = MSALPasskeyCredentialMethod(
            id: "passkey-\(UUID().uuidString.prefix(8))",
            displayName: "Passkey (\(String(credentialIdString.prefix(8)))...)",
            createdAt: Date(),
            credentialID: credentialIdString,
            aaguid: nil
        )
        mockCredentialMethods.append(method)
        return .success(.completed(method))
    }

    /// Async wrapper around the token acquisition callback.
    private func acquireTokenAsync(
        correlationId: UUID
    ) async -> Result<String, MSALNativeCredentialManagementError>
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
                            message: "Failed to acquire access token for passkey registration.",
                            correlationId: correlationId,
                            underlyingError: tokenError
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    guard let accessToken = accessToken else
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Token provider returned nil access token.",
                            correlationId: correlationId
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    continuation.resume(returning: .success(accessToken))
                }
            }
        }
    }
}
