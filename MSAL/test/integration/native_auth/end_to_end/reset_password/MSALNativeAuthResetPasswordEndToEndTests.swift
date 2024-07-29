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

final class MSALNativeAuthResetPasswordEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {
    // Hero Scenario 3.1.1. SSPR – without automatic sign in
    func test_resetPassword_withoutAutomaticSignIn_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForResetPassword()
        else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let resetPasswordStartDelegate = ResetPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.resetPassword(username: username, delegate: resetPasswordStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        XCTAssertTrue(resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled)
        XCTAssertEqual(resetPasswordStartDelegate.channelTargetType, .email)
        XCTAssertFalse(resetPasswordStartDelegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(resetPasswordStartDelegate.codeLength)

        // Now submit the code...

        let passwordRequiredExp = expectation(description: "password required")
        let resetPasswordVerifyDelegate = ResetPasswordVerifyCodeDelegateSpy(expectation: passwordRequiredExp)
        
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        resetPasswordStartDelegate.newState?.submitCode(code: code, delegate: resetPasswordVerifyDelegate)

        await fulfillment(of: [passwordRequiredExp])
        XCTAssertTrue(resetPasswordVerifyDelegate.onPasswordRequiredCalled)

        // Now submit the password...
        let resetPasswordCompletedExp = expectation(description: "reset password completed")
        let resetPasswordRequiredDelegate = ResetPasswordRequiredDelegateSpy(expectation: resetPasswordCompletedExp)

        let uniquePassword = "password.\(Date().timeIntervalSince1970)"
        resetPasswordVerifyDelegate.newPasswordRequiredState?.submitPassword(password: uniquePassword, delegate: resetPasswordRequiredDelegate)

        await fulfillment(of: [resetPasswordCompletedExp])
        XCTAssertTrue(resetPasswordRequiredDelegate.onResetPasswordCompletedCalled)
    }

    // SSPR - with automatic sign in
    func test_resetPassword_withAutomaticSignIn_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForResetPassword()
        else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let resetPasswordStartDelegate = ResetPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.resetPassword(username: username, delegate: resetPasswordStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        XCTAssertTrue(resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled)
        XCTAssertEqual(resetPasswordStartDelegate.channelTargetType, .email)
        XCTAssertFalse(resetPasswordStartDelegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(resetPasswordStartDelegate.codeLength)

        // Now submit the code...

        let passwordRequiredExp = expectation(description: "password required")
        let resetPasswordVerifyDelegate = ResetPasswordVerifyCodeDelegateSpy(expectation: passwordRequiredExp)
        
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        resetPasswordStartDelegate.newState?.submitCode(code: code, delegate: resetPasswordVerifyDelegate)

        await fulfillment(of: [passwordRequiredExp])
        XCTAssertTrue(resetPasswordVerifyDelegate.onPasswordRequiredCalled)

        // Now submit the password...
        let resetPasswordCompletedExp = expectation(description: "reset password completed")
        let resetPasswordRequiredDelegate = ResetPasswordRequiredDelegateSpy(expectation: resetPasswordCompletedExp)

        let uniquePassword = "password.\(Date().timeIntervalSince1970)"
        resetPasswordVerifyDelegate.newPasswordRequiredState?.submitPassword(password: uniquePassword, delegate: resetPasswordRequiredDelegate)

        await fulfillment(of: [resetPasswordCompletedExp])
        XCTAssertTrue(resetPasswordRequiredDelegate.onResetPasswordCompletedCalled)

        // Now sign in...

        let signInAfterResetPasswordExp = expectation(description: "sign in after reset password")
        let signInAfterResetPasswordDelegate = SignInAfterResetPasswordDelegateSpy(expectation: signInAfterResetPasswordExp)

        resetPasswordRequiredDelegate.signInAfterResetPasswordState?.signIn(delegate: signInAfterResetPasswordDelegate)

        await fulfillment(of: [signInAfterResetPasswordExp])
        XCTAssertTrue(signInAfterResetPasswordDelegate.onSignInCompletedCalled)
        XCTAssertEqual(signInAfterResetPasswordDelegate.result?.account.username, username)
        XCTAssertNotNil(signInAfterResetPasswordDelegate.result?.idToken)
        XCTAssertNotNil(signInAfterResetPasswordDelegate.result?.account.accountClaims)
    }
}
