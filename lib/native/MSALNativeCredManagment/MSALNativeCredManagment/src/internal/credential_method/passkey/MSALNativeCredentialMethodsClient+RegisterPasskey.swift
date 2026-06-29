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
import AuthenticationServices
@_implementationOnly import MSAL_Private

extension MSALNativeCredentialMethodsClient
{
    /// Performs the full passkey registration flow:
    /// 1. Acquires an access token.
    /// 2. Calls beginEnrollment to get WebAuthn creation options from the server.
    /// 3. Invokes the platform authenticator via ASAuthorization.
    /// 4. Calls activateEnrollment with the attestation.
    /// 5. Returns the registered credential method.
    internal func performRegisterPasskey(
        params: MSALRegisterPasskeyParams
    ) async -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    {
        let correlationId = params.correlationId ?? UUID()

        MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "performRegisterPasskey: starting")

        // Step 1: Acquire access token
        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        guard case .success(let accessToken) = tokenResult else
        {
            return .failure({ if case .failure(let e) = tokenResult { return e }; fatalError("Unreachable") }())
        }

        // Step 2: Begin enrollment to get creation options from server
        switch getAPIClient()
        {
        case .failure(let error):
            return .failure(error)
        case .success(let client):
            let enrollResult = await client.beginEnrollment(
                params: PasskeyEnrollmentParams(),
                accessToken: accessToken,
                correlationId: correlationId
            )

            guard case .success(let response) = enrollResult else
        {
            if case .failure(let resultError) = enrollResult { return .failure(resultError) }
            fatalError("Unreachable")
        }

            // Expect passkey creation options from the server
            guard case .passkeyCreationRequired(let passkeyInfo) = response else
            {
                if case .completed(let method) = response
                {
                    return .success(.completed(method))
                }
                return .failure(MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: "Server did not return passkey creation options.",
                    correlationId: correlationId
                ))
            }

            // Parse creation options from server response
            let creationOptions = parseCreationOptions(from: passkeyInfo.publicKey)

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

            // Step 4: Submit attestation to server via activate
            let activateResult = await client.activateEnrollment(
                params: PasskeyActivationParams(
                    continuationToken: passkeyInfo.continuationToken,
                    displayName: params.displayName ?? "Passkey",
                    credentialId: attestation.credentialId,
                    attestationObject: attestation.rawAttestationObject,
                    clientDataJSON: attestation.rawClientDataJSON
                ),
                accessToken: accessToken,
                correlationId: correlationId
            )

            switch activateResult
            {
            case .success(let method):
                MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "performRegisterPasskey: completed")
                return .success(.completed(method))
            case .failure(let error):
                return .failure(error)
            }
        }
    }

    // MARK: - Private Helpers

    /// Parses the server-provided publicKey object into local creation options.
    private func parseCreationOptions(from publicKeyDict: [String: Any]) -> MSALPasskeyCreationOptions
    {
        let challenge: Data
        if let challengeString = publicKeyDict["challenge"] as? String,
           let decoded = Self.decodeBase64URL(challengeString)
        {
            challenge = decoded
        }
        else
        {
            var bytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            challenge = Data(bytes)
        }

        let userId: Data
        if let userDict = publicKeyDict["user"] as? [String: Any],
           let idString = userDict["id"] as? String,
           let decoded = Self.decodeBase64URL(idString)
        {
            userId = decoded
        }
        else
        {
            userId = Data(UUID().uuidString.utf8)
        }

        let userName: String
        if let userDict = publicKeyDict["user"] as? [String: Any],
           let name = userDict["name"] as? String
        {
            userName = name
        }
        else
        {
            userName = "user"
        }

        let rpId: String
        if let rpDict = publicKeyDict["rp"] as? [String: Any],
           let id = rpDict["id"] as? String
        {
            rpId = id
        }
        else
        {
            rpId = "login.microsoft.com"
        }

        return MSALPasskeyCreationOptions(
            challenge: challenge,
            userId: userId,
            userName: userName,
            relyingPartyIdentifier: rpId
        )
    }

    /// Decodes a base64url string (WebAuthn/ESTS encoding, no padding, `-`/`_` alphabet),
    /// falling back to standard base64 for authorities that return padded base64.
    private static func decodeBase64URL(_ string: String) -> Data?
    {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0
        {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64) ?? Data(base64Encoded: string)
    }
}
