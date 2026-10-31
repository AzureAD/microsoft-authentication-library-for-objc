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
public final class MSALNativeAuthMFAManager: Sendable {
    private let service: MSALNativeAuthMFAService

    /// Use one shared manager for the hosting app's enrollment, APNs callbacks and session operations.
    /// Enrollment derives the device hardware identifier internally; no device name is supplied by the host.
    public convenience init() {
        self.init(enableRegistrationDeletion: false)
    }

    /// `enableRegistrationDeletion` opts in to Graph-backed registration deletion; other operations are unchanged.
    public init(enableRegistrationDeletion: Bool) {
        service = MSALNativeAuthMFAService(
            transport: MSALNativeAuthMFATransport(),
            storage: MSALNativeAuthMFAKeychain(),
            enableRegistrationDeletion: enableRegistrationDeletion
        )
    }

    internal init(
        transport: any MSALNativeAuthMFATransporting,
        storage: any MSALNativeAuthMFAStoring,
        deviceNameProvider: (@Sendable () -> String?)? = nil,
        enableRegistrationDeletion: Bool = false
    ) {
        service = MSALNativeAuthMFAService(
            transport: transport, storage: storage, deviceNameProvider: deviceNameProvider,
            enableRegistrationDeletion: enableRegistrationDeletion
        )
    }

    /// Supplies the latest APNs token and updates the push destination of existing MFA registrations.
    /// Call for every successful APNs registration callback, including when no accounts have been added yet.
    /// Supply raw token bytes and the environment matching the hosting app's signed entitlement.
    /// This does not request notification permission or register a new account.
    /// Throws if the update cannot be completed. Callers must not log the token.
    /// Persists the latest token in SDK-owned Keychain storage and reconciles existing service registrations.
    /// Uses only the V2 token-change protocol; accounts already using this token require no service call.
    /// Throws `MSALNativeAuthMFAServiceError.invalidResponse` if an account needing an update lacks
    /// its registration ID or secret. No legacy token-change fallback is attempted.
    /// Throws `MSALNativeAuthMFAPushRegistrationError.invalidDeviceToken` for an empty token.
    /// Forward validation pushes through `handlePushNotification`; each account waits up to 120 seconds
    /// after its start response. Accounts are updated sequentially.
    /// A newer token supplied during an update causes `operationInProgress`; completed accounts are not rolled back.
    /// After active work finishes, call again with the latest token to reconcile remaining accounts.
    public func updatePushRegistration(
        deviceToken: Data,
        apnsEnvironment: MSALNativeAuthMFAAPNsEnvironment
    ) async throws {
        try await service.update(token: deviceToken, environment: apnsEnvironment)
    }

    /// Registers an account using decoded QR text or a manually entered activation code and URL.
    /// Throws if registration cannot be completed. QR payloads, secret keys, and device tokens are not included in the result.
    /// Both input forms require a persisted APNs token; missing state throws
    /// `MSALNativeAuthMFAPushRegistrationError.missingPushRegistration`.
    /// Await `updatePushRegistration` with the latest token before starting enrollment.
    /// Throws `MSALNativeAuthMFAServiceError.invalidResponse` if the device hardware identifier cannot be obtained.
    /// Forward validation pushes through `handlePushNotification`, even while activation is in flight.
    /// Returns only after service confirmation and local persistence. Cancellation does not undo service calls.
    public func registerAuthMethod(
        registrationParameters: MSALNativeAuthMFARegistrationParameters
    ) async throws -> MSALNativeAuthMFARegistrationResult {
        try await service.register(registrationParameters.validatedActivation())
    }

    /// Retrieves pending sign-in requests. An empty array means there are no pending requests.
    /// Returns sessions deduplicated by GUID. No accounts means no service calls.
    /// Throws if any account check or fetch fails, rather than returning partial results.
    public func pullPendingNotifications() async throws -> [MSALNativeAuthMFAAuthSession] {
        try await service.pull()
    }

