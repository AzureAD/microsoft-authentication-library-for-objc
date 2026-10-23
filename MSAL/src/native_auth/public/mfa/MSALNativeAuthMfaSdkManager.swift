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
public final class MSALNativeAuthMfaSdkManager: Sendable {
    internal let deviceTokenManager = MSALNativeAuthMfaSdkDeviceTokenManager()
    private let service: MSALNativeAuthMfaSdkService

    /// Enables the experimental service implementation explicitly. Disabled operations throw `featureDisabled`.
    /// Use one shared manager for the hosting app's enrollment, APNs callbacks and session operations.
    /// `deviceName` is the host-provided device display name sent during enrollment. It may contain personal
    /// information; do not log it. Nil preserves the default generic name. The SDK does not read UIKit device state.
    public init(enableExperimentalService: Bool = false, deviceName: String? = nil) {
        service = MSALNativeAuthMfaSdkService(
            enabled: enableExperimentalService,
            transport: MSALNativeAuthMfaSdkTransport(),
            storage: MSALNativeAuthMfaSdkKeychain(),
            deviceName: deviceName ?? "iOS"
        )
    }

    internal init(
        transport: any MSALNativeAuthMfaSdkTransporting,
        storage: any MSALNativeAuthMfaSdkStoring,
        deviceName: String? = nil
    ) {
        service = MSALNativeAuthMfaSdkService(
            enabled: true, transport: transport, storage: storage, deviceName: deviceName ?? "iOS"
        )
    }

    /// Supplies the latest APNs token and updates the push destination of existing MFA registrations.
    /// Call for every successful APNs registration callback, including when no accounts have been added yet.
    /// Supply raw token bytes and the environment matching the hosting app's signed entitlement.
    /// This does not request notification permission or register a new account.
    /// Throws if the update cannot be completed. Callers must not log the token.
    /// Persists the latest token in SDK-owned Keychain storage and reconciles existing service registrations.
    /// Uses only the V2 token-change protocol; accounts already using this token require no service call.
    /// Throws `MSALNativeAuthMfaSdkServiceError.invalidResponse` if an account needing an update lacks
    /// its registration ID or secret. No legacy token-change fallback is attempted.
    /// Throws `MSALNativeAuthMfaSdkPushRegistrationError.invalidDeviceToken` for an empty token.
    public func updatePushRegistration(
        deviceToken: Data,
        apnsEnvironment: MSALNativeAuthMfaSdkAPNsEnvironment
    ) async throws {
        try await service.update(token: deviceToken, environment: apnsEnvironment)
        try await deviceTokenManager.update(deviceToken: deviceToken, environment: apnsEnvironment)
    }

    /// Registers an account using decoded QR text or a manually entered activation code and URL.
    /// Throws if registration cannot be completed. QR payloads, secret keys, and device tokens are not included in the result.
    /// Both input forms require a persisted APNs token; missing state throws
    /// `MSALNativeAuthMfaSdkPushRegistrationError.missingPushRegistration`.
    /// Await `updatePushRegistration` with the latest token before starting enrollment.
    public func registerAuthMethod(
        registrationParameters: MSALNativeAuthMfaSdkRegistrationParameters
    ) async throws -> MSALNativeAuthMfaSdkRegistrationResult {
        try await service.register(registrationParameters.validatedActivation())
    }

    /// Retrieves pending sign-in requests. An empty array means there are no pending requests.
    /// Throws if the requests cannot be retrieved.
    public func pullPendingNotifications() async throws -> [MSALNativeAuthMfaSdkAuthSession] {
        try await service.pull()
    }

    /// Approves the specified sign-in request. Supply the entered number when `requiresNumberMatching` is true,
    /// or an empty string for ordinary approval. The service validates the number; the SDK does not disclose it.
    /// Throws if the response cannot be completed. Callers must not log the entered number.
    public func approve(
        authSession: MSALNativeAuthMfaSdkAuthSession,
        number: String
    ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult {
        try await service.respond(authSession, approve: true, number: number)
    }

    /// Denies the specified sign-in request, or throws if the response cannot be completed.
    public func deny(
        authSession: MSALNativeAuthMfaSdkAuthSession
    ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult {
        try await service.respond(authSession, approve: false, number: "")
    }

    /// Reads registered account display metadata from SDK-owned Keychain storage.
    public func registeredAuthMethods() async throws -> [MSALNativeAuthMfaSdkRegistrationResult] {
        try await service.registrations()
    }

    /// Handles service notification fields forwarded by the host's APNs callback.
    /// Pass string-valued fields from the MFA notification payload. Do not log the payload.
    /// Forward `url` unchanged: supported values include a legacy hostname or a trusted MAC service URL
    /// with its routing query, with or without the HTTPS scheme.
    /// Validation notifications return no sessions; authentication notifications return trusted session metadata.
    /// Unrelated notification types return an empty array. Malformed MFA notifications throw.
    public func handlePushNotification(payload: [String: String]) async throws -> [MSALNativeAuthMfaSdkAuthSession] {
        try await service.notification(payload)
    }
}
