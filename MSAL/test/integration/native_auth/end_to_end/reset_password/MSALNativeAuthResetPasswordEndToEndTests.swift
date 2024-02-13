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

final class MSALNativeAuthResetPasswordEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {

    private let usernameOTP = ProcessInfo.processInfo.environment["existingOTPUserEmail"] ?? "<existingOTPUserEmail not set>"

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipIf(!usingMockAPI)
    }
    
    // Hero Scenario 2.3.1. SSPR – without automatic sign in
    func test_resetPassword_withoutAutomaticSignIn_succeeds() async throws {
        let codeRequiredExp = expectation(description: "code required")
        let resetPasswordStartDelegate = ResetPasswordStartDelegateSpy(expectation: codeRequiredExp)

        if usingMockAPI {
            try await mockResponse(.ssprStartSuccess, endpoint: .resetPasswordStart)
        }

        sut.resetPassword(username: usernameOTP, delegate: resetPasswordStartDelegate)

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled)
        XCTAssertEqual(resetPasswordStartDelegate.channelTargetType, .email)
        XCTAssertFalse(resetPasswordStartDelegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(resetPasswordStartDelegate.codeLength)

        // Now submit the code...

        let passwordRequiredExp = expectation(description: "password required")
        let resetPasswordVerifyDelegate = ResetPasswordVerifyCodeDelegateSpy(expectation: passwordRequiredExp)

        if usingMockAPI {
            try await mockResponse(.ssprContinueSuccess, endpoint: .resetPasswordContinue)
        }

        resetPasswordStartDelegate.newState?.submitCode(code: "1234", delegate: resetPasswordVerifyDelegate)

        await fulfillment(of: [passwordRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(resetPasswordVerifyDelegate.onPasswordRequiredCalled)

        // Now submit the password...
        let resetPasswordCompletedExp = expectation(description: "reset password completed")
        let resetPasswordRequiredDelegate = ResetPasswordRequiredDelegateSpy(expectation: resetPasswordCompletedExp)

        if usingMockAPI {
            try await mockResponse(.ssprSubmitSuccess, endpoint: .resetPasswordSubmit)
        }

        resetPasswordVerifyDelegate.newPasswordRequiredState?.submitPassword(password: "password", delegate: resetPasswordRequiredDelegate)

        await fulfillment(of: [resetPasswordCompletedExp], timeout: defaultTimeout)
        XCTAssertTrue(resetPasswordRequiredDelegate.onResetPasswordCompletedCalled)
    }

    // SSPR - with automatic sign in
    func test_resetPassword_withAutomaticSignIn_succeeds() async throws {
        try XCTSkipIf(true) // TODO: Remove once we update to continuation_token

        let codeRequiredExp = expectation(description: "code required")
        let resetPasswordStartDelegate = ResetPasswordStartDelegateSpy(expectation: codeRequiredExp)

        if usingMockAPI {
            try await mockResponse(.ssprStartSuccess, endpoint: .resetPasswordStart)
        }

        sut.resetPassword(username: usernameOTP, delegate: resetPasswordStartDelegate)

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled)
        XCTAssertEqual(resetPasswordStartDelegate.channelTargetType, .email)
        XCTAssertFalse(resetPasswordStartDelegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(resetPasswordStartDelegate.codeLength)

        // Now submit the code...

        let passwordRequiredExp = expectation(description: "password required")
        let resetPasswordVerifyDelegate = ResetPasswordVerifyCodeDelegateSpy(expectation: passwordRequiredExp)

        if usingMockAPI {
            try await mockResponse(.ssprContinueSuccess, endpoint: .resetPasswordContinue)
        }

        resetPasswordStartDelegate.newState?.submitCode(code: "1234", delegate: resetPasswordVerifyDelegate)

        await fulfillment(of: [passwordRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(resetPasswordVerifyDelegate.onPasswordRequiredCalled)

        // Now submit the password...
        let resetPasswordCompletedExp = expectation(description: "reset password completed")
        let resetPasswordRequiredDelegate = ResetPasswordRequiredDelegateSpy(expectation: resetPasswordCompletedExp)

        if usingMockAPI {
            try await mockResponse(.ssprSubmitSuccess, endpoint: .resetPasswordSubmit)
        }

        resetPasswordVerifyDelegate.newPasswordRequiredState?.submitPassword(password: "password", delegate: resetPasswordRequiredDelegate)

        await fulfillment(of: [resetPasswordCompletedExp], timeout: defaultTimeout)
        XCTAssertTrue(resetPasswordRequiredDelegate.onResetPasswordCompletedCalled)

        // Now sign in...

        let signInAfterResetPasswordExp = expectation(description: "sign in after reset password")
        let signInAfterResetPasswordDelegate = SignInAfterResetPasswordDelegateSpy(expectation: signInAfterResetPasswordExp)

        if usingMockAPI {
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        resetPasswordRequiredDelegate.signInAfterResetPasswordState?.signIn(delegate: signInAfterResetPasswordDelegate)

        await fulfillment(of: [signInAfterResetPasswordExp], timeout: defaultTimeout)
        XCTAssertTrue(signInAfterResetPasswordDelegate.onSignInCompletedCalled)
        XCTAssertEqual(signInAfterResetPasswordDelegate.result?.account.username, usernameOTP)
        XCTAssertNotNil(signInAfterResetPasswordDelegate.result?.idToken)
        XCTAssertNil(signInAfterResetPasswordDelegate.result?.account.accountClaims)
        XCTAssertEqual(signInAfterResetPasswordDelegate.result?.scopes[0], "openid")
        XCTAssertEqual(signInAfterResetPasswordDelegate.result?.scopes[1], "offline_access")
    }
}
