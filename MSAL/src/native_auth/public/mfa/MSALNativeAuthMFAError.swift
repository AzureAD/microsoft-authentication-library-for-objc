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
// furnished to do so, subject to the following conditions:
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

/// A standalone SDK-originated MFA failure with exactly one action-oriented classifier.
/// Diagnostics are bounded and SDK-controlled, never raw errors, payloads, claims or credentials.
/// Token-provider errors propagate unchanged. Swift `CancellationError` propagates separately.
/// Failure or cancellation does not imply rollback or permission to replay a mutation.
@objcMembers
public final class MSALNativeAuthMFAError: NSObject, LocalizedError {
    enum ErrorType: CaseIterable, Sendable {
        case pushTokenMissing
        case registrationNotFound
        case invalidChallenge
        case invalidCode
        case userSignedInWithMismatchedAccount
        case generalError
    }

    private let type: ErrorType
    private let message: String?

    /// Optional sanitized diagnostics. Do not parse for control flow.
    public var errorDescription: String? { message }
    /// SDK-generated operation identifier, including for local failures.
    public let correlationId: UUID

    init(type: ErrorType, errorDescription: String?, correlationId: UUID) {
        self.type = type
        self.message = errorDescription
        self.correlationId = correlationId
        super.init()
    }

    /// Supply the missing push token through `updatePushRegistration`. Invalid tokens and rotation failures do not qualify.
    public var isPushTokenMissing: Bool { type == .pushTokenMissing }
    /// The explicitly requested registration does not exist locally. Reload the registration list.
    public var isRegistrationNotFound: Bool { type == .registrationNotFound }
    /// A known completed or replay-blocked manager-issued session is unusable. Discard it.
    /// Malformed or untrusted context is a general error.
    public var isInvalidChallenge: Bool { type == .invalidChallenge }
    /// Invalid matching number with same-session retry permitted, including pre-submit format errors.
    /// Uncertain submissions and service rejections without continuation guarantees do not qualify.
    public var isInvalidCode: Bool { type == .invalidCode }
    /// A successfully returned token-provider identity differs from the registration. Sign in with the expected account.
    public var isUserSignedInWithMismatchedAccount: Bool { type == .userSignedInWithMismatchedAccount }
    /// No supported application recovery is established. End the operation; do not automatically retry.
    /// Includes protocol, storage, configuration, busy, partial-write and uncertain-outcome failures.
    public var isGeneralError: Bool { type == .generalError }
}

internal enum MSALNativeAuthMFARequestContext {
    @TaskLocal static var correlationId: UUID?
}

internal extension MSALNativeAuthMFAError {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func from(_ error: Error, correlationId: UUID) -> MSALNativeAuthMFAError {
        if let error = error as? MSALNativeAuthMFAError { return error }
        guard let failure = error as? MSALNativeAuthMFAFailure else {
            return MSALNativeAuthMFAError(
                type: .generalError, errorDescription: "Unable to complete the MFA operation.", correlationId: correlationId
            )
        }
        let type: ErrorType
        let message: String
        switch failure {
        case .invalidActivationInput:
            type = .generalError
            message = "The activation code or URL is invalid."
        case .invalidNumber:
            type = .invalidCode
            message = "Enter 1-10 ASCII digits for number matching."
        case .untrustedEndpoint:
            type = .generalError
            message = "The MFA service destination was rejected. Do not bypass destination validation."
        case .invalidDeviceToken:
            type = .generalError
            message = "The APNs device token is invalid."
        case .missingPushRegistration:
            type = .pushTokenMissing
            message = "Supply the current APNs token through updatePushRegistration before continuing."
        case .registrationNotFound:
            type = .registrationNotFound
            message = "The requested registration does not exist locally. Reload the registration list."
        case .unknownAccount:
            type = .generalError
            message = "The registered account is no longer available."
        case .invalidResponse:
            type = .generalError
            message = "Required MFA response or account data is missing or invalid."
        case .transportFailure:
            type = .generalError
            message = "Communication with the MFA service failed. A submitted operation may already have completed."
        case .httpFailure(let status):
            type = .generalError
            message = "The MFA service returned HTTP \(status). A submitted operation may already have completed."
        case .serviceFailure:
            type = .generalError
            message = "The MFA service rejected the operation. Do not automatically replay a submitted request."
        case .storageFailure(let status):
            type = .generalError
            message = "Unable to read or persist MFA registration state (storage status \(status))."
        case .missingSecretKey:
            type = .generalError
            message = "The registered account has no usable signing secret."
        case .operationInProgress:
            type = .generalError
            message = "Another operation is active or a newer push token superseded this update. Wait for active work to finish."
        case .outcomeUnknown:
            type = .generalError
            message = "A submitted operation has an unresolved outcome. Do not replay it without service-defined recovery."
        case .unsupportedDeletionCloud:
            type = .generalError
            message = "Server deletion currently supports commercial-cloud registrations only."
        case .validationTimedOut:
            type = .generalError
            message = "MFA validation timed out. Check push delivery and forwarding before reconciling."
        case .unexpectedNotification:
            type = .generalError
            message = "The notification is malformed or does not match the pending validation."
        case .invalidSession:
            type = .generalError
            message = "The session is invalid or already submitted. Do not reuse it."
        case .completedSession:
            type = .invalidChallenge
            message = "The manager-issued session is completed or replay-blocked. Discard it."
        case .unsupportedPolicy:
            type = .generalError
            message = "The session requires unsupported policy. No actionable session was returned."
        case .validationOnlyEndpoint:
            type = .generalError
            message = "The EEID endpoint validated the contract only; it did not execute the requested workflow."
        case .invalidDeletionToken:
            type = .generalError
            message = "Token acquisition did not provide a valid delegated Graph token for deletion."
        case .deletionAccountMismatch:
            type = .userSignedInWithMismatchedAccount
            message = "Sign in with the account being deleted and its expected authority. No deletion request was sent."
        }
        return MSALNativeAuthMFAError(type: type, errorDescription: message, correlationId: correlationId)
    }
}
