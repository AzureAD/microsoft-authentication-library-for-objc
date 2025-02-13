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
import MSAL

final class MSALNativeAuthResetPasswordEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {
    // Hero Scenario 3.1.1. SSPR – without automatic sign in
    private let codeRetryCount = 3

    func test_resetPassword_withoutAutomaticSignIn_succeeds() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
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
        
        guard resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled else {
            XCTFail("onResetPasswordCodeRequired not called")
            return
        }
        
        XCTAssertEqual(resetPasswordStartDelegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(resetPasswordStartDelegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(resetPasswordStartDelegate.codeLength)

        // Now submit the code...
        let newPasswordRequiredState = await retrieveAndSubmitCode(resetPasswordStartDelegate: resetPasswordStartDelegate,
                   username: username,
                   retries: codeRetryCount)

        // Now submit the password...
        let resetPasswordCompletedExp = expectation(description: "reset password completed")
        let resetPasswordRequiredDelegate = ResetPasswordRequiredDelegateSpy(expectation: resetPasswordCompletedExp)

        let uniquePassword = generateRandomPassword()
        newPasswordRequiredState?.submitPassword(password: uniquePassword, delegate: resetPasswordRequiredDelegate)

        await fulfillment(of: [resetPasswordCompletedExp])
        XCTAssertTrue(resetPasswordRequiredDelegate.onResetPasswordCompletedCalled)
    }
        
    // User Case 3.1.3. SSPR – New password being set doesn’t meet password complexity requirements set on portal
    func test_resetPassword_passwordComplexity_error() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
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
        
        guard resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled else {
            XCTFail("onResetPasswordCodeRequired not called")
            return
        }
        
        XCTAssertEqual(resetPasswordStartDelegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(resetPasswordStartDelegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(resetPasswordStartDelegate.codeLength)

        // Now submit the code...
        let newPasswordRequiredState = await retrieveAndSubmitCode(resetPasswordStartDelegate: resetPasswordStartDelegate,
                   username: username,
                   retries: codeRetryCount)

        // Now submit the password...
        let resetPasswordCompletedExp = expectation(description: "reset password completed")
        let resetPasswordRequiredDelegate = ResetPasswordRequiredDelegateSpy(expectation: resetPasswordCompletedExp)

        let uniquePassword = "INVALID_Passwprd"
        newPasswordRequiredState?.submitPassword(password: uniquePassword, delegate: resetPasswordRequiredDelegate)

        await fulfillment(of: [resetPasswordCompletedExp])
        XCTAssertTrue(resetPasswordRequiredDelegate.onResetPasswordCompletedCalled)
    }
    
    // User Case 3.1.4 SSPR - Resend email OTP
    func test_resetPassword_resendCode_succeeds() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
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
        
        guard resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled else {
            XCTFail("onResetPasswordCodeRequired not called")
            return
        }
        
        // Now get code1...
        guard let code1 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }
        
        // Resend code
        let resendCodeRequiredExp = expectation(description: "code required again")
        let resetPasswordResendCodeDelegate = ResetPasswordResendCodeDelegateSpy(expectation: resendCodeRequiredExp)
        
        // Call resend code method
        resetPasswordStartDelegate.newState?.resendCode(delegate: resetPasswordResendCodeDelegate)
        
        await fulfillment(of: [resendCodeRequiredExp])
            
        // Verify that resend code method was called
        XCTAssertTrue(resetPasswordResendCodeDelegate.onResetPasswordResendCodeCodeRequiredCalled,
                          "Resend code method should have been called")
            
        // Now get code2...
        guard let code2 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }
        
