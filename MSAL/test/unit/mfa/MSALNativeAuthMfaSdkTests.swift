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

import XCTest
@testable import MSAL

final class MSALNativeAuthMfaSdkTests: XCTestCase
{
    func testQRActivationRequiresPushUpdateOnSameManager() async throws
    {
        let parameters = MSALNativeAuthMfaSdkRegistrationParameters(qrCode: "scanned-code")
        let manager = MSALNativeAuthMfaSdkManager()
        do
        {
            _ = try await manager.registerAuthMethod(registrationParameters: parameters)
            XCTFail("QR activation must require the push destination")
        }
        catch
        {
            XCTAssertEqual(error as? MSALNativeAuthMfaSdkPushRegistrationError, .missingPushRegistration)
        }
        try await manager.updatePushRegistration(deviceToken: Data([0x01]), apnsEnvironment: .sandbox)
        _ = try await manager.registerAuthMethod(registrationParameters: parameters)
        do
        {
            _ = try await MSALNativeAuthMfaSdkManager().registerAuthMethod(registrationParameters: parameters)
            XCTFail("Token state must not leak between manager instances")
        }
        catch
        {
            XCTAssertEqual(error as? MSALNativeAuthMfaSdkPushRegistrationError, .missingPushRegistration)
        }
    }

    func testEmptyAndCanceledUpdatesPreserveExistingToken() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        try await manager.updatePushRegistration(deviceToken: Data([0x01]), apnsEnvironment: .sandbox)
        do
        {
            try await manager.updatePushRegistration(deviceToken: Data(), apnsEnvironment: .production)
            XCTFail("Empty token must fail")
        }
        catch
        {
            XCTAssertEqual(error as? MSALNativeAuthMfaSdkPushRegistrationError, .invalidDeviceToken)
        }
        let task = Task
        {
            withUnsafeCurrentTask { $0?.cancel() }
            try await manager.updatePushRegistration(deviceToken: Data([0x02]), apnsEnvironment: .production)
        }
        do
        {
            try await task.value
            XCTFail("Canceled update must fail")
        }
        catch
        {
            XCTAssertTrue(error is CancellationError)
        }
        let retained = try await manager.deviceTokenManager.registration()
        XCTAssertEqual(retained.deviceToken, Data([0x01]))
        XCTAssertEqual(retained.environment, .sandbox)
    }

    func testPushUpdateInterfaceAcceptsRepeatedAndChangedTokensWithoutAccountActivation() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        for environment in [MSALNativeAuthMfaSdkAPNsEnvironment.sandbox, .production]
        {
            for token in [Data([0x00, 0xAB]), Data([0x00, 0xAB]), Data([0xFF, 0x01])]
            {
                try await manager.updatePushRegistration(deviceToken: token, apnsEnvironment: environment)
            }
        }
    }

    func testCanceledPushUpdateThrowsCancellation() async
    {
        let manager = MSALNativeAuthMfaSdkManager()
        let task = Task
        {
            withUnsafeCurrentTask { $0?.cancel() }
            try await manager.updatePushRegistration(deviceToken: Data([0x01]), apnsEnvironment: .sandbox)
        }
        do
        {
            try await task.value
            XCTFail("A canceled update must not report success")
        }
        catch
        {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testActivationAcceptsQRInputAndReturnsRegistrationDetails() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        try await manager.updatePushRegistration(deviceToken: Data([0x01]), apnsEnvironment: .sandbox)
        for qrCode in ["scanned-qr-payload", "another-qr-payload"]
        {
            let parameters = MSALNativeAuthMfaSdkRegistrationParameters(qrCode: qrCode)
            XCTAssertEqual(parameters.qrCode, qrCode)
            XCTAssertNil(parameters.accountName)
            XCTAssertNil(parameters.secretKey)
            let result = try await manager.registerAuthMethod(registrationParameters: parameters)
            XCTAssertNotNil(UUID(uuidString: result.registrationId))
            XCTAssertFalse(result.accountName.isEmpty)
        }
    }

    func testSDKRetainsLatestTokenBytesAndEnvironment() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        let token = Data([0x00, 0xAB, 0xFF])
        for environment in [MSALNativeAuthMfaSdkAPNsEnvironment.sandbox, .production]
        {
            try await manager.updatePushRegistration(deviceToken: token, apnsEnvironment: environment)
            let stored = try await manager.deviceTokenManager.registration()
            XCTAssertEqual(stored.deviceToken, token)
            XCTAssertEqual(stored.environment, environment)
        }
        try await manager.updatePushRegistration(deviceToken: Data([0x02]), apnsEnvironment: .sandbox)
        let rotated = try await manager.deviceTokenManager.registration()
        XCTAssertEqual(rotated.deviceToken, Data([0x02]))
        XCTAssertEqual(rotated.environment, .sandbox)
        XCTAssertEqual(MSALNativeAuthMfaSdkAPNsEnvironment(rawValue: "development"), .sandbox)
        XCTAssertEqual(MSALNativeAuthMfaSdkAPNsEnvironment(rawValue: "production"), .production)
        XCTAssertNil(MSALNativeAuthMfaSdkAPNsEnvironment(rawValue: "unknown"))
    }

    func testManualRegistrationAcceptsNameAndSecretWithoutQRAndReturnsOnlyDisplayMetadata() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        for secret in ["JBSWY3DPEHPK3PXP", "GEZDGNBVGY3TQOJQ"]
        {
            let parameters = MSALNativeAuthMfaSdkRegistrationParameters(
                accountName: " Other account \n",
                secretKey: secret
            )
            XCTAssertEqual(parameters.accountName, " Other account \n")
            XCTAssertEqual(parameters.secretKey, secret)
            XCTAssertNil(parameters.qrCode)
            let result = try await manager.registerAuthMethod(registrationParameters: parameters)
            XCTAssertNotNil(UUID(uuidString: result.registrationId))
            XCTAssertEqual(result.accountName, "Other account")
            XCTAssertEqual(
                Set(Mirror(reflecting: result).children.compactMap(\.label)),
                ["registrationId", "accountName"]
            )
        }
    }

    func testPendingChallengeIncludesIdentityAndSessionDetails() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        for _ in 0..<2
        {
            let sessions = try await manager.pullPendingNotifications()
            XCTAssertEqual(sessions.count, 1)
            let session = try XCTUnwrap(sessions.first)
            XCTAssertNotNil(UUID(uuidString: session.guid))
            XCTAssertFalse(session.firstEntropyNumber.isEmpty)
            XCTAssertFalse(session.accountName.isEmpty)
            XCTAssertFalse(session.username.isEmpty)
        }
    }

    func testApprovalReturnsCompletedDecision() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        let sessions = try await manager.pullPendingNotifications()
        let session = try XCTUnwrap(sessions.first)
        let result = try await manager.approve(authSession: session, number: "42")
        XCTAssertTrue(result.wasApproved)
    }

    func testDenialReturnsCompletedDecision() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        let sessions = try await manager.pullPendingNotifications()
        let session = try XCTUnwrap(sessions.first)
        let denial = try await manager.deny(authSession: session)
        XCTAssertFalse(denial.wasApproved)
    }
}
