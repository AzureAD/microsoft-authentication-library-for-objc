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

final class MSALNativeAuthSignInWithMFAEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {

    func test_signInUsingPasswordWithMFA_completeSuccessfully() async throws {
        guard let sut = initialisePublicClientApplication(), 
                let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
                let password = await retrievePasswordForSignInUsername()
        else {
            XCTFail("Missing information")
            return
        }
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        
        guard signInDelegateSpy.onSignInAwaitingMFACalled, let awaitingMFAState = signInDelegateSpy.newStateAwaitingMFA else {
            XCTFail("Awaiting MFA not called")
            return
        }
        
        // Request to send challenge to the default strong auth method
        let mfaExpectation = expectation(description: "mfa")
        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
        
        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
        
        await fulfillment(of: [signInExpectation])
        
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

}
