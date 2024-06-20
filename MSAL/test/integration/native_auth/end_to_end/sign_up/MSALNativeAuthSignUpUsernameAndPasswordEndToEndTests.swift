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

final class MSALNativeAuthSignUpUsernameAndPasswordEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {
    private let usernamePassword = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"
    private let password = ProcessInfo.processInfo.environment["existingUserPassword"] ?? "<existingUserPassword not set>"
    private let attributes = ["age": 40]
    
    // Hero Scenario 2.1.1. Sign up - with Email verification as LAST step (Email & Password)
    func test_signUpWithPassword_withEmailVerificationLastStep_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: usernamePassword,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 2.1.2. Sign up - with Email verification as LAST step & Custom Attributes (Email & Password)
    func test_signUpWithPassword_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: usernamePassword,
            password: "1234",
            attributes: attributes,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 2.1.3. Sign up - with Email verification as FIRST step (Email & Password)
    func test_signUpWithPassword_withEmailVerificationAsFirstStep_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: usernamePassword,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let credentialRequiredExp = expectation(description: "credential required")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: credentialRequiredExp)

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [credentialRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpPasswordRequiredCalled)

        // Now submit the password...

        let attributesRequiredExp = expectation(description: "attributes required")
        let signUpPasswordDelegate = SignUpPasswordRequiredDelegateSpy(expectation: attributesRequiredExp)

        signUpVerifyCodeDelegate.passwordRequiredState?.submitPassword(
            password: "1234",
            delegate: signUpPasswordDelegate
        )

        await fulfillment(of: [attributesRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpPasswordDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpPasswordDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 2.1.4. Sign up - with Email verification as FIRST step & Custom Attribute (Email & Password)
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: usernamePassword,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let submitCodeExp = expectation(description: "submit code, credential required")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: submitCodeExp)

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [submitCodeExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpPasswordRequiredCalled)

        // Now submit the password...

        let passwordRequiredExp = expectation(description: "password required")
        let signUpPasswordDelegate = SignUpPasswordRequiredDelegateSpy(expectation: passwordRequiredExp)

        signUpVerifyCodeDelegate.passwordRequiredState?.submitPassword(
            password: "1234",
            delegate: signUpPasswordDelegate
        )

        await fulfillment(of: [passwordRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpPasswordDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes...

        let attributesRequiredExp = expectation(description: "attributes required, sign-up complete")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesRequiredExp)

        signUpPasswordDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }
    
    // Hero Scenario 2.2.2. Sign in – Email and Password on MULTIPLE screens (Email & Password)
    func test_signInAndSendingCorrectPasswordResultsInSuccess() async throws {
        guard let sut = initialisePublicClientApplication(useEmailPasswordClientId: false) else {
            return
        }
        
        let signInExpectation = expectation(description: "signing in")
        let passwordRequiredExpectation = expectation(description: "verifying password")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInPasswordRequiredDelegateSpy = SignInPasswordRequiredDelegateSpy(expectation: passwordRequiredExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"
        let password = ProcessInfo.processInfo.environment["existingUserPassword"] ?? "<existingUserPassword not set>"

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)

        // Now submit the password..

        signInDelegateSpy.newStatePasswordRequired?.submitPassword(password: password, delegate: signInPasswordRequiredDelegateSpy)

        await fulfillment(of: [passwordRequiredExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInPasswordRequiredDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInPasswordRequiredDelegateSpy.result?.idToken)
        XCTAssertEqual(signInPasswordRequiredDelegateSpy.result?.account.username, username)
    }

    // Hero Scenario 2.1.5. Sign up - with Email verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Password)
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: usernamePassword,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let submitCodeExp = expectation(description: "submit code, credential required")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: submitCodeExp)

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [submitCodeExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpPasswordRequiredCalled)

        // Now submit the password...

        let attributesRequiredExp1 = expectation(description: "attributes required 1")
        let signUpPasswordDelegate = SignUpPasswordRequiredDelegateSpy(expectation: attributesRequiredExp1)

        signUpVerifyCodeDelegate.passwordRequiredState?.submitPassword(
            password: "1234",
            delegate: signUpPasswordDelegate
        )

        await fulfillment(of: [attributesRequiredExp1], timeout: defaultTimeout)
        XCTAssertTrue(signUpPasswordDelegate.onSignUpAttributesRequiredCalled)

        // Now submit the attributes...

        let attributesRequiredExp2 = expectation(description: "attributes required 2, sign-up complete")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesRequiredExp2)

        signUpPasswordDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp2], timeout: defaultTimeout)
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpAttributesRequiredErrorCalled)

        // Now submit more attributes...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        signUpAttributesRequiredDelegate.expectation = signUpCompleteExp

        signUpAttributesRequiredDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [signUpCompleteExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpAttributesRequiredDelegate.onSignUpCompletedCalled)

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp], timeout: defaultTimeout)
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate)
    }

    // Hero Scenario 2.1.6. Sign up – without automatic sign in (Email & Password)
    func test_signUpWithPasswordWithoutAutomaticSignIn() async throws {
        guard let sut = initialisePublicClientApplication() else {
            return
        }
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: usernamePassword,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp], timeout: defaultTimeout)
        checkSignUpStartDelegate(signUpStartDelegate)

        // Now submit the code...

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: "1234", delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp], timeout: defaultTimeout)
        XCTAssertTrue(signUpVerifyCodeDelegate.onSignUpCompletedCalled)
    }
    
    func test_signInAndSendingIncorrectPasswordResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(useEmailPasswordClientId: false) else {
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let passwordRequiredExpectation = expectation(description: "verifying password")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInPasswordRequiredDelegateSpy = SignInPasswordRequiredDelegateSpy(expectation: passwordRequiredExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)

        // Now submit the password..

        signInDelegateSpy.newStatePasswordRequired?.submitPassword(password: "An Invalid Password", delegate: signInPasswordRequiredDelegateSpy)

        await fulfillment(of: [passwordRequiredExpectation], timeout: defaultTimeout)

        XCTAssertTrue(signInPasswordRequiredDelegateSpy.onSignInPasswordRequiredErrorCalled)
        XCTAssertEqual(signInPasswordRequiredDelegateSpy.error?.isInvalidPassword, true)
    }

    private func checkSignUpStartDelegate(_ delegate: SignUpPasswordStartDelegateSpy) {
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(delegate.codeLength)
    }

    private func checkSignInAfterSignUpDelegate(_ delegate: SignInAfterSignUpDelegateSpy) {
        XCTAssertTrue(delegate.onSignInCompletedCalled)
        XCTAssertEqual(delegate.result?.account.username, usernamePassword)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertNil(delegate.result?.account.accountClaims)
    }
}
