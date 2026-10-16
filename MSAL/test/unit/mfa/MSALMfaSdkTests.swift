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
import MSALMfaSdk

final class MSALMfaSdkTests: XCTestCase
{
    func testActivationReturnsTheSameMockForAnyInput() async
    {
        let manager = MSALMfaSdkManager()
        for qrCode in ["", "mock-qr-activation", "not a QR payload"]
        {
            let parameters = MSALMfaSdkRegistrationParameters(qrCode: qrCode)
            XCTAssertEqual(parameters.qrCode, qrCode)
            let result = await manager.activateMfaAccount(registrationParameters: parameters)
            XCTAssertTrue(result.isMock)
            XCTAssertEqual(result.registrationId, "mock-registration")
        }
    }

    func testChallengeIsDeterministicWithoutRegistration() async throws
    {
        let manager = MSALMfaSdkManager()
        for _ in 0..<2
        {
            let sessions = await manager.pullPendingNotificationsAsync()
            XCTAssertEqual(sessions.count, 1)
            let session = try XCTUnwrap(sessions.first)
            XCTAssertTrue(session.isMock)
            XCTAssertEqual(session.guid, "mock-session")
            XCTAssertEqual(session.firstEntropyNumber, "42")
        }
    }

    func testApprovalDoesNotValidateNumbers() async throws
    {
        let manager = MSALMfaSdkManager()
        let sessions = await manager.pullPendingNotificationsAsync()
        let session = try XCTUnwrap(sessions.first)
        for number in ["42", "99", "", "not a number"]
        {
            let result = await manager.approve(authSession: session, number: number)
            XCTAssertTrue(result.isMock)
            XCTAssertTrue(result.wasApproved)
        }
    }

    func testDenyAndApproveAreStatelessMockDecisions() async throws
    {
        let manager = MSALMfaSdkManager()
        let sessions = await manager.pullPendingNotificationsAsync()
        let session = try XCTUnwrap(sessions.first)
        let denial = await manager.deny(authSession: session)
        XCTAssertTrue(denial.isMock)
        XCTAssertFalse(denial.wasApproved)
        let approval = await manager.approve(authSession: session, number: "42")
        XCTAssertTrue(approval.isMock)
        XCTAssertTrue(approval.wasApproved)
        let repeatedDenial = await manager.deny(authSession: session)
        XCTAssertTrue(repeatedDenial.isMock)
        XCTAssertFalse(repeatedDenial.wasApproved)
    }
}
