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
import MSAL

final class MSALNativeAuthSignInJITEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {

    func test_createUserAndAddSameEmailAsStrongAuthMethod_thenAutomaticallySignInSuccessfully_withPreverified() async throws {
        throw XCTSkip("Retrieving OTP failure")
#if os(macOS)
        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
#endif

        // Step 1: Create User
        guard let application = initialisePublicClientApplication() else {
            XCTFail("Failed to initialize public client application")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.password = password
        signUpParam.correlationId = correlationId

        application.signUp(parameters: signUpParam, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

        // Step 2: Get & Submit Code for Sign Up
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])

        guard signUpVerifyCodeDelegate.onSignUpCompletedCalled,
              let signInAfterSignUpState = signUpVerifyCodeDelegate.signInAfterSignUpState else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return
        }

        // Step 3: Attempt to Sign In automtically
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInAfterSignUpDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInAfterSignUpParameters()
        signInAfterSignUpState.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let authMethod = signInDelegateSpy.authMethods?.first else {
            XCTFail("Sign in failed or strong auth method registration not required")
            return
        }

        // Step 4: Add Strong Auth Method, but don't specify verification contact so it's preverified
        let challengeParameters = MSALNativeAuthChallengeAuthMethodParameters(authMethod: authMethod)
        let challengeExpectation = expectation(description: "challenging auth method")
        let challengeDelegateSpy = RegisterStrongAuthChallengeDelegateSpy(expectation: challengeExpectation)

        strongAuthState.challengeAuthMethod(parameters: challengeParameters, delegate: challengeDelegateSpy)

        await fulfillment(of: [challengeExpectation])

        XCTAssertTrue(challengeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(challengeDelegateSpy.result)
        XCTAssertNotNil(challengeDelegateSpy.result?.idToken)
        XCTAssertEqual(challengeDelegateSpy.result?.account.username, username)
    }

    func test_createUserAndAddDifferentEmailAsStrongAuthMethod_thenAutomaticallySignInSuccessfully() async throws {
        throw XCTSkip("Retrieving OTP failure")
#if os(macOS)
        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
#endif

        // Step 1: Create User
        guard let application = initialisePublicClientApplication() else {
            XCTFail("Failed to initialize public client application")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.password = password
        signUpParam.correlationId = correlationId

        application.signUp(parameters: signUpParam, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

        // Step 2: Get & Submit Code for Sign Up
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])

        guard signUpVerifyCodeDelegate.onSignUpCompletedCalled,
              let signInAfterSignUpState = signUpVerifyCodeDelegate.signInAfterSignUpState else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return
        }

        // Step 3: Attempt to Sign In automatically
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInAfterSignUpDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInAfterSignUpParameters()
        signInAfterSignUpState.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let authMethod = signInDelegateSpy.authMethods?.first else {
            XCTFail("Sign in failed or strong auth method registration not required")
            return
        }

        // Step 4: Add Strong Auth Method and specify different email
        let newEmail = generateSignUpRandomEmail()
        let challengeParameters = MSALNativeAuthChallengeAuthMethodParameters(authMethod: authMethod)
        challengeParameters.verificationContact = newEmail
        let challengeExpectation = expectation(description: "challenging auth method")
        let challengeDelegateSpy = RegisterStrongAuthChallengeDelegateSpy(expectation: challengeExpectation)

        strongAuthState.challengeAuthMethod(parameters: challengeParameters, delegate: challengeDelegateSpy)

        await fulfillment(of: [challengeExpectation])

        guard challengeDelegateSpy.onRegisterStrongAuthVerificationRequiredCalled,
              let verificationState = challengeDelegateSpy.newStateVerificationRequired else {
            XCTFail("Challenge auth method failed")
            return
        }

        // Step 5: Get Code for Register Strong Auth
        guard let code = await retrieveCodeFor(email: newEmail) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        // Step 6: Submit Code to Register Strong Auth
        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let submitChallengeDelegateSpy = RegisterStrongAuthSubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        verificationState.submitChallenge(challenge: code, delegate: submitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        checkSubmitChallengeDelegate(submitChallengeDelegateSpy, username: username)
    }

    func test_createUserAndAddDifferentEmailAsStrongAuthMethod_thenSignInSuccessfully() async throws {
        throw XCTSkip("Retrieving OTP failure")
#if os(macOS)
        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
#endif

        // Step 1: Create User
        guard let application = initialisePublicClientApplication() else {
            XCTFail("Failed to initialize public client application")
            return
        }

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()

        let codeRequiredExp = expectation(description: "code required")
        let signUpStartDelegate = SignUpPasswordStartDelegateSpy(expectation: codeRequiredExp)

        let signUpParam = MSALNativeAuthSignUpParameters(username: username)
        signUpParam.password = password
        signUpParam.correlationId = correlationId

        application.signUp(parameters: signUpParam, delegate: signUpStartDelegate)

        await fulfillment(of: [codeRequiredExp])
        checkSignUpStartDelegate(signUpStartDelegate)

        guard signUpStartDelegate.onSignUpCodeRequiredCalled else {
            XCTFail("onSignUpCodeRequired not called")
            return
        }

        // Step 2: Get & Submit Code for Sign Up
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

        // Step 3: Attempt to Sign In with new flow
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInParameters(username: username)
        signInParameters.password = password

        application.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let authMethod = signInDelegateSpy.authMethods?.first else {
            XCTFail("Sign in failed or strong auth method registration not required")
            return
        }

        // Step 4: Add Strong Auth Method and specify different email
        let newEmail = generateSignUpRandomEmail()
        let challengeParameters = MSALNativeAuthChallengeAuthMethodParameters(authMethod: authMethod)
        challengeParameters.verificationContact = newEmail
        let challengeExpectation = expectation(description: "challenging auth method")
        let challengeDelegateSpy = RegisterStrongAuthChallengeDelegateSpy(expectation: challengeExpectation)

        strongAuthState.challengeAuthMethod(parameters: challengeParameters, delegate: challengeDelegateSpy)

        await fulfillment(of: [challengeExpectation])

        guard challengeDelegateSpy.onRegisterStrongAuthVerificationRequiredCalled,
              let verificationState = challengeDelegateSpy.newStateVerificationRequired else {
            XCTFail("Challenge auth method failed")
            return
        }

        // Step 5: Get Code for Register Strong Auth
        guard let code = await retrieveCodeFor(email: newEmail) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        // Step 6: Submit Code to Register Strong Auth
        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let submitChallengeDelegateSpy = RegisterStrongAuthSubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        verificationState.submitChallenge(challenge: code, delegate: submitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        checkSubmitChallengeDelegate(submitChallengeDelegateSpy, username: username)
    }

    private func checkSignUpStartDelegate(_ delegate: SignUpPasswordStartDelegateSpy) {
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertNotNil(delegate.codeLength)
    }

    private func checkSubmitChallengeDelegate(_ delegate: RegisterStrongAuthSubmitChallengeDelegateSpy, username: String) {
        XCTAssertTrue(delegate.onSignInCompletedCalled)
        XCTAssertNotNil(delegate.result)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertEqual(delegate.result?.account.username, username)
    }
}
