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

final class MSALNativeAuthSignInUsernameAndPasswordEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {
    // Hero Scenario 1.2.1. Sign in - Use email and password to get token
    func test_signInUsingPasswordWithKnownUsernameResultsInSuccess() async throws {
    #if os(macOS)
        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
    #endif
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
    }
    
    // Hero Scenario 1.2.2. Sign in - User is not registered with given email
    func test_signInUsingPasswordWithUnknownUsernameResultsInError() async throws {
        guard let sut = initialisePublicClientApplication() else {
            XCTFail("Missing information")
            return
        }
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let unknownUsername = UUID().uuidString + "@contoso.com"

        sut.signIn(username: unknownUsername, password: "testpass", correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isUserNotFound)
    }

    // Hero Scenario 1.2.3. Sign in - Password is incorrect
    func test_signInWithKnownUsernameInvalidPasswordResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: "An Invalid Password", correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isInvalidCredentials)
    }
    
    // User Case 1.2.4. Sign In - User signs in with account A, while data for account A already exists in SDK persistence
    func test_signInWithAccountSigned() async throws {
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
        
        // Now signed in the account again
        let signInExpectation2 = expectation(description: "signing in")
        let signInDelegateSpy2 = SignInPasswordStartDelegateSpy(expectation: signInExpectation2)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy2)
        
        XCTAssertTrue(signInDelegateSpy2.error!.description, "An account is already signed in.")
    }
    
    // User Case 1.2.5. Sign In - User signs in with account B, while data for account A already exists in SDK persistence
    func test_signInWithAccountSigned() async throws {
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
        
        // Now signed in the account again
        let signInExpectation2 = expectation(description: "signing in")
        let signInDelegateSpy2 = SignInPasswordStartDelegateSpy(expectation: signInExpectation2)
        
        let uesrname2 = retrieveUsernameForSignInCode()

        sut.signIn(username: uesrname2, password: password, correlationId: correlationId, delegate: signInDelegateSpy2)
        
        XCTAssertTrue(signInDelegateSpy2.error!.description, "An account is already signed in.")
    }
    
    /* User Case 1.2.6. Sign In - Ability to provide scope to control auth strength of the token
        Please refer to Crendentials test (test_signInWithExtraScopes())
     
        sut.signIn(username: username, password: password, scopes: ["User.Read"], correlationId: correlationId, delegate: signInDelegateSpy)
        ...
        XCTAssertTrue(credentialsDelegateSpy.result!.scopes.contains("User.Read"))
    */
    
    // User Case 1.2.7. Sign In - User email is registered with email OTP auth method, which is supported by the developer
    func test_signInWithOTPSufficientChallengeResultsInSuccess() async throws {
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let passwordRequiredExpectation = expectation(description: "verifying password")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInPasswordRequiredDelegateSpy = SignInPasswordRequiredDelegateSpy(expectation: passwordRequiredExpectation)

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInPasswordRequiredCalled else {
            XCTFail("onSignInPasswordRequired not called")
            return
        }

        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)

        // Now submit the password..

        signInDelegateSpy.newStatePasswordRequired?.submitPassword(password: password, delegate: signInPasswordRequiredDelegateSpy)

        await fulfillment(of: [passwordRequiredExpectation])

        XCTAssertTrue(signInPasswordRequiredDelegateSpy.onSignInCompletedCalled)
    }
    
    /* User Case 1.2.8. Sign In - User attempts to sign in with email and password, but server requires second factor authentication (MFA OTP)
       Please refer to MFA Test (test_signInAuthenticationContextClaim_mfaFlowIsTriggeredAndAccessTokenContainsClaims)
     
        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
        ...
        newMfaRequiredState.submitChallenge(challenge: code, delegate: mfaSubmitChallengeDelegateSpy)
        ...
    */
    
    // User Case 1.2.9. Sign In - User email is registered with email OTP auth method, which is not supported by the developer (aka redirect flow)
    func test_signInWithOTPInsufficientChallengeResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isBrowserRequired)
    }
    
    // Sign in - Password is incorrect (sent over delegate.newStatePasswordRequired)
    func test_signInAndSendingIncorrectPasswordResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let passwordRequiredExpectation = expectation(description: "verifying password")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)
        let signInPasswordRequiredDelegateSpy = SignInPasswordRequiredDelegateSpy(expectation: passwordRequiredExpectation)

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.onSignInPasswordRequiredCalled else {
            XCTFail("onSignInPasswordRequired not called")
            return
        }

        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)

        // Now submit the password..

        signInDelegateSpy.newStatePasswordRequired?.submitPassword(password: "An Invalid Password", delegate: signInPasswordRequiredDelegateSpy)

        await fulfillment(of: [passwordRequiredExpectation])

        XCTAssertTrue(signInPasswordRequiredDelegateSpy.onSignInPasswordRequiredErrorCalled)
        XCTAssertEqual(signInPasswordRequiredDelegateSpy.error?.isInvalidPassword, true)
    }
}
