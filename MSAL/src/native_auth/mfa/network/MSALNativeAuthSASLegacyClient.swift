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

/// Placeholder only: SAS operations require the separate legacy-client implementation.
internal struct MSALNativeAuthSASLegacyClient: MSALNativeAuthSASClient {
    let isImplemented = false

    private typealias Failure = MSALNativeAuthMFAError.Reason

    init(transport: any MSALNativeAuthMFATransporting) {}

    func activationInput(_ parameters: MSALNativeAuthMFARegistrationParameters) throws -> MSALNativeAuthMFAActivation {
        throw Failure.sasClientUnavailable
    }

    func deviceToken(_ data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) throws -> String {
        throw Failure.sasClientUnavailable
    }

    func notification(_ payload: [AnyHashable: Any]) throws -> MSALNativeAuthSASNotification? {
        throw Failure.sasClientUnavailable
    }

    func endpoint(for scope: String, in endpoints: MSALNativeAuthSASEndpoints) throws -> URL {
        throw Failure.sasClientUnavailable
    }

    func activate(input: MSALNativeAuthMFAActivation, token: String, deviceName: String) async throws -> MSALNativeAuthSASActivationResult {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func confirmActivation(code: String, endpoint: URL) async throws -> String {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func validateDeviceToken(guid: String, token: String, endpoint: URL) async throws -> MSALNativeAuthSASValidationResult {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func startDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, environment: MSALNativeAuthMFAAPNsEnvironment, endpoint: URL
    ) async throws {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func completeDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, counter: UInt64, endpoint: URL
    ) async throws {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func checkForAuthentication(
        account: MSALNativeAuthMFAAccountRecord, previousToken: String?, endpoint: URL
    ) async throws -> MSALNativeAuthSASPendingAuthentication? {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func authentication(
        guid: String, token: String, account: MSALNativeAuthMFAAccountRecord?, counter: UInt64?, endpoint: URL
    ) async throws -> MSALNativeAuthSASAuthenticationResult {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func pinValidation(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, number: String, endpoint: URL
    ) async throws {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func authenticationResult(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, approved: Bool, endpoint: URL
    ) async throws {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }

    func getEndpoints(endpoint: URL) async throws -> MSALNativeAuthSASEndpoints {
        try Task.checkCancellation()
        throw Failure.sasClientUnavailable
    }
}
