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

/// Registers MFA accounts and responds to pending sign-in requests using the configured SAS client.
///
/// SDK-originated failures use `MSALNativeAuthMFAError` and its six action-oriented classifiers.
/// Token-provider errors propagate unchanged for the host to handle; they are not wrapped, classified or logged by MFA.
/// Swift `CancellationError` propagates separately. Neither failure nor cancellation implies rollback or safe replay.
/// Migrating from the earlier proposal: replace `approve`/`deny` with `respond`, inspect `MSALNativeAuthMFADecision`
/// instead of `wasApproved`, and catch `MSALNativeAuthMFAError` directly rather than as a Native Auth error.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
public final class MSALNativeAuthMFAManager: Sendable {
    private let sasClient: any MSALNativeAuthSASClient
    private let service: MSALNativeAuthMFAService

    /// Use one shared manager for the hosting app's enrollment, APNs callbacks and session operations.
    /// Enrollment derives device metadata internally; no device name is supplied by the host.
    public init() {
        let transport = MSALNativeAuthMFATransport()
        sasClient = MSALNativeAuthSASLegacyClient(transport: transport)
        service = MSALNativeAuthMFAService(
            sasClient: sasClient, graphClient: MSALNativeAuthMFAGraphClient(transport: transport),
            storage: MSALNativeAuthMFAKeychain()
        )
    }

    internal init(
        sasClient: any MSALNativeAuthSASClient,
        transport: any MSALNativeAuthMFATransporting,
        storage: any MSALNativeAuthMFAStoring,
        deviceNameProvider: (@Sendable () -> String?)? = nil
    ) {
        self.sasClient = sasClient
        service = MSALNativeAuthMFAService(
            sasClient: sasClient, graphClient: MSALNativeAuthMFAGraphClient(transport: transport),
            storage: storage, deviceNameProvider: deviceNameProvider
        )
    }

    /// Supplies the latest APNs token and updates the push destination of existing MFA registrations.
    /// Call for every successful APNs registration callback, including when no accounts have been added yet.
    /// Supply raw token bytes and the environment matching the hosting app's signed entitlement.
    /// This does not request notification permission or register a new account.
    /// Persists the latest token; with no accounts needing an update, returns without a service call.
    /// Updates existing registrations sequentially using V2 validation without reenrolling accounts.
    /// Forward validation pushes through `handlePushNotification`, including while this operation is pending.
    /// Success requires validation and local persistence for every account needing an update.
    /// Failure or cancellation stops remaining work without rolling back completed accounts; the token may already be stored.
    /// Subsequent calls can update accounts not yet attempted or resume updates where the service contract explicitly permits it.
    /// An uncertain submitted update requires service-defined recovery; repeating the call does not authorize replay.
    /// Pending token-change attempts are persisted per registration and block replay across process restarts.
    /// Confirmed completion is persisted by the validation callback even if the initiating task was cancelled.
    /// A locally older token does not prove that the server update failed. Recovery after a lost validation push,
    /// lost response, partial write or process restart remains a backend-contract dependency, not a guaranteed continuation.
    /// Do not log the token.
    public func updatePushRegistration(
        deviceToken: Data,
        apnsEnvironment: MSALNativeAuthMFAAPNsEnvironment
    ) async throws {
        try await perform { try await self.service.update(token: deviceToken, environment: apnsEnvironment) }
    }

    /// Registers an account using decoded QR text or a manually entered activation code and URL.
    /// Throws if registration cannot be completed. QR payloads, secret keys, and device tokens are not included in the result.
    /// Both input forms require a persisted APNs token; its absence produces `isPushTokenMissing`.
    /// Await `updatePushRegistration` with the latest token before starting enrollment.
    /// Validates and normalizes activation input, rejecting unsupported or unsafe input.
    /// Forward validation pushes through `handlePushNotification`, even while activation is in flight.
    /// This legacy POC persists pending enrollment context while activation and push validation complete.
    /// Validates the expected account, then confirms with the service before saving the registration locally.
    /// Returns only after confirmation and local persistence succeed.
    /// A lost confirmation response or local save failure throws without returning a registration;
    /// the service may already have activated the method. Cancellation does not undo service calls.
    /// No automatic retry, status reconciliation or compensating deletion is provided.
    /// Retrying the same activation input can resume a saved activation/validation; an unresolved activation or
    /// confirmation outcome blocks replay. A fresh activation input is not recovery of the previous attempt.
    /// A different activation input cannot replace a pending enrollment.
    public func registerAuthMethod(
        registrationParameters: MSALNativeAuthMFARegistrationParameters
    ) async throws -> MSALNativeAuthMFARegistrationResult {
        try await perform { try await self.service.register(registrationParameters) }
    }

    /// Retrieves pending sign-in requests. An empty array means there are no pending requests.
    /// Returns sessions deduplicated by GUID. No accounts means no service calls.
    /// Throws if any account check or fetch fails, rather than returning partial results.
    /// The host owns presentation and passes the original returned session to `respond`.
    /// Every returned session supports both approval and denial. Unsupported policy throws rather than returning
    /// a deny-only session or partial results. The service still validates each submitted action.
    public func pullPendingNotifications() async throws -> [MSALNativeAuthMFAAuthSession] {
        try await perform { try await self.service.pull() }
    }

