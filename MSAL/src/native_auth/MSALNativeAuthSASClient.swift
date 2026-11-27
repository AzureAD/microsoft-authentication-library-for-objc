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

/// SAS operations return normalized values, never wire envelopes or service result codes.
/// Implementations own input/endpoint validation, token encoding, proofs and policy decoding.
/// Only an explicit enrollment rejection may throw `enrollmentRejected`; ambiguous outcomes must not.
internal protocol MSALNativeAuthSASClient: Sendable {
    func activationInput(_ parameters: MSALNativeAuthMFARegistrationParameters) throws -> MSALNativeAuthMFAActivation
    func deviceToken(_ data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) throws -> String
    func notification(_ payload: [AnyHashable: Any]) throws -> MSALNativeAuthSASNotification?
    func endpoint(for scope: String, in endpoints: MSALNativeAuthSASEndpoints) throws -> URL

    func activate(
        input: MSALNativeAuthMFAActivation, token: String, deviceName: String
    ) async throws -> MSALNativeAuthSASActivationResult
    func confirmActivation(code: String, endpoint: URL) async throws -> String
    func validateDeviceToken(guid: String, token: String, endpoint: URL) async throws -> MSALNativeAuthSASValidationResult
    func startDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, environment: MSALNativeAuthMFAAPNsEnvironment, endpoint: URL
    ) async throws
    func completeDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, counter: UInt64, endpoint: URL
    ) async throws
    func checkForAuthentication(
        account: MSALNativeAuthMFAAccountRecord, previousToken: String?, endpoint: URL
    ) async throws -> MSALNativeAuthSASPendingAuthentication?
    func authentication(
        guid: String, token: String, account: MSALNativeAuthMFAAccountRecord?, counter: UInt64?, endpoint: URL
    ) async throws -> MSALNativeAuthSASAuthenticationResult
    func pinValidation(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, number: String, endpoint: URL
    ) async throws
    func authenticationResult(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, approved: Bool, endpoint: URL
    ) async throws
    func getEndpoints(endpoint: URL) async throws -> MSALNativeAuthSASEndpoints
}

internal struct MSALNativeAuthSASActivationResult: Codable, Sendable {
    let username: String
    let secret: String
    let confirmationCode: String
    let tenantId: String
    let objectId: String
    var bundleId: String?
    var replicationScope: String?
    var routingHint: String?
    var countryCode: String?
}

internal struct MSALNativeAuthSASValidationResult: Codable, Sendable {
    let username: String
    let accountName: String
    let groupKey: String
    let dosPreventer: String
}

internal struct MSALNativeAuthSASPendingAuthentication: Sendable {
    let guid: String
    let endpoint: URL
    let username: String
    let counter: UInt64?
}

internal struct MSALNativeAuthSASAuthenticationResult: Sendable {
    let guid: String
    let registrationId: String
    let tenantId: String
    let objectId: String
    let replicationScope: String?
    let routingHint: String?
    let countryCode: String?
    let dosPreventer: String
    let requiresNumberMatching: Bool
    let policySupported: Bool
    /// Client-owned challenge metadata, held only in memory and passed back unchanged for decisions.
    let serverContext: Data?
}

internal struct MSALNativeAuthSASEndpoints: Sendable {
    let defaultURL: String
    let endpoints: [String: String]
}

internal enum MSALNativeAuthSASValidationScenario: Equatable, Sendable {
    case enrollment
    case tokenChange
}

internal enum MSALNativeAuthSASNotification: Sendable {
    case authentication(guid: String, endpoint: URL)
    case validation(MSALNativeAuthSASValidationNotification)
}

internal struct MSALNativeAuthSASValidationNotification: Sendable {
    let guid: String
    let endpoint: URL
    let scenario: MSALNativeAuthSASValidationScenario?
    let counter: UInt64?
    let tenantId: String?
}
