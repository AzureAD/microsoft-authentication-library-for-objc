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

/// Unified MFA error with the Native Auth V2 error structure and Authenticator's error categories.
///
/// Inspect the Boolean classifications rather than parsing the description. Descriptions contain only
/// SDK-controlled diagnostics; raw provider errors, response bodies and credentials are not exposed.
/// `errorCodes` contains service-provided numeric codes, not HTTP statuses, Keychain statuses or local enum values.
/// Task cancellation is propagated as `CancellationError`, not converted into this type.
///
/// A failure does not imply that a submitted operation was rolled back or can safely be retried.
@objcMembers
public final class MSALNativeAuthMFAError: MSALNativeAuthError {
    enum ErrorType: CaseIterable {
        case generalError
        case invalidArgument
        case networkError
        case itemNotFound
        case userInteractionRequired
        case userCancelled
        case userSignedInWithMismatchedAccount
        case storageError
        case operationNotAllowed
        case invalidRegistration
        case authNotificationError
    }

    let type: ErrorType

    init(
        type: ErrorType,
        errorDescription: String,
        correlationId: UUID,
        errorCodes: [Int] = [],
        isBrowserRequired: Bool = false
    ) {
        self.type = type
        super.init(
            message: errorDescription, correlationId: correlationId, errorCodes: errorCodes,
            isBrowserRequired: isBrowserRequired, isGeneralError: type == .generalError
        )
    }

    /// The caller supplied invalid input. Correct it before starting another operation.
    public var isInvalidArgument: Bool { type == .invalidArgument }
    /// Communication failed or validation timed out. A write may already have reached the service.
    public var isNetworkError: Bool { type == .networkError }
    /// Required local account or registration state was not found.
    public var isItemNotFound: Bool { type == .itemNotFound }
    /// Token acquisition requires user interaction. This does not necessarily require a browser.
    public var isUserInteractionRequired: Bool { type == .userInteractionRequired }
    /// The user cancelled sign-in. This is distinct from Swift task cancellation.
    public var isUserCancelled: Bool { type == .userCancelled }
    /// The acquired token's identity or authority does not match the registration.
    public var isUserSignedInWithMismatchedAccount: Bool { type == .userSignedInWithMismatchedAccount }
    /// Registration storage or a required stored secret could not be accessed.
    public var isStorageError: Bool { type == .storageError }
    /// Current operation state or the supported environment prevents this operation.
    /// This includes conflicting work and retained uncertain enrollment outcomes; do not blindly retry.
    public var isOperationNotAllowed: Bool { type == .operationNotAllowed }
    /// The device token or registration is invalid.
    public var isInvalidRegistration: Bool { type == .invalidRegistration }
    /// The notification/session is invalid, already processed, or unsupported.
    public var isAuthNotificationError: Bool { type == .authNotificationError }
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
        var codes: [Int] = []
        switch failure {
        case .invalidActivationInput:
            type = .invalidArgument
            message = "The activation code or URL is invalid."
        case .invalidNumber:
            type = .invalidArgument
            message = "Enter 1-10 ASCII digits for number matching."
        case .untrustedEndpoint:
            type = .invalidArgument
            message = "The MFA service destination was rejected. Do not bypass destination validation."
        case .invalidDeviceToken:
            type = .invalidRegistration
            message = "The APNs device token is invalid."
        case .missingPushRegistration:
            type = .itemNotFound
            message = "Supply the current APNs token through updatePushRegistration before continuing."
        case .unknownAccount:
            type = .itemNotFound
            message = "The registered account is no longer available."
        case .invalidResponse:
            type = .generalError
            message = "Required MFA response or account data is missing or invalid."
        case .transportFailure:
            type = .networkError
            message = "Communication with the MFA service failed. A submitted operation may already have completed."
        case .httpFailure(let status):
            type = .generalError
            message = "The MFA service returned HTTP \(status). A submitted operation may already have completed."
        case .serviceFailure(let operation, let code):
            // These are numeric protocol results, not HTTP statuses or local diagnostic categories.
            if !code.isEmpty, code.utf8.count <= 10, code.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int(code) {
                codes = [value]
            }
            switch (operation, code) {
            case ("DeviceTokenChange", "101"), ("CompleteDeviceTokenChange", "101"):
                type = .invalidRegistration
            case ("DeviceTokenChange", "102"), ("CompleteDeviceTokenChange", "102"):
                type = .networkError
            case ("ActivateNew", "17"), ("ConfirmActivation", "17"):
                type = .operationNotAllowed
            default:
                type = .generalError
            }
            message = "The MFA service rejected the operation. Do not automatically replay a submitted request."
        case .storageFailure(let status):
            type = .storageError
            message = "Unable to read or persist MFA registration state (storage status \(status))."
        case .missingSecretKey:
            type = .storageError
            message = "The registered account has no usable signing secret."
        case .operationInProgress:
            type = .operationNotAllowed
            message = "Another operation is active or a newer push token superseded this update. Wait for active work to finish."
        case .outcomeUnknown:
            type = .operationNotAllowed
            message = "The previous enrollment outcome is unknown. Do not replay activation or confirmation blindly."
        case .unsupportedDeletionCloud:
            type = .operationNotAllowed
            message = "Server deletion currently supports commercial-cloud registrations only."
        case .validationTimedOut:
            type = .networkError
            message = "MFA validation timed out. Check push delivery and forwarding before reconciling."
        case .unexpectedNotification:
            type = .authNotificationError
            message = "The notification is malformed or does not match the pending validation."
        case .invalidSession:
            type = .authNotificationError
            message = "The session is invalid or already submitted. Do not reuse it."
        case .unsupportedPolicy:
            type = .authNotificationError
            message = "The session requires unsupported approval capabilities. Denial remains available before submission."
        case .invalidDeletionToken:
            type = .generalError
            message = "Token acquisition did not provide a valid delegated Graph token for deletion."
        case .deletionAccountMismatch:
            type = .userSignedInWithMismatchedAccount
            message = "Sign in with the account being deleted and its expected authority. No deletion request was sent."
        }
        return MSALNativeAuthMFAError(type: type, errorDescription: message, correlationId: correlationId, errorCodes: codes)
    }

    static func fromTokenProvider(_ error: Error, correlationId: UUID) -> MSALNativeAuthMFAError {
        if let error = error as? MSALNativeAuthMFAError { return error }
        let nativeError = error as? MSALNativeAuthError
        let nsError = error as NSError
        let type: ErrorType
        let message: String
        if nsError.domain == MSALErrorDomain, nsError.code == MSALError.userCanceled.rawValue {
            type = .userCancelled
            message = "Sign-in was cancelled. No deletion request was sent."
        } else if nativeError?.isBrowserRequired == true ||
                    (nsError.domain == MSALErrorDomain && nsError.code == MSALError.interactionRequired.rawValue) {
            type = .userInteractionRequired
            message = "Token acquisition requires user interaction. No deletion request was sent."
        } else if nsError.domain == MSALErrorDomain,
                  (nsError.userInfo[MSALInternalErrorCodeKey] as? NSNumber)?.intValue == MSALInternalError.mismatchedUser.rawValue {
            type = .userSignedInWithMismatchedAccount
            message = "Sign in with the account being deleted. No deletion request was sent."
        } else {
            type = .generalError
            message = "Unable to acquire the required token. Check provider configuration, permissions and sign-in."
        }
        return MSALNativeAuthMFAError(
            type: type, errorDescription: message, correlationId: correlationId,
            errorCodes: nativeError?.errorCodes ?? [], isBrowserRequired: nativeError?.isBrowserRequired ?? false
        )
    }
}
