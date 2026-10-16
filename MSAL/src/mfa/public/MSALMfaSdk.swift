//------------------------------------------------------------------------------
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
//
//------------------------------------------------------------------------------

#if MSAL_MFA_POC

/// QR input for the experimental mock-only MFA interface. Not a production registration API.
public final class MSALMfaSdkRegistrationParameters: Sendable
{
    /// Opaque QR text supplied by the caller. Phase 1 does not parse, validate, log, or persist it.
    public let qrCode: String

    /// Creates parameters without requiring sign-in, an account, a device token, or a camera.
    public init(qrCode: String)
    {
        self.qrCode = qrCode
    }
}

/// A mock registration receipt. No account or device has actually been enrolled.
public final class MSALMfaSdkRegistrationResult: Sendable
{
    public let isMock = true
    public let registrationId = "mock-registration"

    internal init() {}
}

/// A deterministic mock challenge, not a server-issued authentication session.
public final class MSALMfaSdkAuthSession: Sendable
{
    public let isMock = true
    public let guid = "mock-session"

    /// The sample displays 42 as its simulated sign-in number. The SDK does not verify number input.
    public let firstEntropyNumber = "42"

    internal init() {}
}

/// A simulated local decision. It does not authorize or deny any real sign-in.
public final class MSALMfaSdkPendingAuthSessionCompletionResult: Sendable
{
    public let isMock = true
    public let wasApproved: Bool

    internal init(wasApproved: Bool)
    {
        self.wasApproved = wasApproved
    }
}

/// Headless Phase 1 interface. Every async operation returns one fixed mock result without suspension.
///
/// Inputs are intentionally ignored. There is no networking, registration, token acquisition, storage,
/// cryptography, push handling, UI, or session lifecycle enforcement. Calls are stateless and repeatable,
/// including calls made out of order. These signatures are experimental, not a production API contract.
public final class MSALMfaSdkManager: Sendable
{
    public init() {}

    /// Returns a mock receipt for any QR input, including empty or malformed text.
    /// The parameters are not retained; no account-sign-in registration overload is provided.
    public func activateMfaAccount(
        registrationParameters: MSALMfaSdkRegistrationParameters
    ) async -> MSALMfaSdkRegistrationResult
    {
        MSALMfaSdkRegistrationResult()
    }

    /// Returns one fixed mock challenge without polling a server or requiring prior activation.
    public func pullPendingNotificationsAsync() async -> [MSALMfaSdkAuthSession]
    {
        [MSALMfaSdkAuthSession()]
    }

    /// Returns a mock approval. Neither the session nor the number is validated or submitted anywhere.
    public func approve(
        authSession: MSALMfaSdkAuthSession,
        number: String
    ) async -> MSALMfaSdkPendingAuthSessionCompletionResult
    {
        MSALMfaSdkPendingAuthSessionCompletionResult(wasApproved: true)
    }

    /// Returns a mock denial without modifying the session or contacting a server.
    public func deny(
        authSession: MSALMfaSdkAuthSession
    ) async -> MSALMfaSdkPendingAuthSessionCompletionResult
    {
        MSALMfaSdkPendingAuthSessionCompletionResult(wasApproved: false)
    }
}

#endif
