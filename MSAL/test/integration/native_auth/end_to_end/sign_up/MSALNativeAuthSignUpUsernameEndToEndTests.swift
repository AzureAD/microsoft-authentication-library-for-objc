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
        throw XCTSkip("Retrieving OTP failure")
        
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        let signInparam = MSALNativeAuthSignUpParameters(username: usernameOTP)
        signInparam.correlationId = correlationId

        sut.signUp(parameters: signInparam, delegate: signUpStartDelegate)

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
        
        let autoParam = MSALNativeAuthSignInAfterSignUpParameters()
        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(parameters: autoParam, delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }

    // Hero Scenario 2.1.2. Sign up – with Email Verification as LAST step & Custom Attributes (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
        guard let sut = initialisePublicClientApplication(clientIdType: .codeAndAttributes) else {
            XCTFail("OTP code not retrieved from email")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        let param = MSALNativeAuthSignUpParameters(username: usernameOTP)
        param.attributes = AttributesStub.allAttributes
        param.correlationId = correlationId
        
        sut.signUp(parameters: param, delegate: signUpStartDelegate)

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
        
        let autoParam = MSALNativeAuthSignInAfterSignUpParameters()
        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(parameters: autoParam, delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }

    // Hero Scenario 2.1.3. Sign up – with Email Verification as FIRST step & Custom Attributes (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
        guard let sut = initialisePublicClientApplication(clientIdType: .codeAndAttributes) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: usernameOTP)
        signUpParam.correlationId = correlationId
        sut.signUp(parameters: signUpParam, delegate: signUpStartDelegate)

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
        
        let autoParam = MSALNativeAuthSignInAfterSignUpParameters()
        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(parameters: autoParam, delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }

    // Hero Scenario 2.1.4. Sign up – with Email Verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Email OTP)
    func test_signUpWithCode_withEmailVerificationAsFirstStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
        guard let sut = initialisePublicClientApplication(clientIdType: .codeAndAttributes) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: usernameOTP)
        signUpParam.correlationId = correlationId
        sut.signUp(parameters: signUpParam, delegate: signUpStartDelegate)

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

        let autoParam = MSALNativeAuthSignInAfterSignUpParameters()
        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(parameters: autoParam, delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, username: usernameOTP)
    }
    
    // use case 2.1.5. Sign up - with Email & OTP resend email OTP
    func test_signUpWithEmailOTP_resendEmail_success() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }
            
        let username = generateSignUpRandomEmail()
            
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.correlationId = correlationId
            
        sut.signUp(
            parameters: signUpParam,
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
        
        let signUpFailureExp = expectation(description: "sign-up with existing email fails")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: signUpFailureExp)
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.correlationId = correlationId
        
        sut.signUp(
            parameters: signUpParam,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [signUpFailureExp])
        
        // Verify error condition
        XCTAssertTrue(signUpStartDelegate.onSignUpErrorCalled)
        XCTAssertEqual(signUpStartDelegate.error?.isUserAlreadyExists, true)
    }
    
    // Use case 2.1.7. Sign up - with Email & Password, User already exists with given email as social account
    func test_signUpWithEmailPassword_socialAccount_fails() async throws {
        throw XCTSkip("Skipping test as it requires a Social account, not present in MSIDLAB")
        
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }
        
        let username = "invalid"
        let password = generateRandomPassword()
        
        let signUpFailureExp = expectation(description: "sign-up with social account email fails")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: signUpFailureExp)
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.password = password
        signUpParam.correlationId = correlationId
        
        sut.signUp(
            parameters: signUpParam,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [signUpFailureExp])
        
        // Verify error condition
        XCTAssertTrue(signUpStartDelegate.onSignUpPasswordErrorCalled)
        XCTAssertEqual(signUpStartDelegate.error?.isInvalidUsername, true)
    }
    
    // Use case 2.1.8. Sign up - with Email & OTP, Developer makes a request with invalid format email address
    func test_signUpWithEmailPassword_invalidEmailFormat_fails() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }
        
        let username = "invalid"
        
        let signUpFailureExp = expectation(description: "sign-up with invalid email format fails")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: signUpFailureExp)
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.correlationId = correlationId
        
        sut.signUp(
            parameters: signUpParam,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [signUpFailureExp])
        
        // Verify error condition
        XCTAssertTrue(signUpStartDelegate.onSignUpPasswordErrorCalled)
        XCTAssertEqual(signUpStartDelegate.error?.isInvalidUsername, true)
    }

    // Hero Scenario 2.1.9. Sign up – without automatic sign in (Email & Email OTP)
    func test_signUpWithoutAutomaticSignIn() async throws {
        throw XCTSkip("Retrieving OTP failure")
        
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpStartDelegateSpy(expectation: codeRequiredExp)
        let usernameOTP = generateSignUpRandomEmail()
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: usernameOTP)
        signUpParam.correlationId = correlationId
        
        sut.signUp(parameters: signUpParam, delegate: signUpStartDelegate)

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
        guard let sut = initialisePublicClientApplication(clientIdType: .password, challengeTypes: [.OOB]) else {
            XCTFail("Missing information")
            return
        }
        
        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        
        let signUpFailureExp = expectation(description: "sign-up with invalid challenge type fails")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: signUpFailureExp)
        
        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.password = password
        signUpParam.correlationId = correlationId
        
        sut.signUp(
            parameters: signUpParam,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [signUpFailureExp])
        
        // Verify error condition
        XCTAssertTrue(signUpStartDelegate.error!.isBrowserRequired)
    }
    
    // Hero Scenario 2.1.11. Sign up – Server requires password authentication, which is supported by the developer
    // The same as 1.1.4

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
