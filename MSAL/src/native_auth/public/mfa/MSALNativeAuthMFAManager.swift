// ------------------------------------------------------------------------------
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
// ------------------------------------------------------------------------------

import Foundation

/// Proposed API for registering MFA accounts and responding to pending sign-in requests.
///
/// API review only: every operation currently throws `MSALNativeAuthMFAError` with `isGeneralError == true`
/// and "MFA API is not implemented." No networking, storage, token acquisition or push handling occurs.
/// Method documentation describes the intended contract, not implemented behavior.
public final class MSALNativeAuthMFAManager: Sendable {
    /// Use one shared manager for the hosting app's enrollment, APNs callbacks and session operations.
    /// Enrollment derives the device hardware identifier internally; no device name is supplied by the host.
    public init() {}

    /// Supplies the latest APNs token and updates the push destination of existing MFA registrations.
    /// Call for every successful APNs registration callback, including when no accounts have been added yet.
    /// Supply raw token bytes and the environment matching the hosting app's signed entitlement.
    /// This does not request notification permission or register a new account.
    /// Throws if the update cannot be completed. Callers must not log the token.
    /// Persists the latest token in SDK-owned Keychain storage and reconciles existing service registrations.
    /// Uses only the V2 token-change protocol; accounts already using this token require no service call.
    /// Missing registration data produces a general error; a missing secret produces a storage error.
    /// No legacy token-change fallback is attempted. An empty token produces an invalid-registration error.
    /// Forward validation pushes through `handlePushNotification`; each account waits up to 120 seconds
    /// after its start response. Accounts are updated sequentially.
    /// A newer token supplied during an update produces an operation-not-allowed error; completed accounts are not rolled back.
    /// After active work finishes, call again with the latest token to reconcile remaining accounts.
    public func updatePushRegistration(
        deviceToken: Data,
        apnsEnvironment: MSALNativeAuthMFAAPNsEnvironment
    ) async throws {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Registers an account using decoded QR text or a manually entered activation code and URL.
    /// Throws if registration cannot be completed. QR payloads, secret keys, and device tokens are not included in the result.
    /// Both input forms require a persisted APNs token; missing state produces an item-not-found error.
    /// Await `updatePushRegistration` with the latest token before starting enrollment.
    /// Produces a general error if the device hardware identifier cannot be obtained.
    /// Forward validation pushes through `handlePushNotification`, even while activation is in flight.
    /// Returns only after service confirmation and local persistence. Cancellation does not undo service calls.
    public func registerAuthMethod(
        registrationParameters: MSALNativeAuthMFARegistrationParameters
    ) async throws -> MSALNativeAuthMFARegistrationResult {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Retrieves pending sign-in requests. An empty array means there are no pending requests.
    /// Returns sessions deduplicated by GUID. No accounts means no service calls.
    /// Throws if any account check or fetch fails, rather than returning partial results.
    public func pullPendingNotifications() async throws -> [MSALNativeAuthMFAAuthSession] {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Approves the specified sign-in request. Supply the entered number when `requiresNumberMatching` is true,
    /// or an empty string for ordinary approval. The service validates the number; the SDK does not disclose it.
    /// Number matching accepts 1-10 ASCII digits. Pass the original session object returned by this manager.
    /// Unsupported approval policies produce an auth-notification error; denial remains available before submission.
    /// Throws if the response cannot be completed. Callers must not log the entered number.
    /// Once submission starts, the session is replay-blocked even if the operation fails or is cancelled.
    /// Do not retry the decision or switch to denial after submission.
    public func approve(
        authSession: MSALNativeAuthMFAAuthSession,
        number: String
    ) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Denies the specified sign-in request, or throws if the response cannot be completed.
    /// Pass the original session object returned by this manager. No number is required.
    /// Success returns `wasApproved = false`; failures throw rather than returning a false success result.
    /// Once submission starts, failure or cancellation does not permit retry or switching to approval.
    public func deny(
        authSession: MSALNativeAuthMFAAuthSession
    ) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Reads registered account display metadata from SDK-owned Keychain storage.
    /// Returns an empty array when none are stored; pending enrollments are excluded.
    /// Does not contact SAS or detect server-side removal. Storage failures throw.
    public func registeredAuthMethods() async throws -> [MSALNativeAuthMFARegistrationResult] {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Deletes the registered authentication method through Microsoft Graph, then removes its local credentials and sessions.
    /// Currently supports commercial-cloud registrations only.
    /// The shared provider acquires a delegated Graph token for the supplied account, authority, scopes and claims.
    /// The SDK requests essential `ngcmfa`; Graph enforces recent strong authentication.
    /// Native and web-based providers return the same feature-neutral token result.
    /// The SDK checks the returned tenant and object ID, not the login hint, before sending the deletion.
    /// HTTP 204 or 404 permits local removal; other failures retain the local registration and throw.
    /// A transport failure or cancellation can leave the remote outcome unknown; retrying deletion reconciles a 404.
    /// Local persistence may fail after remote success. Retry deletion to finish cleanup.
    /// Token acquisition may present UI; the provider must marshal UI work to the main actor. Never log token requests/results.
    public func deleteAuthMethod(
        registrationId: String,
        tokenProvider: any MSALTokenProvider
    ) async throws {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Handles service notification fields forwarded by the host's APNs callback.
    /// Pass string-valued fields from the MFA notification payload. Do not log the payload.
    /// Forward `url` unchanged: supported values include a legacy hostname or a trusted MAC service URL
    /// with its routing query, with or without the HTTPS scheme.
    /// Validation notifications return no sessions; authentication notifications return trusted session metadata.
    /// Unrelated notification types return an empty array. Malformed MFA notifications throw.
    /// Duplicate active sessions may reuse the same object; submitted or completed sessions produce an auth-notification error.
    public func handlePushNotification(payload: [String: String]) async throws -> [MSALNativeAuthMFAAuthSession] {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }
}
