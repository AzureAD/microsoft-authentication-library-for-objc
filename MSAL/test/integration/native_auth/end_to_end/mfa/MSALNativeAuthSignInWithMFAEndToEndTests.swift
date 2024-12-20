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

    func test_signInUsingPasswordWithMFASubmitWrongChallengeResendChallengeThen_completeSuccessfully() async throws {
#if os(macOS)
        throw XCTSkip("Keychain access is not active on the macOS app and is used by Keyvault")
#endif
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
        
        // Now submit the wrong email OTP code
        let submitWrongChallengeExpectation = expectation(description: "submitChallenge")
        let mfaSubmitWrongChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitWrongChallengeExpectation)

        mfaRequiredState.submitChallenge(challenge: "wrong_code", delegate: mfaSubmitWrongChallengeDelegateSpy)

        await fulfillment(of: [submitWrongChallengeExpectation])

        XCTAssertTrue(mfaSubmitWrongChallengeDelegateSpy.onMFASubmitChallengeErrorCalled)
        XCTAssertEqual(mfaSubmitWrongChallengeDelegateSpy.error?.isInvalidChallenge, true)
        
        guard let mfaRequiredState = mfaSubmitWrongChallengeDelegateSpy.newStateMFARequiredState else {
            XCTFail("New state not received after SDK error")
            return
        }
        
        // Resend code to default auth method
        
        let mfaResendChallengeExpectation = expectation(description: "mfa")
        let mfaResendChallengeDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaResendChallengeExpectation)
        
        mfaRequiredState.requestChallenge(delegate: mfaResendChallengeDelegateSpy)
        
        await fulfillment(of: [mfaResendChallengeExpectation])
        
        guard mfaResendChallengeDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired else {
            XCTFail("Challenge not sent to MFA method")
            return
        }

        // Now retrieve and submit the email OTP code
        await completeSignInWithMFAFlow(state: mfaRequiredState, username: username)
    }
    
    func test_signInUsingPasswordWithMFAGetAuthMethods_thenCompleteSuccessfully() async throws {
#if os(macOS)
        throw XCTSkip("Keychain access is not active on the macOS app and is used by Keyvault")
#endif
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
        
        // Now retrieve and submit the email OTP code
        await completeSignInWithMFAFlow(state: mfaRequiredState, username: username)
    }
    
    func test_signInUsingPasswordWithMFANoDefaultAuthMethod_completeSuccessfully() async throws {
#if os(macOS)
        throw XCTSkip("Keychain access is not active on the macOS app and is used by Keyvault")
#endif
        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFANoDefaultAuthMethod(),
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
        
        guard mfaDelegateSpy.onSelectionRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired, let authMethod = mfaDelegateSpy.authMethods?.first else {
            XCTFail("Selection required not triggered")
            return
        }
        
        XCTAssertTrue(authMethod.channelTargetType.isEmailType)
        
        // Request to send challenge to a specific strong auth method
        
        let mfaSendChallengeExpectation = expectation(description: "mfa")
        let mfaSendChallengeDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaSendChallengeExpectation)
        mfaRequiredState.requestChallenge(authMethod: authMethod, delegate: mfaSendChallengeDelegateSpy)
        
        await fulfillment(of: [mfaSendChallengeExpectation])
        
        guard mfaSendChallengeDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaSendChallengeDelegateSpy.newStateMFARequired else {
            XCTFail("Challenge not sent to MFA method")
            return
        }
        
        // Now retrieve and submit the email OTP code
        await completeSignInWithMFAFlow(state: mfaRequiredState, username: username)
    }
    
    // MARK: private methods
    
    private func signInUsernameAndPassword(username: String, password: String) async -> AwaitingMFAState? {
        guard let application = initialisePublicClientApplication()
        else {
            XCTFail("Missing information")
            return nil
        }
        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        application.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        
        guard signInDelegateSpy.onSignInAwaitingMFACalled, let awaitingMFAState = signInDelegateSpy.newStateAwaitingMFA else {
            XCTFail("Awaiting MFA not called")
            return nil
        }
        return awaitingMFAState
    }
    
    private func completeSignInWithMFAFlow(state: MFARequiredState, username: String) async {
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let submitChallengeExpectation = expectation(description: "submitChallenge")
        let mfaSubmitChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)

        state.submitChallenge(challenge: code, delegate: mfaSubmitChallengeDelegateSpy)

        await fulfillment(of: [submitChallengeExpectation])

        XCTAssertTrue(mfaSubmitChallengeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result)
        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result?.idToken)
        XCTAssertEqual(mfaSubmitChallengeDelegateSpy.result?.account.username, username)
    }
}
