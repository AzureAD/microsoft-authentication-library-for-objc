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
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let unknownUsername = UUID().uuidString + "@contoso.com"

        sut.signIn(username: unknownUsername, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isUserNotFound)
    }

    func test_signInAndSendingIncorrectOTPResultsInError() async throws {
        throw XCTSkip("Skipping this test because email+code signIn username is missing")
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        let username = "missing email+code signIn username"

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        guard signInDelegateSpy.onSignInCodeRequiredCalled else {
            XCTFail("OTP not sent")
            return
        }
        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: "00000000", delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInVerifyCodeErrorCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.error)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.error?.isInvalidCode, true)
    }

    // Hero Scenario 1.2.1. Sign in (Email & Email OTP)
    func test_signInAndSendingCorrectOTPResultsInSuccess() async throws {
        throw XCTSkip("Skipping this test because email+code signIn username is missing")
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        let username = ProcessInfo.processInfo.environment["existingOTPUserEmail"] ?? "<existingOTPUserEmail not set>"
        let otp = "<otp not set>"

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInCodeRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: otp, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)
    }
}
