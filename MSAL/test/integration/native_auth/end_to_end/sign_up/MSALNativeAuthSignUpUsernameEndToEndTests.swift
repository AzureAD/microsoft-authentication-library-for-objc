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

import XCTest
import MSAL

final class MSALNativeAuthSignUpUsernameEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {

    // Hero Scenario 2.1.1. Sign up – with Email Verification (Email & Email OTP)
    func test_signUpWithCode_withEmailVerification_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()

        sut.signUp(username: usernameOTP, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("OTP not sent")
            return
        }
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)
        guard let code = await retrieveCodeFor(email: usernameOTP) else {
            XCTFail("OTP code not retrieved from email")
            return
        }
        
        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }

    // Hero Scenario 2.1.2. Sign up – with Email Verification as LAST step & Custom Attributes (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .codeAndAttributes) else {
            XCTFail("OTP code not retrieved from email")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        sut.signUp(username: usernameOTP, attributes: AttributesStub.allAttributes, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)
        
        guard let code = await retrieveCodeFor(email: usernameOTP) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }

    // Hero Scenario 2.1.3. Sign up – with Email Verification as FIRST step & Custom Attributes (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .codeAndAttributes) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        sut.signUp(username: usernameOTP, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let submitCodeExp = expectation(description: "submit code")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: submitCodeExp)

        guard let code = await retrieveCodeFor(email: usernameOTP) else {
            XCTFail("OTP code not retrieved from email")
            return
        }
        
        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [submitCodeExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes...

        let attributesExp = expectation(description: "submit attributes, sign-up complete")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesExp)

        signUpVerifyCodeDelegate.attributesRequiredNewState?.submitAttributes(
            attributes: AttributesStub.allAttributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesExp])
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }

    // Hero Scenario 2.1.4. Sign up – with Email Verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsFirstStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .codeAndAttributes) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        sut.signUp(username: usernameOTP, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("OTP not sent")
            return
        }
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let submitCodeExp = expectation(description: "submit code")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: submitCodeExp)
        
        guard let code = await retrieveCodeFor(email: usernameOTP) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [submitCodeExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes...

        let submitAttributesExp1 = expectation(description: "submit attributes 1")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: submitAttributesExp1)

        signUpVerifyCodeDelegate.attributesRequiredNewState?.submitAttributes(
            attributes: AttributesStub.attribute1,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [submitAttributesExp1])
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpAttributesRequiredErrorCalled)

        // Now submit more attributes...

        let submitAttributesExp2 = expectation(description: "submit attributes 2, sign-up complete")
        signUpAttributesRequiredDelegate.expectation = submitAttributesExp2

        signUpAttributesRequiredDelegate.attributesRequiredState?.submitAttributes(
            attributes: AttributesStub.attribute2,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [submitAttributesExp2])
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }
    
    // use case 2.1.5. Sign up - with Email & Password, resend email OTP
    func test_signUpWithEmailOTP_resendEmail_success() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }
            
        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
            
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
            
        sut.signUp(
            username: username,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )
            
        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)
        
        // Now get code1...
        guard let code1 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }
        
        // Resend code
        let resendCodeRequiredExp = expectation(description: "code required again")
        let signUpResendCodeDelegate = SignUpResendCodeDelegateSpy(expectation: resendCodeRequiredExp)
        
        // Call resend code method
        signUpStartDelegate.newState?.resendCode(delegate: signUpResendCodeDelegate)
        
        await fulfillment(of: [resendCodeRequiredExp])
            
        // Verify that resend code method was called
        XCTAssertTrue(signUpResendCodeDelegate.onSignUpResendCodeCodeRequiredCalled,
                          "Resend code method should have been called")
            
        // Now get code2...
        guard let code2 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }
        
        // Verify that the codes are different
        XCTAssertNotEqual(code1, code2, "Resent code should be different from the original code")
    }
    
    // use case 2.1.6. Sign Up - with Email & OTP, User already exists with given email as email-otp account
    func test_signUpWithEmailOTP_andExistingAccount() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code), let username = retrieveUsernameForSignInCode() else {
            XCTFail("Missing information")
            return
        }
        
        let signUpFailureExp = expectation(description: "sign-up with invalid email fails")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: signUpFailureExp)
        
        sut.signUp(
            username: username,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [signUpFailureExp])
        
        // Verify error condition
        XCTAssertTrue(signUpStartDelegate.onSignUpErrorCalled)
        XCTAssertTrue(signUpStartDelegate.error!.isUserAlreadyExists)
    }

    // Hero Scenario 2.1.9. Sign up – without automatic sign in (Email & Email OTP)
    func test_signUpWithoutAutomaticSignIn() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        sut.signUp(username: usernameOTP, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("OTP not sent")
            return
        }
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)
        guard let code = await retrieveCodeFor(email: usernameOTP) else {
            XCTFail("OTP code not retrieved from email")
            return
        }

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)
    }
    
    // Use case 2.1.10 Sign up - with Email & Password, Server requires password authentication, which is not supported by the developer (aka redirect flow)
    func test_signUpWithEmailPassword_butChallengeTypeOOB_fails() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code, challengeTypes: [.OOB]) else {
            XCTFail("Missing information")
            return
        }
        
        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        
        let signUpFailureExp = expectation(description: "sign-up with invalid email fails")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: signUpFailureExp)
        
        sut.signUp(
            username: username,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [signUpFailureExp])
        
        // Verify error condition
        XCTAssertTrue(signUpStartDelegate.error!.isBrowserRequired)
    }
    
    // Hero Scenario 2.1.11. Sign up – Server requires password authentication, which is supported by the developer
    // The same as 1.1.4
    func test_signUpWithCode_withPasswordConfiguration_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        
        sut.signUp(username: username, correlationId: correlationId, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("OTP not sent")
            return
        }
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let submitCodeExp = expectation(description: "submit code, credential required")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: submitCodeExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [submitCodeExp])

        guard signUpVerifyCodeDelegate.onSignUpPasswordRequiredCalled else {
            XCTFail("onSignUpPasswordRequired not called")
            return
        }

        // Now submit the password...

        let passwordRequiredExp = expectation(description: "password required")
        let signUpPasswordDelegate = SignUpPasswordRequiredDelegateSpy(expectation: passwordRequiredExp)

        signUpVerifyCodeDelegate.passwordRequiredState?.submitPassword(
            password: password,
            delegate: signUpPasswordDelegate
        )

        await fulfillment(of: [passwordRequiredExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)
    }
    

    private func checkSignUpStartDelegate(_ delegate: SignUpStartDelegateSpy) {
        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(delegate.codeLength)
    }

    private func checkSignInAfterSignUpDelegate(_ delegate: SignInAfterSignUpDelegateSpy, username: String) {
        XCTAssertTrue(delegate.onSignInCompletedCalled)
        XCTAssertEqual(delegate.result?.account.username, username)
        XCTAssertNotNil(delegate.result?.idToken)
    }
}
