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

import Foundation

/// Registers MFA accounts and retrieves and responds to pending sign-in requests.
public final class MSALNativeAuthMfaSdkManager: Sendable {
    public init() {}

    // TODO: Replace these temporary local responses with registration and notification service calls.

    /// Activates an account using decoded QR text and returns its registration details.
    /// Throws if activation cannot be completed. The QR payload is not included in the result.
    public func activateMfaAccount(
        registrationParameters: MSALNativeAuthMfaSdkRegistrationParameters
    ) async throws -> MSALNativeAuthMfaSdkRegistrationResult {
        MSALNativeAuthMfaSdkRegistrationResult(registrationId: UUID().uuidString, accountName: "Example account")
    }

    /// Adds an account using its manually entered name and secret, without QR activation.
    /// Returns registration details or throws if the account cannot be added.
    /// The secret must not be logged and is never included in the returned registration details.
    public func addThirdPartyAccount(
        registrationParameters: MSALNativeAuthMfaSdkManualRegistrationParameters
    ) async throws -> MSALNativeAuthMfaSdkRegistrationResult {
        MSALNativeAuthMfaSdkRegistrationResult(
            registrationId: UUID().uuidString,
            accountName: registrationParameters.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Retrieves pending sign-in requests. An empty array means there are no pending requests.
    /// Throws if the requests cannot be retrieved.
    public func pullPendingNotificationsAsync() async throws -> [MSALNativeAuthMfaSdkAuthSession] {
        [
            MSALNativeAuthMfaSdkAuthSession(
                guid: "1E379F3D-B2C8-4D3F-9741-1E02328C8965",
                accountName: "Example account",
                username: "user@example.com",
                firstEntropyNumber: "42"
            )
        ]
    }

    /// Submits the entered number to approve the specified sign-in request.
    /// Throws if the response cannot be completed. Callers must not log the entered number.
    public func approve(
        authSession: MSALNativeAuthMfaSdkAuthSession,
        number: String
    ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult {
        MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult(wasApproved: true)
    }

    /// Denies the specified sign-in request, or throws if the response cannot be completed.
    public func deny(
        authSession: MSALNativeAuthMfaSdkAuthSession
    ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult {
        MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult(wasApproved: false)
    }
}
