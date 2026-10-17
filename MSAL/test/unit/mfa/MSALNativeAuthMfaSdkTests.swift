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
import MSAL

final class MSALNativeAuthMfaSdkTests: XCTestCase
{
    func testActivationAcceptsQRInputAndReturnsRegistrationDetails() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        for qrCode in ["scanned-qr-payload", "another-qr-payload"]
        {
            let parameters = MSALNativeAuthMfaSdkRegistrationParameters(qrCode: qrCode)
            XCTAssertEqual(parameters.qrCode, qrCode)
            let result = try await manager.activateMfaAccount(registrationParameters: parameters)
            XCTAssertNotNil(UUID(uuidString: result.registrationId))
            XCTAssertFalse(result.accountName.isEmpty)
        }
    }

    func testManualRegistrationAcceptsNameAndSecretWithoutQRAndReturnsOnlyDisplayMetadata() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        for secret in ["JBSWY3DPEHPK3PXP", "GEZDGNBVGY3TQOJQ"]
        {
            let parameters = MSALNativeAuthMfaSdkManualRegistrationParameters(
                accountName: " Other account \n",
                secretKey: secret
            )
            XCTAssertEqual(parameters.accountName, " Other account \n")
            XCTAssertEqual(parameters.secretKey, secret)
            let result = try await manager.addThirdPartyAccount(registrationParameters: parameters)
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
            let sessions = try await manager.pullPendingNotificationsAsync()
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
        let sessions = try await manager.pullPendingNotificationsAsync()
        let session = try XCTUnwrap(sessions.first)
        let result = try await manager.approve(authSession: session, number: "42")
        XCTAssertTrue(result.wasApproved)
    }

    func testDenialReturnsCompletedDecision() async throws
    {
        let manager = MSALNativeAuthMfaSdkManager()
        let sessions = try await manager.pullPendingNotificationsAsync()
        let session = try XCTUnwrap(sessions.first)
        let denial = try await manager.deny(authSession: session)
        XCTAssertFalse(denial.wasApproved)
    }
}
