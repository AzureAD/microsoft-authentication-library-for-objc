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

    private func checkSignUpStartDelegate(_ delegate: SignUpStartDelegateSpy) {
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(delegate.codeLength)
    }

    private func checkSignInAfterSignUpDelegate(_ delegate: SignInAfterSignUpDelegateSpy, username: String) {
        XCTAssertTrue(delegate.onSignInCompletedCalled)
        XCTAssertEqual(delegate.result?.account.username, username)
        XCTAssertNotNil(delegate.result?.idToken)
    }
}
