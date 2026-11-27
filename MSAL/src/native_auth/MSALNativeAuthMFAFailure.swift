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

// Internal operation conditions, translated at the manager boundary into the shared public error shape.
internal enum MSALNativeAuthMFAFailure: Error, Equatable, Sendable {
    case invalidDeviceToken
    case missingPushRegistration
    case missingSecretKey
    case invalidActivationInput
    case untrustedEndpoint
    case invalidResponse
    case transportFailure
    case httpFailure(statusCode: Int)
    /// A service rejection with a bounded numeric code or SDK-defined category, never a raw service description.
    case serviceFailure(operation: String, code: String)
    /// A definitive enrollment rejection, not an uncertain transport or service-fault outcome.
    case enrollmentRejected(code: String)
    case sasClientUnavailable
    case validationOnlyEndpoint
    case storageFailure(status: Int32)
    case operationInProgress
    case validationTimedOut
    case unexpectedNotification
    case unknownAccount
    case registrationNotFound
    case invalidSession
    case completedSession
    case unsupportedPolicy
    case invalidNumber
    case outcomeUnknown
    /// Graph deletion is not configured for this registration's cloud.
    case unsupportedDeletionCloud
    /// The provider returned an expired, empty, or unsuitable Graph token.
    case invalidDeletionToken
    /// The sign-in result does not belong to the registration's tenant and user.
    case deletionAccountMismatch
}

// Preserve provider-owned errors across the SDK's sanitizing boundary.
internal struct MSALNativeAuthMFAProviderFailure: Error {
    let underlying: Error
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
        case .serviceFailure, .enrollmentRejected:
            type = .generalError
            message = "The MFA service rejected the operation. Do not automatically replay a submitted request."
        case .sasClientUnavailable:
            type = .generalError
            message = "MFA API is not implemented."
        case .validationOnlyEndpoint:
            type = .generalError
            message = "The EEID endpoint only validated the contract; it did not execute the MFA workflow."
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
