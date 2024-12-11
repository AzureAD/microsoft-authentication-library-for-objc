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

    // Hero Scenario 1.1.1. Sign up - with Email verification as LAST step (Email & Password)
    func test_signUpWithPassword_withEmailVerificationLastStep_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()

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

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])

        guard signUpVerifyCodeDelegate.onSignUpCompletedCalled else {
            XCTFail("onSignUpCompleted not called")
            return
        }

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario 1.1.3. Sign up - with Email verification as LAST step & Custom Attributes (Email & Password)
    func test_signUpWithPassword_withEmailVerificationAsLastStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .passwordAndAttributes) else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        let attributes = AttributesStub.allAttributes

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

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])

        guard signUpVerifyCodeDelegate.onSignUpCompletedCalled else {
            XCTFail("onSignUpCompleted not called")
            return
        }

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario 1.1.4. Sign up - with Email verification as FIRST step (Email & Password)
    func test_signUpWithPassword_withEmailVerificationAsFirstStepAndThenSetPassword_succeeds() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: username,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let credentialRequiredExp = expectation(description: "credential required")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: credentialRequiredExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [credentialRequiredExp])

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

        guard signUpPasswordDelegate.onSignUpCompletedCalled else {
            XCTFail("onSignUpCompleted not called")
            return
        }

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpPasswordDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Hero Scenario 1.1.6. Sign up - with Email verification as FIRST step & Custom Attribute (Email & Password)
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributes_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .passwordAndAttributes) else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        let attributes = AttributesStub.allAttributes

        sut.signUp(
            username: username,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

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

        guard signUpPasswordDelegate.onSignUpAttributesRequiredCalled else {
            XCTFail("onSignUpAttributesRequired not called")
            return
        }

        // Now submit the attributes...

        let attributesRequiredExp = expectation(description: "attributes required, sign-up complete")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesRequiredExp)

        signUpPasswordDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributes,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp])

        guard signUpAttributesRequiredDelegate.onSignUpCompletedCalled else {
            XCTFail("onSignUpCompleted not called")
            return
        }

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Sign up - with Email verification as FIRST step & Custom Attributes over MULTIPLE screens (Email & Password)
    func test_signUpWithPasswordWithEmailVerificationAsFirstStepAndCustomAttributesOverMultipleScreens_succeeds() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .passwordAndAttributes) else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        let attributesScreen1 = AttributesStub.attribute1
        let attributesScreen2 = AttributesStub.attribute2

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        sut.signUp(
            username: username,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

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

        guard signUpPasswordDelegate.onSignUpAttributesRequiredCalled else {
            XCTFail("onSignUpAttributesRequired not called")
            return
        }

        // Now submit the attributes in screen 1...

        let attributesRequiredExp1 = expectation(description: "attributes required screen 1")
        let signUpAttributesRequiredDelegate = SignUpAttributesRequiredDelegateSpy(expectation: attributesRequiredExp1)

        signUpPasswordDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributesScreen1,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp1])

        guard signUpAttributesRequiredDelegate.onSignUpAttributesRequiredErrorCalled else {
            XCTFail("expected onSignUpAttributesRequiredError not called")
            return
        }

        // Now submit attributes in screen 2...

        let attributesRequiredExp2 = expectation(description: "attributes required screen 2")
        signUpAttributesRequiredDelegate.expectation = attributesRequiredExp2

        signUpAttributesRequiredDelegate.attributesRequiredState?.submitAttributes(
            attributes: attributesScreen2,
            delegate: signUpAttributesRequiredDelegate
        )

        await fulfillment(of: [attributesRequiredExp2])

        guard signUpAttributesRequiredDelegate.onSignUpCompletedCalled else {
            XCTFail("onSignUpCompleted not called")
            return
        }

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpAttributesRequiredDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)
    }

    // Sign up – without automatic sign in (Email & Password)
    func test_signUpWithPasswordWithoutAutomaticSignIn() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()

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

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

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
    
    // Use case 1.1.10. Sign up - with Email & Password, Sign Out, Attempt SignUp with same Email
    func test_signUpWithEmailPassword_andAgainSameEmail_fails() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()

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

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

        // Now submit the code...

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])

        guard signUpVerifyCodeDelegate.onSignUpCompletedCalled else {
            XCTFail("onSignUpCompleted not called")
            return
        }

        // Now sign in...

        let signInExp = expectation(description: "sign-in after sign-up")
        let signInAfterSignUpDelegate = SignInAfterSignUpDelegateSpy(expectation: signInExp)

        signUpVerifyCodeDelegate.signInAfterSignUpState?.signIn(delegate: signInAfterSignUpDelegate)

        await fulfillment(of: [signInExp])
        checkSignInAfterSignUpDelegate(signInAfterSignUpDelegate, expectedUsername: username)

        // Now sign out...

        guard signInAfterSignUpDelegate.onSignInCompletedCalled else {
            XCTFail("onSignInCompleted not called")
            return
        }

        signInAfterSignUpDelegate.result?.signOut()

        // Now we attempt to sign up again with same email
        let newPassword = generateRandomPassword()

        let newCodeRequiredExp = expectation(description: "code required")
        let newSignUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: newCodeRequiredExp)

        sut.signUp(
            username: username,
            password: newPassword,
            correlationId: correlationId,
            delegate: newSignUpStartDelegate
        )

        await fulfillment(of: [newCodeRequiredExp])
        XCTAssertTrue(newSignUpStartDelegate.onSignUpPasswordErrorCalled)
        XCTAssertTrue(newSignUpStartDelegate.error!.isUserAlreadyExists)
    }
    
    // Use case 1.1.12. Sign up - with Email & Password, Developer makes a request with invalid format email address
    func test_signUpWithEmailPassword_invalidEmail_fails() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }
        
        let username = "invalid"
        let password = generateRandomPassword()
        
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)
        
        sut.signUp(
            username: username,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [codeRequiredExp])
        XCTAssertTrue(signUpStartDelegate.error!.isInvalidUsername)
    }
    
    // Use case 1.1.13. Sign up - with Email & Password, Developer makes a request with password that does not match password complexity requirements set on portal
    func test_signUpWithEmailPassword_invalidPassword_fails() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }
        
        let username = generateSignUpRandomEmail()
        let password = "invalid"
        
        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)
        
        sut.signUp(
            username: username,
            password: password,
            correlationId: correlationId,
            delegate: signUpStartDelegate
        )
        
        await fulfillment(of: [codeRequiredExp])
        XCTAssertTrue(signUpStartDelegate.error!.isInvalidUsername)
    }
    
    // Use case 1.1.2. Sign up - with Email & Password, Resend email OOB
    
    

    private func checkSignUpStartDelegate(_ delegate: SignUpPasswordStartDelegateSpy) {
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
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
