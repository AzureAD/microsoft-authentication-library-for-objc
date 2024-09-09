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

final class MSALNativeAuthSignInWithMFAEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {

    func test_signInUsingPasswordWithMFA_completeSuccessfully() async throws {
        XCTSkip("Missing username for MFA user")
        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFA(), 
                let password = await retrievePasswordForSignInUsername(),
                let awaitingMFAState = await signInUsernameAndPassword(username: username, password: password)
        else {
            XCTFail("Something went wrong")
            return
        }
        
        // Request to send challenge to the default strong auth method
        let mfaExpectation = expectation(description: "mfa")
        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
        
        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
        
        await fulfillment(of: [mfaExpectation])
        
        guard mfaDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired else {
            XCTFail("Challenge not sent to MFA method")
            return
        }

        // Now submit the email OTP code
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let mfaSubmitChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        mfaRequiredState.submitChallenge(challenge: code, delegate: mfaSubmitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        XCTAssertTrue(mfaSubmitChallengeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result)
        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result?.idToken)
        XCTAssertEqual(mfaSubmitChallengeDelegateSpy.result?.account.username, username)
    }
    
    func test_signInUsingPasswordWithMFASendWrongChallenge_returnExpectedError() async throws {
        XCTSkip("Missing username for MFA user")
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
              let password = await retrievePasswordForSignInUsername(),
              let awaitingMFAState = await signInUsernameAndPassword(username: username, password: password)
        else {
            XCTFail("Something went wrong")
            return
        }
        
        // Request to send challenge to the default strong auth method
        let mfaExpectation = expectation(description: "mfa")
        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
        
        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
        
        await fulfillment(of: [mfaExpectation])
        
        guard mfaDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired else {
            XCTFail("Challenge not sent to MFA method")
            return
        }

        // Now submit the wrong email OTP code
        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let mfaSubmitChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        mfaRequiredState.submitChallenge(challenge: "000000", delegate: mfaSubmitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        XCTAssertTrue(mfaSubmitChallengeDelegateSpy.onMFASubmitChallengeErrorCalled)
        XCTAssertEqual(mfaSubmitChallengeDelegateSpy.error?.isInvalidChallenge, true)
    }
    
    func test_signInUsingPasswordWithMFAGetAuthMethods_thenCompleteSuccessfully() async throws {
        XCTSkip("Missing username for MFA user")
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
              let password = await retrievePasswordForSignInUsername(),
              let awaitingMFAState = await signInUsernameAndPassword(username: username, password: password)
        else {
            XCTFail("Something went wrong")
            return
        }
        
        // Request to send challenge to the default strong auth method
        let mfaExpectation = expectation(description: "mfa")
        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
        
        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
        
        await fulfillment(of: [mfaExpectation])
        
        guard mfaDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired else {
            XCTFail("Challenge not sent to MFA method")
            return
        }

        // Now retrieve the list of auth methods
        let getAuthMethodsExpectation = expectation(description: "getAuthmethods")
        let mfaGetAuthMethodsDelegateSpy = MFAGetAuthMethodsDelegateSpy(expectation: getAuthMethodsExpectation)

        mfaRequiredState.getAuthMethods(delegate: mfaGetAuthMethodsDelegateSpy)

        await fulfillment(of: [getAuthMethodsExpectation])

        guard let authMethod = mfaGetAuthMethodsDelegateSpy.authMethods?.first, let mfaRequiredState = mfaGetAuthMethodsDelegateSpy.newStateMFARequired else {
            XCTFail("No MFA auth methods returned")
            return
        }
        
        XCTAssertTrue(authMethod.channelTargetType.isEmailType)
        XCTAssertTrue(mfaGetAuthMethodsDelegateSpy.onSelectionRequiredCalled)
        
        // Request to send challenge to a specific strong auth method
        
        let mfaSendChallengeExpectation = expectation(description: "mfa")
        let mfaSendChallengeDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaSendChallengeExpectation)
        mfaRequiredState.requestChallenge(authMethod: authMethod, delegate: mfaSendChallengeDelegateSpy)
        
        await fulfillment(of: [mfaSendChallengeExpectation])
        
        guard mfaSendChallengeDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaSendChallengeDelegateSpy.newStateMFARequired else {
            XCTFail("Challenge not sent to MFA method")
            return
        }
        
        // Now submit the email OTP code
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let mfaSubmitChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        mfaRequiredState.submitChallenge(challenge: code, delegate: mfaSubmitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        XCTAssertTrue(mfaSubmitChallengeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result)
        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result?.idToken)
        XCTAssertEqual(mfaSubmitChallengeDelegateSpy.result?.account.username, username)
    }
    
    // MARK: private methods
    
    private func signInUsernameAndPassword(username: String, password: String) async -> AwaitingMFAState? {
        guard let sut = initialisePublicClientApplication()
        else {
            XCTFail("Missing information")
            return nil
        }
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        
        guard signInDelegateSpy.onSignInAwaitingMFACalled, let awaitingMFAState = signInDelegateSpy.newStateAwaitingMFA else {
            XCTFail("Awaiting MFA not called")
            return nil
        }
        return awaitingMFAState
    }

}