        // Verify that the codes are different
        XCTAssertNotEqual(code1, code2, "Resent code should be different from the original code")
    }
    
    // User Case 3.1.5 SSPR - Email is not found in records
    func test_resetPassword_emailNotFound_error() async throws {
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForResetPassword()
        else {
            XCTFail("Missing information")
            return
        }
        
        let resetPasswordFailureExp = expectation(description: "reset password user not found")
        let resetPasswordStartDelegate = ResetPasswordStartDelegateSpy(expectation: resetPasswordFailureExp)
        
        sut.resetPassword(username: username, delegate: resetPasswordStartDelegate)
        
        await fulfillment(of: [resetPasswordFailureExp])
        
        // Verify error condition
        XCTAssertTrue(resetPasswordStartDelegate.onResetPasswordErrorCalled)
        XCTAssertEqual(resetPasswordStartDelegate.error?.isUserNotFound, true)
    }
    
    // User Case 3.1.6 SSPR - When SSPR requires a challenge type not supported by the client, redirect to web-fallback
    func test_resetPassword_webfallback_error() async throws {
        guard let sut = initialisePublicClientApplication(challengeTypes: [.password]),
              let username = retrieveUsernameForResetPassword()
        else {
            XCTFail("Missing information")
            return
        }
        
        let resetPasswordFailureExp = expectation(description: "reset password web-fallback")
        let resetPasswordStartDelegate = ResetPasswordStartDelegateSpy(expectation: resetPasswordFailureExp)
        
        sut.resetPassword(username: username, delegate: resetPasswordStartDelegate)
        
        await fulfillment(of: [resetPasswordFailureExp])
        
        // Verify error condition
        XCTAssertTrue(resetPasswordStartDelegate.onResetPasswordErrorCalled)
        XCTAssertEqual(resetPasswordStartDelegate.error?.isBrowserRequired, true)
    }
    
    // User Case 3.1.8 SSPR – Email exists but not linked to any password
    // Not applicable
    
    // User Case 3.1.9 - Email exists but signup method was OTP, social, etc.
    func test_resetPassword_socialAccount_error() async throws {
        throw XCTSkip("Skipping test as it requires a Social account, not present in MSIDLAB")
        
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }
        
        let username = "invalid"
        
        let resetPasswordFailureExp = expectation(description: "reset password user not found")
        let resetPasswordStartDelegate = ResetPasswordStartDelegateSpy(expectation: resetPasswordFailureExp)
        
        sut.resetPassword(username: username, delegate: resetPasswordStartDelegate)
        
        await fulfillment(of: [resetPasswordFailureExp])
        
        // Verify error condition
        XCTAssertTrue(resetPasswordStartDelegate.onResetPasswordErrorCalled)
        XCTAssertEqual(resetPasswordStartDelegate.error?.isInvalidUsername, true)
    }

    // SSPR - with automatic sign in
    func test_resetPassword_withAutomaticSignIn_succeeds() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
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
        
        guard resetPasswordStartDelegate.onResetPasswordCodeRequiredCalled else {
            XCTFail("onResetPasswordCodeRequired not called")
            return
        }
        
        XCTAssertEqual(resetPasswordStartDelegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(resetPasswordStartDelegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(resetPasswordStartDelegate.codeLength)

        // Now submit the code...
        let newPasswordRequiredState = await retrieveAndSubmitCode(resetPasswordStartDelegate: resetPasswordStartDelegate,
                   username: username,
                   retries: codeRetryCount)

        // Now submit the password...
        let resetPasswordCompletedExp = expectation(description: "reset password completed")
        let resetPasswordRequiredDelegate = ResetPasswordRequiredDelegateSpy(expectation: resetPasswordCompletedExp)

        let uniquePassword = generateRandomPassword()
        newPasswordRequiredState?.submitPassword(password: uniquePassword, delegate: resetPasswordRequiredDelegate)

        await fulfillment(of: [resetPasswordCompletedExp])
        XCTAssertTrue(resetPasswordRequiredDelegate.onResetPasswordCompletedCalled)
        
        guard resetPasswordRequiredDelegate.onResetPasswordCompletedCalled else {
            XCTFail("onResetPasswordCompleted not called")
            return
        }

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

    // This method tries to fetch a code from 1secmail API and submit it
    private func retrieveAndSubmitCode(resetPasswordStartDelegate: ResetPasswordStartDelegateSpy, username: String, retries: Int) async -> ResetPasswordRequiredState? {
        let passwordRequiredExp = expectation(description: "password required")
        let resetPasswordVerifyDelegate = ResetPasswordVerifyCodeDelegateSpy(expectation: passwordRequiredExp)

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code not retrieved from email")
            return nil
        }

        resetPasswordStartDelegate.newState?.submitCode(code: code, delegate: resetPasswordVerifyDelegate)

        await fulfillment(of: [passwordRequiredExp])
        if resetPasswordVerifyDelegate.onResetPasswordVerifyCodeErrorCalled && resetPasswordVerifyDelegate.error?.isInvalidCode == true && retries > 0 {
            return await retrieveAndSubmitCode(resetPasswordStartDelegate: resetPasswordStartDelegate, username: username, retries: retries - 1)
        }
        guard resetPasswordVerifyDelegate.onPasswordRequiredCalled else {
            XCTFail("onPasswordRequired not called")
            return nil
        }
        return resetPasswordVerifyDelegate.newPasswordRequiredState
    }
}
