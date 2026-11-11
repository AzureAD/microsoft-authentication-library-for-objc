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
///
/// All operations use the standalone `MSALNativeAuthMFAError` and its seven action-oriented classifiers.
/// Swift `CancellationError` propagates separately. Neither failure nor cancellation implies rollback or safe replay.
/// Migrating from the earlier proposal: replace `approve`/`deny` with `respond`, inspect `MSALNativeAuthMFADecision`
/// instead of `wasApproved`, and catch `MSALNativeAuthMFAError` directly rather than as a Native Auth error.
public final class MSALNativeAuthMFAManager: Sendable {
    /// Use one shared manager for the hosting app's enrollment, APNs callbacks and session operations.
    /// Enrollment derives device metadata internally; no device name is supplied by the host.
    public init() {}

    /// Supplies the latest APNs token and updates the push destination of existing MFA registrations.
    /// Call for every successful APNs registration callback, including when no accounts have been added yet.
    /// Supply raw token bytes and the environment matching the hosting app's signed entitlement.
    /// This does not request notification permission or register a new account.
    /// Persists the latest token; with no accounts needing an update, returns without a service call.
    /// Reconciles existing registrations sequentially using V2 validation without reenrolling accounts.
    /// Forward validation pushes through `handlePushNotification`, including while this operation is pending.
    /// Success requires validation and local persistence for every account needing an update.
    /// Failure or cancellation stops remaining work without rolling back completed accounts; the token may already be stored.
    /// A later call can reconcile accounts still using an older token. Do not log the token.
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
    /// Both input forms require a persisted APNs token; its absence produces `isPushTokenMissing`.
    /// Await `updatePushRegistration` with the latest token before starting enrollment.
    /// Validates and normalizes activation input, rejecting unsupported or unsafe input.
    /// Forward validation pushes through `handlePushNotification`, even while activation is in flight.
    /// Returns only after service confirmation and local persistence. Cancellation does not undo service calls.
    /// Validates the expected account and retains uncertain-operation state to prevent unsafe replay after failure.
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
    /// The host owns presentation and passes the original returned session to `respond`.
    /// Unsupported approval policy does not hide a session; denial remains available before submission.
    public func pullPendingNotifications() async throws -> [MSALNativeAuthMFAAuthSession] {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Submits an explicit approval or denial for the original session object returned by this manager.
    /// Rejects already-submitted or completed sessions; neither `guid` nor `registrationId` can reconstruct a session.
    /// For number matching, pass `.approve(number:)` with a number in the format required by the service contract.
    /// Missing, empty or malformed required input fails before submission; it never falls back to ordinary approval.
    /// Pass `.approve(number: nil)` only when authoritative policy and backend support permit ordinary approval.
    /// Ordinary approval remains unavailable until the SAS contract supports it; unsupported approval fails before submission.
    /// Pass `.deny` without a number. Approval-only policy restrictions do not prevent denial of an otherwise valid session.
    /// Returns `.approved` or `.denied` only after acknowledgment of that action, not sign-in completion or token issuance.
    /// Wrong numbers, service rejection, transport failure and cancellation throw, never return `.denied` as a fallback.
    /// Persists replay protection before submission. Subsequent failure or cancellation does not permit automatic retry,
    /// switching actions or changing approval mode. Server wrong-number continuation is not assumed.
    /// The expected number is never exposed. Do not log the entered number.
    public func respond(
        authSession: MSALNativeAuthMFAAuthSession,
        action: MSALNativeAuthMFAAction
    ) async throws -> MSALNativeAuthMFADecision {
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
    /// The SDK checks the returned tenant/object ID, authority host, expiry, Bearer scheme and Graph scope before deletion.
    /// A login hint is not identity proof. Tokens are neither parsed nor stored with MFA registrations.
    /// HTTP 204 or 404 permits local removal; other failures retain the local registration and throw.
    /// A transport failure or cancellation can leave the remote outcome unknown; a caller-initiated retry reconciles a 404.
    /// After confirmed remote success, sessions stay invalidated even if cancellation or local persistence failure occurs.
    /// Retrying on the same manager finishes pending local cleanup without another token or Graph request.
    /// Retrieval and decisions remain available while token acquisition is pending. A target decision still submitting
    /// prevents Graph deletion; once DELETE is submitted, decisions for that registration are blocked until deletion finishes.
    /// Conflicting enrollment, token reconciliation or deletion is rejected without automatic retry.
    /// Only the selected method is removed; other registrations, APNs state, replay records and the host OAuth cache remain.
    /// Token acquisition may present UI; the provider must marshal UI work to the main actor. Never log token requests/results.
    public func deleteAuthMethod(
        registrationId: String,
        tokenProvider: any MSALTokenProvider
    ) async throws {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }

    /// Processes Apple's notification `userInfo` unchanged, with no host-side filtering or dictionary conversion.
    /// Pass `notification.request.content.userInfo`, `response.notification.request.content.userInfo`,
    /// or the remote-notification callback's `userInfo`. Never log the payload.
    /// Extracts and validates supported MFA fields and ignores unrelated fields, including nested `aps` content.
    /// Arbitrary values are never stringified. Malformed recognized MFA payloads or mismatched context throw.
    /// Authentication notifications retrieve validated sessions associated with stored registrations.
    /// Successful enrollment/token-update validation returns no sessions and lets the pending initiating operation continue.
    /// Missing or unrelated notification types return no sessions without an MFA service call, unless
    /// input, storage or cancellation checks fail first. Unsupported approval policy still permits denial before submission.
    ///
    /// The host owns presentation options, completion handlers, background-execution requests and expiration handling.
    /// Calling or awaiting this API does not keep the app running or extend iOS background execution time.
    /// Meet system callback deadlines without waiting for user interaction. Cancellation/interruption does not imply
    /// rollback or safe replay. `actionIdentifier` belongs to `UNNotificationResponse`, not `userInfo`.
    /// The host interprets explicit user actions and calls `respond` with the returned session when permitted.
    /// Delivery or a notification tap alone is not approval; this handler neither presents UI nor submits a decision.
    public func handlePushNotification(payload: [AnyHashable: Any]) async throws -> [MSALNativeAuthMFAAuthSession] {
        throw MSALNativeAuthMFAError(
            type: .generalError, errorDescription: "MFA API is not implemented.", correlationId: UUID()
        )
    }
}