    /// Approves the specified sign-in request. Supply the entered number when `requiresNumberMatching` is true,
    /// or an empty string for ordinary approval. The service validates the number; the SDK does not disclose it.
    /// Number matching accepts 1-10 ASCII digits. Pass the original session object returned by this manager.
    /// Unsupported approval policies throw `unsupportedPolicy`; denial remains available before submission.
    /// Throws if the response cannot be completed. Callers must not log the entered number.
    /// Once submission starts, the session is replay-blocked even if the operation fails or is cancelled.
    /// Do not retry the decision or switch to denial after submission.
    public func approve(
        authSession: MSALNativeAuthMFAAuthSession,
        number: String
    ) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult {
        try await service.respond(authSession, approve: true, number: number)
    }

    /// Denies the specified sign-in request, or throws if the response cannot be completed.
    /// Pass the original session object returned by this manager. No number is required.
    /// Success returns `wasApproved = false`; failures throw rather than returning a false success result.
    /// Once submission starts, failure or cancellation does not permit retry or switching to approval.
    public func deny(
        authSession: MSALNativeAuthMFAAuthSession
    ) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult {
        try await service.respond(authSession, approve: false, number: "")
    }

    /// Reads registered account display metadata from SDK-owned Keychain storage.
    /// Returns an empty array when none are stored; pending enrollments are excluded.
    /// Does not contact SAS or detect server-side removal. Storage failures throw.
    public func registeredAuthMethods() async throws -> [MSALNativeAuthMFARegistrationResult] {
        try await service.registrations()
    }

    /// Deletes the registered authentication method through Microsoft Graph, then removes its local credentials and sessions.
    /// Requires `enableRegistrationDeletion`. Currently supports commercial-cloud registrations only.
    /// The host acquires a delegated Graph token using the supplied context and returns the unmodified MSAL result.
    /// On both silent and interactive token parameters, the host must request
    /// `{"access_token":{"amr":{"essential":true,"values":["ngcmfa"]}}}` through `claimsRequest`.
    /// Graph enforces recent strong authentication; a login prompt alone does not request the required claim.
    /// The SDK checks the returned tenant and object ID, not the login hint, before sending the deletion.
    /// HTTP 204 or 404 permits local removal; other failures retain the local registration and throw.
    /// A transport failure or cancellation can leave the remote outcome unknown; retrying deletion reconciles a 404.
    /// Local persistence may fail after remote success. Retry deletion to finish cleanup.
    /// Token acquisition may present UI; the host must marshal UI work to the main actor. Never log the token or context.
    public func deleteAuthMethod(
        registrationId: String,
        tokenProvider: @escaping @Sendable (MSALNativeAuthMFADeletionContext) async throws -> MSALResult
    ) async throws {
        try await service.delete(registrationId: registrationId, tokenProvider: tokenProvider)
    }

    /// Handles service notification fields forwarded by the host's APNs callback.
    /// Pass string-valued fields from the MFA notification payload. Do not log the payload.
    /// Forward `url` unchanged: supported values include a legacy hostname or a trusted MAC service URL
    /// with its routing query, with or without the HTTPS scheme.
    /// Validation notifications return no sessions; authentication notifications return trusted session metadata.
    /// Unrelated notification types return an empty array. Malformed MFA notifications throw.
    /// Duplicate active sessions may reuse the same object; submitted or completed sessions throw `invalidSession`.
    public func handlePushNotification(payload: [String: String]) async throws -> [MSALNativeAuthMFAAuthSession] {
        try await service.notification(payload)
    }
}

/// SDK-supplied identity and permissions for acquiring a registration-deletion token.
/// The username is only a login hint. The returned token must belong to `tenantId` and `objectId`.
public final class MSALNativeAuthMFADeletionContext: Sendable {
    public let registrationId: String
    /// Personal information used only for the sign-in prompt. Do not log it.
    public let username: String
    public let tenantId: String
    public let objectId: String
    public let authorityURL: URL
    public let scopes: [String]

    internal init(registrationId: String, username: String, tenantId: String, objectId: String, authorityURL: URL) {
        self.registrationId = registrationId
        self.username = username
        self.tenantId = tenantId
        self.objectId = objectId
        self.authorityURL = authorityURL
        self.scopes = ["https://graph.microsoft.com/UserAuthenticationMethod.ReadWrite"]
    }
}
