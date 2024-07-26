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

final class MSALNativeAuthSignUpUsernameAndPasswordEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {

    // Hero Scenario 1.1.1. Sign up - with Email verification as LAST step (Email & Password)
    func test_signUpWithPassword_withEmailVerificationLastStep_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: username,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario 1.1.3. Sign up - with Email verification as LAST step & Custom Attributes (Email & Password)
    // DJB: Re-test when admin-consent is granted
    func test_signUpWithPassword_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        guard
            let sut = initialisePublicClientApplication(clientIdType: .passwordAndAttributes),
            let password = await retrievePasswordForSignInUsername()
        else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let attributes = [
            "city": "Dublin",
            "country": "Ireland"
        ]

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: username,
            password: password,
            attributes: attributes,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario 1.1.4. Sign up - with Email verification as FIRST step (Email & Password)
    func test_signUpWithPassword_withEmailVerificationAsFirstStepAndThenSetPassword_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: username,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let credentialRequiredExp = expectation(description: "credential required")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: credentialRequiredExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [credentialRequiredExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpPasswordRequiredCalled)

        // Now submit the password...

        let passwordRequiredExp = expectation(description: "password required")
        let signUpPasswordDelegate = SignUpPasswordRequiredDelegateSpy(expectation: passwordRequiredExp)

        signUpVerifyCodeDelegate.passwordRequiredState?.submitPassword(
            password: password,
            delegate: signUpPasswordDelegate
        )

        await fulfillment(of: [passwordRequiredExp])
        XCTAssertTrue(signUpPasswordDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpPasswordDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario 1.1.6. Sign up - with Email verification as FIRST step & Custom Attribute (Email & Password)
    // DJB: Re-test when admin-consent is granted
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        guard
            let sut = initialisePublicClientApplication(clientIdType: .passwordAndAttributes),
            let password = await retrievePasswordForSignInUsername() 
        else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        let username = generateSignUpRandomEmail()
        let attributes = [
            "city": "Dublin",
            "country": "Ireland"
        ]

        sut.signUp(
            username: username,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
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
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpPasswordRequiredCalled)

        // Now submit the password...

        let passwordRequiredExp = expectation(description: "password required")
        let signUpPasswordDelegate = SignUpPasswordRequiredDelegateSpy(expectation: passwordRequiredExp)

        signUpVerifyCodeDelegate.passwordRequiredState?.submitPassword(
            password: password,
            delegate: signUpPasswordDelegate
        )

        await fulfillment(of: [passwordRequiredExp])
        XCTAssertTrue(signUpPasswordDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes...

        let attributesRequiredExp = expectation(description: "attributes required, sign-up complete")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesRequiredExp)

        signUpPasswordDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp])
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario xxx. Sign up - with Email verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Password)
    // DJB: Re-test when admin-consent is granted
    // DJB: This Hero scenario doesn't exist in the AC doc (only exists the OOB one)
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        guard
            let sut = initialisePublicClientApplication(clientIdType: .passwordAndAttributes),
            let password = await retrievePasswordForSignInUsername()
        else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let attributesScreen1 = ["city": "Dublin"]
        let attributesScreen2 = ["country": "Ireland"]

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: username,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
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
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpPasswordRequiredCalled)

        // Now submit the password...

        let passwordRequiredExp = expectation(description: "password required")
        let signUpPasswordDelegate = SignUpPasswordRequiredDelegateSpy(expectation: passwordRequiredExp)

        signUpVerifyCodeDelegate.passwordRequiredState?.submitPassword(
            password: password,
            delegate: signUpPasswordDelegate
        )

        await fulfillment(of: [passwordRequiredExp])
        XCTAssertTrue(signUpPasswordDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes in screen 1...

        let attributesRequiredExp1 = expectation(description: "attributes required screen 1")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesRequiredExp1)

        signUpPasswordDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributesScreen1,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp1])
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpAttributesRequiredErrorCalled)

        // Now submit attributes in screen 2...

        let attributesRequiredExp2 = expectation(description: "attributes required screen 2")
        signUpAttributesRequiredDelegate.expectation = attributesRequiredExp2

        signUpAttributesRequiredDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributesScreen2,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp2])
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario xxx Sign up – without automatic sign in (Email & Password)
    // DJB: the scenario doesn't exist in AC doc
    func test_signUpWithPasswordWithoutAutomaticSignIn() async throws {
        guard let sut = initialisePublicClientApplication(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: username,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)
    }

    private func checkSignUpStartDelegate(_ delegate: SignUpPasswordStartDelegateSpy) {
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(delegate.codeLength)
    }

    private func checkSignInAfterSignUpDelegate(_ delegate: SignInAfterSignUpDelegateSpy, expectedUsername: String) {
        XCTAssertTrue(delegate.onSignInCompletedCalled)
        XCTAssertEqual(delegate.result?.account.username, expectedUsername)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertNotNil(delegate.result?.account.accountClaims)
    }
}