    /// Submits an explicit approval or denial for the original session object returned by this manager.
    /// Rejects already-submitted or completed sessions; neither `guid` nor `registrationId` can reconstruct a session.
    /// For number matching, pass `.approve(number:)` with a number in the format required by the service contract.
    /// Missing, empty or malformed required input fails before submission; it never falls back to ordinary approval.
    /// Pass `.approve(number: nil)` only when authoritative policy and backend support permit ordinary approval.
    /// Legacy SAS ordinary approval is used only for a validated session that does not require number matching.
    /// Pass `.deny` without a number. Every returned session supports both actions, subject to service and session validation.
    /// Unsupported policy detected on revalidation fails before submission rather than permitting a deny-only fallback.
    /// Returns `.approved` or `.denied` only after acknowledgment of that action, not sign-in completion or token issuance.
    /// Wrong numbers, service rejection, transport failure and cancellation throw, never return `.denied` as a fallback.
    /// Persists replay protection before submission. Subsequent failure or cancellation does not permit automatic retry,
    /// switching actions or changing approval mode. Server wrong-number continuation is not assumed.
    /// The expected number is never exposed. Do not log the entered number.
    public func respond(
        authSession: MSALNativeAuthMFAAuthSession,
        action: MSALNativeAuthMFAAction
    ) async throws -> MSALNativeAuthMFADecision {
        try await perform { try await self.service.respond(authSession, action: action) }
    }

    /// Reads registered account display metadata from SDK-owned Keychain storage.
    /// Returns an empty array when none are stored; pending enrollments are excluded.
    /// Does not contact SAS or detect server-side removal. Storage failures throw.
    public func registeredAuthMethods() async throws -> [MSALNativeAuthMFARegistrationResult] {
        try await perform { try await self.service.registrations() }
    }

    /// Deletes the registered authentication method through Microsoft Graph, then removes its local credentials and sessions.
    /// Currently supports commercial-cloud registrations only.
    /// The shared provider acquires a delegated Graph token for the supplied account, authority, scopes and claims.
    /// If acquisition throws, propagate that exact error without wrapping, classifying or logging it, and do not send DELETE.
    /// The host handles its provider's errors, including explicit sign-in cancellation, at this call site.
    /// Only SDK-detected failures, including validation of a successfully returned result, use `MSALNativeAuthMFAError`.
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
        try await perform { try await self.service.delete(registrationId: registrationId, tokenProvider: tokenProvider) }
    }

    /// Processes Apple's notification `userInfo` unchanged, with no host-side filtering or dictionary conversion.
    /// Pass `notification.request.content.userInfo`, `response.notification.request.content.userInfo`,
    /// or the remote-notification callback's `userInfo`. Never log the payload.
    /// Extracts and validates supported MFA fields and ignores unrelated fields, including nested `aps` content.
    /// Arbitrary values are never stringified. Malformed recognized MFA payloads or mismatched context throw.
    /// Leave `isolation` at its default to process the raw payload on the caller's actor.
    /// Authentication notifications retrieve validated sessions associated with stored registrations.
    /// Successful enrollment/token-update validation returns no sessions and lets the pending initiating operation continue.
    /// Missing or unrelated notification types return no sessions without an MFA service call, unless
    /// input, storage or cancellation checks fail first. Every returned session supports both approval and denial.
    /// Unsupported policy throws rather than returning a deny-only session; service validation can still reject either action.
    ///
    /// The host owns presentation options, completion handlers, background-execution requests and expiration handling.
    /// Calling or awaiting this API does not keep the app running or extend iOS background execution time.
    /// Meet system callback deadlines without waiting for user interaction. Cancellation/interruption does not imply
    /// rollback or safe replay. `actionIdentifier` belongs to `UNNotificationResponse`, not `userInfo`.
    /// The host interprets explicit user actions and calls `respond` with the returned session when permitted.
    /// Delivery or a notification tap alone is not approval; this handler neither presents UI nor submits a decision.
    public func handlePushNotification(
        payload: [AnyHashable: Any],
        isolation: isolated (any Actor)? = #isolation
    ) async throws -> [MSALNativeAuthMFAAuthSession] {
        let notification = Result { try sasClient.notification(payload) }
        return try await perform { try await self.service.notification(notification.get()) }
    }

    private func perform<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async throws -> Value {
        let correlationId = UUID()
        return try await MSALNativeAuthMFARequestContext.$correlationId.withValue(correlationId) {
            do {
                guard sasClient.isImplemented else { throw MSALNativeAuthMFAFailure.sasClientUnavailable }
                return try await operation()
            } catch let error as MSALNativeAuthMFAProviderFailure {
                throw error.underlying
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw MSALNativeAuthMFAError.from(error, correlationId: correlationId)
            }
        }
    }
}
