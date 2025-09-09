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
        let username = generateSignUpRandomEmail()
        // Step 1: Create User
        guard let signInAfterSignUpState = await signUpInternally(username: username, password: generateRandomPassword(), application: initialisePublicClientApplication()) else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return
        }

        // Step 2: Attempt to Sign In automtically
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInAfterSignUpDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInAfterSignUpParameters()
        signInParameters.claimsRequest = MSALClaimsRequest(jsonString: "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c4\"}}}", error: nil)
        signInAfterSignUpState.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let authMethod = signInDelegateSpy.authMethods?.first(where: { $0.channelTargetType.isEmailType }) else {
            XCTFail("Sign in failed or strong auth method registration not required")
            return
        }

        // Step 3: Add Strong Auth Method, but don't specify verification contact so it's preverified
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

        let username = generateSignUpRandomEmail()
        // Step 1: Create User
        guard let signInAfterSignUpState = await signUpInternally(username: username, password: generateRandomPassword(), application: initialisePublicClientApplication()) else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return
        }

        // Step 2: Attempt to Sign In automatically
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInAfterSignUpDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInAfterSignUpParameters()
        signInParameters.claimsRequest = MSALClaimsRequest(jsonString: "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c4\"}}}", error: nil)
        signInAfterSignUpState.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let authMethod = signInDelegateSpy.authMethods?.first(where: { $0.channelTargetType.isEmailType }) else {
            XCTFail("Sign in failed or strong auth method registration not required")
            return
        }

        // Step 3: Add Strong Auth Method and specify different email
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

        // Step 4: Get Code for Register Strong Auth
        guard let code = await retrieveCodeFor(email: newEmail) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        // Step 5: Submit Code to Register Strong Auth
        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let submitChallengeDelegateSpy = RegisterStrongAuthSubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        verificationState.submitChallenge(challenge: code, delegate: submitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        checkSubmitChallengeDelegate(submitChallengeDelegateSpy, username: username)
    }

    func test_createUserAndAddDifferentEmailAsStrongAuthMethod_thenSignInSuccessfully() async throws {
        throw XCTSkip("Capabilities feature not available in eSTS production")
#if os(macOS)
        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
#endif

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        guard let application = initialisePublicClientApplication() else {
            XCTFail("Failed to initialize public client application")
            return
        }
        // Step 1: Create User
        guard let _ = await signUpInternally(username: username, password: password, application: application) else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return
        }

        // Step 2: Attempt to Sign In with new flow
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInParameters(username: username)
        signInParameters.password = password
        signInParameters.claimsRequest = MSALClaimsRequest(jsonString: "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c4\"}}}", error: nil)

        application.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let authMethod = signInDelegateSpy.authMethods?.first(where: { $0.channelTargetType.isEmailType }) else {
            XCTFail("Sign in failed or strong auth method registration not required")
            return
        }

        // Step 3: Add Strong Auth Method and specify different email
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

        // Step 4: Get Code for Register Strong Auth
        guard let code = await retrieveCodeFor(email: newEmail) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        // Step 5: Submit Code to Register Strong Auth
        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let submitChallengeDelegateSpy = RegisterStrongAuthSubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        verificationState.submitChallenge(challenge: code, delegate: submitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        checkSubmitChallengeDelegate(submitChallengeDelegateSpy, username: username)
    }
    
    func test_createUserAndDoNotSendCapabilities_thenBrowserRequiredIsExpected() async throws {
        throw XCTSkip("Retrieving OTP failure")
#if os(macOS)
        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
#endif

        let username = generateSignUpRandomEmail()
        let password = generateRandomPassword()
        guard let application = initialisePublicClientApplication(capabilities: []) else {
            XCTFail("Failed to initialize public client application")
            return
        }
        // Step 1: Create User
        guard let _ = await signUpInternally(username: username, password: password, application: application) else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return
        }

        // Step 2: Attempt to Sign In with new flow
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInParameters(username: username)
        signInParameters.password = password
        signInParameters.claimsRequest = MSALClaimsRequest(jsonString: "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c4\"}}}", error: nil)

        application.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let authMethod = signInDelegateSpy.authMethods?.first(where: { $0.channelTargetType.isEmailType }) else {
            XCTFail("Sign in failed or strong auth method registration not required")
            return
        }

        // browser required is expected here
        XCTAssertTrue(signInDelegateSpy.onSignInPasswordErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error?.isBrowserRequired ?? false)
        XCTAssertNotNil(signInDelegateSpy.error?.errorDescription)
    }
    
    func test_createUserAndAddInvalidPhoneAsStrongAuthMethod_thenInvalidInputErrorIsReturned() async throws {
        throw XCTSkip("SMS auth method not yet available in lab tenant")
#if os(macOS)
        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
#endif
        let username = generateSignUpRandomEmail()
        // Step 1: Create User
        guard let signInAfterSignUpState = await signUpInternally(username: username, password: generateRandomPassword(), application: initialisePublicClientApplication()) else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return
        }

        // Step 2: Attempt to Sign In after signUp
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInAfterSignUpDelegateSpy(expectation: signInExpectation)

        let signInParameters = MSALNativeAuthSignInAfterSignUpParameters()
        signInParameters.claimsRequest = MSALClaimsRequest(jsonString: "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c4\"}}}", error: nil)
        signInAfterSignUpState.signIn(parameters: signInParameters, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInStrongAuthMethodRegistrationCalled,
              let strongAuthState = signInDelegateSpy.newStateStrongAuthMethodRegistration,
              let smsAuthMethod = signInDelegateSpy.authMethods?.first(where: { $0.channelTargetType.isSMSType }) else {
            XCTFail("Sign in failed or strong auth method registration not required or SMS method not found")
            return
        }

        // Step 3: Add Strong Auth Method and specify invalid phone number
        let invalidPhone = "+123" // Clearly invalid phone number
        let challengeParameters = MSALNativeAuthChallengeAuthMethodParameters(authMethod: smsAuthMethod)
        challengeParameters.verificationContact = invalidPhone
        let challengeExpectation = expectation(description: "challenging auth method with invalid phone")
        let challengeDelegateSpy = RegisterStrongAuthChallengeDelegateSpy(expectation: challengeExpectation)

        strongAuthState.challengeAuthMethod(parameters: challengeParameters, delegate: challengeDelegateSpy)

        await fulfillment(of: [challengeExpectation])

        XCTAssertTrue(challengeDelegateSpy.onRegisterStrongAuthChallengeErrorCalled)
        XCTAssertEqual(challengeDelegateSpy.error?.isInvalidInput, true)
    }
    
    // MARK: private methods
    
    private func signUpInternally(username: String, password: String, application:  MSALNativeAuthPublicClientApplication?) async -> SignInAfterSignUpState? {
        // Step 1: Create User
        guard let application = application else {
            XCTFail("Failed to initialize public client application")
            return nil
        }
        
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
            return nil
        }

        // Step 2: Get & Submit Code for Sign Up
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return nil
        }

        let signUpCompleteExp = expectation(description: "sign-up complete")
        let signUpVerifyCodeDelegate = SignUpVerifyCodeDelegateSpy(expectation: signUpCompleteExp)

        signUpStartDelegate.newState?.submitCode(code: code, delegate: signUpVerifyCodeDelegate)

        await fulfillment(of: [signUpCompleteExp])

        guard signUpVerifyCodeDelegate.onSignUpCompletedCalled else {
            XCTFail("onSignUpCompleted not called or state is nil")
            return nil
        }
        return signUpVerifyCodeDelegate.signInAfterSignUpState
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
