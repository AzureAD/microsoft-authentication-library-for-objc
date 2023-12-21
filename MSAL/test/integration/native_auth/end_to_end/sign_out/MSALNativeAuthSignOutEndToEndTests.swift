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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import XCTest

final class MSALNativeAuthSignOutEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {
    func test_noSignOutAfterSignInOTPAccountStillPresent() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        let username = ProcessInfo.processInfo.environment["existingOTPUserEmail"] ?? "<existingOTPUserEmail not set>"
        let otp = "<otp not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypeOOB, endpoint: .signInChallenge)
        }

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInCodeRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        } else {
            // TODO: Replace this with retrieving the OTP from email
            XCTAssertNotEqual(otp, "<otp not set>")
        }

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: otp, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)

        // Check Account Exists

        let userAccountResult = sut.getNativeAuthUserAccount()
        XCTAssertNotNil(userAccountResult)
        XCTAssertEqual(userAccountResult?.account.username, username)
    }

    // Hero Scenario 1.3.1. Sign out – Local sign out from app on device (no SSO)
    
    func test_signOutAfterSignInOTPSuccess() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        let username = ProcessInfo.processInfo.environment["existingOTPUserEmail"] ?? "<existingOTPUserEmail not set>"
        let otp = "<otp not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypeOOB, endpoint: .signInChallenge)
        }

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInCodeRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        } else {
            // TODO: Replace this with retrieving the OTP from email
            XCTAssertNotEqual(otp, "<otp not set>")
        }

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: otp, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)

        // Sign out

        var userAccountResult = sut.getNativeAuthUserAccount()
        userAccountResult?.signOut()

        userAccountResult = sut.getNativeAuthUserAccount()
        XCTAssertNil(userAccountResult)
    }

    func test_noSignOutAfterSignInPasswordAccountStillPresent() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"
        let password = ProcessInfo.processInfo.environment["existingUserPassword"] ?? "<existingUserPassword not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)

        // Check Account Exists

        let userAccountResult = sut.getNativeAuthUserAccount()
        XCTAssertNotNil(userAccountResult)
        XCTAssertEqual(userAccountResult?.account.username, username)
    }

    // Hero Scenario 2.4.1. Sign out – Local sign out from app on device (no SSO)

    func test_signOutAfterSignInPasswordSuccess() async throws {
        try XCTSkipIf(!usingMockAPI)
        
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"
        let password = ProcessInfo.processInfo.environment["existingUserPassword"] ?? "<existingUserPassword not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)

        // Sign out

        var userAccountResult = sut.getNativeAuthUserAccount()
        userAccountResult?.signOut()

        userAccountResult = sut.getNativeAuthUserAccount()
        XCTAssertNil(userAccountResult)
    }
}
