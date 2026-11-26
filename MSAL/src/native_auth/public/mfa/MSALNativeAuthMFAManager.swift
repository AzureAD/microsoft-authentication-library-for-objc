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

/// Registers MFA accounts and retrieves and responds to pending sign-in requests.
/// SDK failures use `MSALNativeAuthMFAError`. Token-provider errors and Swift `CancellationError` propagate unchanged.
/// Each operation carries a correlation ID through its token request and HTTP requests.
public final class MSALNativeAuthMFAManager: Sendable {
    private let service: MSALNativeAuthMFAService

    /// Use one shared manager for the hosting app's enrollment, APNs callbacks and session operations.
    /// Enrollment derives the device hardware identifier internally; no device name is supplied by the host.
    public init() {
        service = MSALNativeAuthMFAService(
            transport: MSALNativeAuthMFATransport(),
            storage: MSALNativeAuthMFAKeychain()
        )
    }

    internal init(
        transport: any MSALNativeAuthMFATransporting,
        storage: any MSALNativeAuthMFAStoring,
        deviceNameProvider: (@Sendable () -> String?)? = nil
    ) {
        service = MSALNativeAuthMFAService(
            transport: transport, storage: storage, deviceNameProvider: deviceNameProvider
        )
    }

    /// Supplies the latest APNs token and updates the push destination of existing MFA registrations.
    /// Call for every successful APNs registration callback, including when no accounts have been added yet.
    /// Supply raw token bytes and the environment matching the hosting app's signed entitlement.
    /// This does not request notification permission or register a new account.
    /// Throws if the update cannot be completed. Callers must not log the token.
    /// Persists the latest token in SDK-owned Keychain storage and reconciles existing service registrations.
    /// Uses only the V2 token-change protocol; accounts already using this token require no service call.
    /// Missing registration data, invalid tokens and storage failures produce a general error.
    /// No legacy token-change fallback is attempted.
    /// Forward validation pushes through `handlePushNotification`; each account waits up to 120 seconds
    /// after its start response. Accounts are updated sequentially.
    /// A newer token supplied during an update produces a general error; completed accounts are not rolled back.
    /// After active work finishes, call again with the latest token to reconcile remaining accounts.
    public func updatePushRegistration(
        deviceToken: Data,
        apnsEnvironment: MSALNativeAuthMFAAPNsEnvironment
    ) async throws {
        try await perform { try await self.service.update(token: deviceToken, environment: apnsEnvironment) }
    }

    /// Registers an account using decoded QR text or a manually entered activation code and URL.
    /// Throws if registration cannot be completed. QR payloads, secret keys, and device tokens are not included in the result.
    /// Both input forms require a persisted APNs token; missing state produces `isPushTokenMissing`.
    /// Await `updatePushRegistration` with the latest token before starting enrollment.
    /// Produces a general error if the device hardware identifier cannot be obtained.
    /// Forward validation pushes through `handlePushNotification`, even while activation is in flight.
    /// Returns only after service confirmation and local persistence. Cancellation does not undo service calls.
    public func registerAuthMethod(
        registrationParameters: MSALNativeAuthMFARegistrationParameters
    ) async throws -> MSALNativeAuthMFARegistrationResult {
        try await perform { try await self.service.register(registrationParameters.validatedActivation()) }
    }

    /// Retrieves pending sign-in requests. An empty array means there are no pending requests.
    /// Returns sessions deduplicated by GUID. No accounts means no service calls.
    /// Throws if any account check or fetch fails, rather than returning partial results.
    /// Unsupported policy fails during retrieval; every returned session supports both approval and denial.
    public func pullPendingNotifications() async throws -> [MSALNativeAuthMFAAuthSession] {
        try await perform { try await self.service.pull() }
    }

    /// Submits an explicit approval or denial for the original session object returned by this manager.
    /// Supply `.approve(number:)` with 1-10 ASCII digits when `requiresNumberMatching` is true.
    /// For ordinary approval the number is ignored; `.deny` requires no number.
    /// Missing or malformed required numbers produce `isInvalidCode` before submission and permit correction.
    /// Returns only the service-acknowledged decision, not completed sign-in or token issuance.
    /// Once submission starts, failures and cancellation do not permit replay or switching actions.
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
    /// Provider errors propagate unchanged without wrapping, classifying or logging, and no DELETE is sent.
    /// The SDK requests essential `ngcmfa`; Graph enforces recent strong authentication.
    /// Native and web-based providers return the same feature-neutral token result.
    /// The SDK checks the returned tenant and object ID, not the login hint, before sending the deletion.
    /// HTTP 204 or 404 permits local removal; other failures retain the local registration and throw.
    /// A transport failure or cancellation can leave the remote outcome unknown; retrying deletion reconciles a 404.
    /// Local persistence may fail after remote success. Retry deletion to finish cleanup.
    /// On the same manager, confirmed remote success retries only local cleanup, without acquiring a token or resending DELETE.
    /// Retrieval and decisions remain available during token acquisition. A submitting target decision prevents
    /// DELETE; once DELETE is submitted, target decisions remain blocked until completion or reconciliation.
    /// Token acquisition may present UI; the provider must marshal UI work to the main actor. Never log token requests/results.
    public func deleteAuthMethod(
        registrationId: String,
        tokenProvider: any MSALTokenProvider
    ) async throws {
        try await perform { try await self.service.delete(registrationId: registrationId, tokenProvider: tokenProvider) }
    }

    /// Handles Apple's raw notification userInfo without host filtering or dictionary conversion.
    /// Extracts recognized string fields and ignores unrelated values, including nested aps. Never stringifies values.
    /// Forward `url` unchanged: supported values include a legacy hostname or a trusted MAC service URL
    /// with its routing query, with or without the HTTPS scheme.
    /// Validation notifications return no sessions; authentication notifications return trusted session metadata.
    /// Unrelated notification types return an empty array. Malformed MFA notifications throw.
    /// Duplicate active sessions may reuse the same object; submitted or completed sessions are replay-blocked.
    public func handlePushNotification(payload: [AnyHashable: Any]) async throws -> [MSALNativeAuthMFAAuthSession] {
        let fields = Result { try MSALNativeAuthMFANotification.fields(payload) }
        return try await perform { try await self.service.notification(fields.get()) }
    }

    private func perform<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async throws -> Value {
        let correlationId = UUID()
        return try await MSALNativeAuthMFARequestContext.$correlationId.withValue(correlationId) {
            do {
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
