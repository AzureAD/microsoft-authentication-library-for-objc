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
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Internal Types

/// WebAuthn creation options returned by the server for passkey registration.
internal struct MSALPasskeyCreationOptions
{
    let challenge: Data
    let userId: Data
    let userName: String
    let relyingPartyIdentifier: String
}

/// Attestation data from the platform authenticator after passkey creation.
internal struct MSALPasskeyAttestation
{
    let credentialId: Data
    let rawAttestationObject: Data
    let rawClientDataJSON: Data
}

// MARK: - Internal Authorization Handler

/// Handles the ASAuthorization flow for passkey creation.
///
/// This class encapsulates all platform authenticator interactions so that
/// developers never need to work with `ASAuthorizationController` directly.
internal class MSALPasskeyAuthorizationHandler: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private let anchor: ASPresentationAnchor
    private var continuation: CheckedContinuation<MSALPasskeyAttestation, Error>?

    init(anchor: ASPresentationAnchor)
    {
        self.anchor = anchor
        super.init()
    }

    /// Performs the platform passkey creation and returns the attestation.
    func performRegistration(
        options: MSALPasskeyCreationOptions
    ) async throws -> MSALPasskeyAttestation
    {
        return try await withCheckedThrowingContinuation
        { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.relyingPartyIdentifier
            )

            let request = provider.createCredentialRegistrationRequest(
                challenge: options.challenge,
                name: options.userName,
                userID: options.userId
            )

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            DispatchQueue.main.async
            {
                controller.performRequests()
            }
        }
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor
    {
        return anchor
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    )
    {
        guard let credential = authorization.credential
            as? ASAuthorizationPlatformPublicKeyCredentialRegistration
        else
        {
            let error = NSError(
                domain: "MSALPasskeyError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected credential type returned."]
            )
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }

        let attestation = MSALPasskeyAttestation(
            credentialId: credential.credentialID,
            rawAttestationObject: credential.rawAttestationObject ?? Data(),
            rawClientDataJSON: credential.rawClientDataJSON
        )
        continuation?.resume(returning: attestation)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    )
    {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
