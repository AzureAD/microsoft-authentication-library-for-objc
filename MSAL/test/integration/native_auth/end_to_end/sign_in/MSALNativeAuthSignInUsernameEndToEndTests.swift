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

import Foundation
import XCTest

final class MSALNativeAuthSignInUsernameEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {
    func test_signInWithUnknownUsernameResultsInError() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let unknownUsername = UUID().uuidString

        if usingMockAPI {
            try await mockResponse(.userNotFound, endpoint: .signInInitiate)
        }

        sut.signIn(username: unknownUsername, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isUserNotFound)
    }

    func test_signInWithKnownUsernameResultsInOTPSent() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let username = ProcessInfo.processInfo.environment["existingOTPUserEmail"] ?? "<existingOTPUserEmail not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypeOOB, endpoint: .signInChallenge)
        }

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInCodeRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)
    }

    func test_signInAndSendingIncorrectOTPResultsInError() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        let username = ProcessInfo.processInfo.environment["existingOTPUserEmail"] ?? "<existingOTPUserEmail not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypeOOB, endpoint: .signInChallenge)
        }

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInCodeRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        if usingMockAPI {
            try await mockResponse(.invalidOOBValue, endpoint: .signInToken)
        }

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: "badc0d3", delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation], timeout: 2)

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInVerifyCodeErrorCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.error)
        XCTAssertTrue(signInVerifyCodeDelegateSpy.error!.isInvalidCode)
    }

    // Hero Scenario 1.2.1. Sign in (Email & Email OTP)
    func test_signInAndSendingCorrectOTPResultsInSuccess() async throws {
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

        await fulfillment(of: [signInExpectation], timeout: 2)

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

        await fulfillment(of: [verifyCodeExpectation], timeout: 2)

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)
    }

    func test_signInWithKnownPasswordUsernameResultsInPasswordSent() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
        }

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)
    }

    func test_signInAndSendingIncorrectPasswordResultsInError() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let passwordRequiredExpectation = expectation(description: "verifying password")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInPasswordRequiredDelegateSpy = SignInPasswordRequiredDelegateSpy(expectation: passwordRequiredExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
        }

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)

        // Now submit the password..

        if usingMockAPI {
            try await mockResponse(.invalidPassword, endpoint: .signInToken)
        }

        signInDelegateSpy.newStatePasswordRequired?.submitPassword(password: "An Invalid Password", delegate: signInPasswordRequiredDelegateSpy)

        await fulfillment(of: [passwordRequiredExpectation], timeout: 2)

        XCTAssertTrue(signInPasswordRequiredDelegateSpy.onSignInPasswordRequiredErrorCalled)
        XCTAssertTrue(signInPasswordRequiredDelegateSpy.error!.isInvalidPassword)
    }

    // Hero Scenario 2.2.2. Sign in – Email and Password on MULTIPLE screens (Email & Password)
    func test_signInAndSendingCorrectPasswordResultsInSuccess() async throws {
        try XCTSkipIf(!usingMockAPI)
        
        let signInExpectation = expectation(description: "signing in")
        let passwordRequiredExpectation = expectation(description: "verifying password")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInPasswordRequiredDelegateSpy = SignInPasswordRequiredDelegateSpy(expectation: passwordRequiredExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"
        let password = ProcessInfo.processInfo.environment["existingUserPassword"] ?? "<existingUserPassword not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
        }

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)

        // Now submit the password..

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        signInDelegateSpy.newStatePasswordRequired?.submitPassword(password: password, delegate: signInPasswordRequiredDelegateSpy)

        await fulfillment(of: [passwordRequiredExpectation], timeout: 2)

        XCTAssertTrue(signInPasswordRequiredDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInPasswordRequiredDelegateSpy.result?.idToken)
        XCTAssertEqual(signInPasswordRequiredDelegateSpy.result?.account.username, username)
    }
}
