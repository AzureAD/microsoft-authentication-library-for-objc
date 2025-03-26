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

    func test_createUserAddStrongAuthMethodAndSignInSuccessfully() async throws {
        // Step 1: Create User
        guard let application = try? MSALNativeAuthPublicClientApplication(
            clientId: "Enter_the_Application_Id_Here",
            tenantSubdomain: "Enter_the_Tenant_Subdomain_Here",
            challengeTypes: [.OOB]
        ) else {
            XCTFail("Failed to initialize public client application")
            return
        }

        let username = "user@example.com"
        let password = "password123"

        let signUpParameters = MSALNativeAuthSignUpParameters(username: username)
        signUpParameters.password = password

        let signUpExpectation = expectation(description: "signing up")
        let signUpDelegateSpy = SignUpStartDelegateSpy(expectation: signUpExpectation)

        application.signUp(parameters: signUpParameters, delegate: signUpDelegateSpy)

        await fulfillment(of: [signUpExpectation])

        // Step 2: Attempt to Sign In
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

        // Step 3: Add Strong Auth Method
        let challengeParameters = MSALNativeAuthChallengeAuthMethodParameters(authMethod: authMethod)
        let challengeExpectation = expectation(description: "challenging auth method")
        let challengeDelegateSpy = RegisterStrongAuthChallengeDelegateSpy(expectation: challengeExpectation)

        strongAuthState.challengeAuthMethod(parameters: challengeParameters, delegate: challengeDelegateSpy)

        await fulfillment(of: [challengeExpectation])

        guard challengeDelegateSpy.onRegisterStrongAuthVerificationRequiredCalled, let verificationState = challengeDelegateSpy.newStateVerificationRequired else {
            XCTFail("Challenge auth method failed")
            return
        }

        // Step 4: Get Code
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        // Step 5: Submit Challenge
        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let submitChallengeDelegateSpy = RegisterStrongAuthSubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        verificationState.submitChallenge(challenge: code, delegate: submitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        XCTAssertTrue(submitChallengeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(submitChallengeDelegateSpy.result)
        XCTAssertNotNil(submitChallengeDelegateSpy.result?.idToken)
        XCTAssertEqual(submitChallengeDelegateSpy.result?.account.username, username)
    }



        func test_createUserAddStrongAuthMethodAndFailSignInWithIncorrectCode() async throws {
            // Step 1: Create User
            guard let application = try? MSALNativeAuthPublicClientApplication(
                clientId: "Enter_the_Application_Id_Here",
                tenantSubdomain: "Enter_the_Tenant_Subdomain_Here",
                challengeTypes: [.OOB]
            ) else {
                XCTFail("Failed to initialize public client application")
                return
            }

            let username = "user@example.com"
            let password = "password123"

            let signUpParameters = MSALNativeAuthSignUpParameters(username: username)
            signUpParameters.password = password

            let signUpExpectation = expectation(description: "signing up")
            let signUpDelegateSpy = SignUpStartDelegateSpy(expectation: signUpExpectation)

            application.signUp(parameters: signUpParameters, delegate: signUpDelegateSpy)

            await fulfillment(of: [signUpExpectation])

            // Step 2: Attempt to Sign In
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

            // Step 3: Add Strong Auth Method
            let challengeParameters = MSALNativeAuthChallengeAuthMethodParameters(authMethod: authMethod)
            let challengeExpectation = expectation(description: "challenging auth method")
            let challengeDelegateSpy = RegisterStrongAuthChallengeDelegateSpy(expectation: challengeExpectation)

            strongAuthState.challengeAuthMethod(parameters: challengeParameters, delegate: challengeDelegateSpy)

            await fulfillment(of: [challengeExpectation])

            guard challengeDelegateSpy.onRegisterStrongAuthVerificationRequiredCalled, let verificationState = challengeDelegateSpy.newStateVerificationRequired else {
                XCTFail("Challenge auth method failed")
                return
            }

            // Step 4: Submit Incorrect Challenge
            let incorrectCode = "incorrectCode"
            let submitChallengeExpectation = expectation(description: "submitChallenge")
            let submitChallengeDelegateSpy = RegisterStrongAuthSubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)
            
            verificationState.submitChallenge(challenge: incorrectCode, delegate: submitChallengeDelegateSpy)

            await fulfillment(of: [submitChallengeExpectation])

            XCTAssertTrue(submitChallengeDelegateSpy.onRegisterStrongAuthSubmitChallengeErrorCalled, "Error should be called for incorrect code")
            XCTAssertTrue(submitChallengeDelegateSpy.error?.isInvalidChallenge ?? false, "Error type should be invalidChallenge for incorrect code")
        }

}
