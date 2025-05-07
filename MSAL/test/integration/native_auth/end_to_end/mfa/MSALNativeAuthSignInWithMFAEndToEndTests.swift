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

//    func test_signInUsingPasswordWithMFASubmitWrongChallengeResendChallengeThen_completeSuccessfully() async throws {
//        throw XCTSkip("Retrieving OTP failure")
//#if os(macOS)
//        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
//#endif
//        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
//                let password = await retrievePasswordForSignInUsername(),
//                let awaitingMFAState = await signInUsernameAndPassword(username: username, password: password)
//        else {
//            XCTFail("Something went wrong")
//            return
//        }
//        
//        // Request to send challenge to the default strong auth method
//        let mfaExpectation = expectation(description: "mfa")
//        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
//        
//        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
//        
//        await fulfillment(of: [mfaExpectation])
//        
//        guard mfaDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired else {
//            XCTFail("Challenge not sent to MFA method")
//            return
//        }
//        
//        // Now submit the wrong email OTP code
//        let submitWrongChallengeExpectation = expectation(description: "submitChallenge")
//        let mfaSubmitWrongChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitWrongChallengeExpectation)
//
//        mfaRequiredState.submitChallenge(challenge: "wrong_code", delegate: mfaSubmitWrongChallengeDelegateSpy)
//
//        await fulfillment(of: [submitWrongChallengeExpectation])
//
//        XCTAssertTrue(mfaSubmitWrongChallengeDelegateSpy.onMFASubmitChallengeErrorCalled)
//        XCTAssertEqual(mfaSubmitWrongChallengeDelegateSpy.error?.isInvalidChallenge, true)
//        
//        guard let mfaRequiredState = mfaSubmitWrongChallengeDelegateSpy.newStateMFARequiredState else {
//            XCTFail("New state not received after SDK error")
//            return
//        }
//        
//        // Resend code to default auth method
//        
//        let mfaResendChallengeExpectation = expectation(description: "mfa")
//        let mfaResendChallengeDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaResendChallengeExpectation)
//        
//        mfaRequiredState.requestChallenge(delegate: mfaResendChallengeDelegateSpy)
//        
//        await fulfillment(of: [mfaResendChallengeExpectation])
//        
//        guard mfaResendChallengeDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired else {
//            XCTFail("Challenge not sent to MFA method")
//            return
//        }
//
//        // Now retrieve and submit the email OTP code
//        await completeSignInWithMFAFlow(state: mfaRequiredState, username: username)
//    }
//    
//    func test_signInUsingPasswordWithMFAGetAuthMethods_thenCompleteSuccessfully() async throws {
//        throw XCTSkip("Retrieving OTP failure")
//#if os(macOS)
//        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
//#endif
//        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
//              let password = await retrievePasswordForSignInUsername(),
//              let awaitingMFAState = await signInUsernameAndPassword(username: username, password: password)
//        else {
//            XCTFail("Something went wrong")
//            return
//        }
//        
//        // Request to send challenge to the default strong auth method
//        let mfaExpectation = expectation(description: "mfa")
//        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
//        
//        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
//        
//        await fulfillment(of: [mfaExpectation])
//        
//        guard mfaDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired else {
//            XCTFail("Challenge not sent to MFA method")
//            return
//        }
//
//        // Now retrieve the list of auth methods
//        let getAuthMethodsExpectation = expectation(description: "getAuthmethods")
//        let mfaGetAuthMethodsDelegateSpy = MFAGetAuthMethodsDelegateSpy(expectation: getAuthMethodsExpectation)
//
//        mfaRequiredState.getAuthMethods(delegate: mfaGetAuthMethodsDelegateSpy)
//
//        await fulfillment(of: [getAuthMethodsExpectation])
//
//        guard let authMethod = mfaGetAuthMethodsDelegateSpy.authMethods?.first, let mfaRequiredState = mfaGetAuthMethodsDelegateSpy.newStateMFARequired else {
//            XCTFail("No MFA auth methods returned")
//            return
//        }
//        
//        XCTAssertTrue(authMethod.channelTargetType.isEmailType)
//        XCTAssertTrue(mfaGetAuthMethodsDelegateSpy.onSelectionRequiredCalled)
//        
//        // Request to send challenge to a specific strong auth method
//        
//        let mfaSendChallengeExpectation = expectation(description: "mfa")
//        let mfaSendChallengeDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaSendChallengeExpectation)
//        mfaRequiredState.requestChallenge(authMethod: authMethod, delegate: mfaSendChallengeDelegateSpy)
//        
//        await fulfillment(of: [mfaSendChallengeExpectation])
//        
//        guard mfaSendChallengeDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaSendChallengeDelegateSpy.newStateMFARequired else {
//            XCTFail("Challenge not sent to MFA method")
//            return
//        }
//        
//        // Now retrieve and submit the email OTP code
//        await completeSignInWithMFAFlow(state: mfaRequiredState, username: username)
//    }
//    
//    func test_signInUsingPasswordWithMFANoDefaultAuthMethod_completeSuccessfully() async throws {
//        throw XCTSkip("Retrieving OTP failure")
//#if os(macOS)
//        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
//#endif
//        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFANoDefaultAuthMethod(),
//                let password = await retrievePasswordForSignInUsername(),
//                let awaitingMFAState = await signInUsernameAndPassword(username: username, password: password)
//        else {
//            XCTFail("Something went wrong")
//            return
//        }
//        
//        // Request to send challenge to the default strong auth method
//        let mfaExpectation = expectation(description: "mfa")
//        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
//        
//        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
//        
//        await fulfillment(of: [mfaExpectation])
//        
//        guard mfaDelegateSpy.onSelectionRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired, let authMethod = mfaDelegateSpy.authMethods?.first else {
//            XCTFail("Selection required not triggered")
//            return
//        }
//        
//        XCTAssertTrue(authMethod.channelTargetType.isEmailType)
//        
//        // Request to send challenge to a specific strong auth method
//        
//        let mfaSendChallengeExpectation = expectation(description: "mfa")
//        let mfaSendChallengeDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaSendChallengeExpectation)
//        mfaRequiredState.requestChallenge(authMethod: authMethod, delegate: mfaSendChallengeDelegateSpy)
//        
//        await fulfillment(of: [mfaSendChallengeExpectation])
//        
//        guard mfaSendChallengeDelegateSpy.onVerificationRequiredCalled, let mfaRequiredState = mfaSendChallengeDelegateSpy.newStateMFARequired else {
//            XCTFail("Challenge not sent to MFA method")
//            return
//        }
//        
//        // Now retrieve and submit the email OTP code
//        await completeSignInWithMFAFlow(state: mfaRequiredState, username: username)
//    }
//
//    func test_signInAuthenticationContextClaim_mfaFlowIsTriggeredAndAccessTokenContainsClaims() async throws {
//        throw XCTSkip("Retrieving OTP failure")
//#if os(macOS)
//        throw XCTSkip("For some reason this test now requires Keychain access, reason needs to be investigated")
//#endif
//        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
//              let password = await retrievePasswordForSignInUsername(),
//              let application = initialisePublicClientApplication()
//        else {
//            XCTFail("Something went wrong")
//            return
//        }
//
//        let authenticationContextId = "c4"
//        let authenticationContextRequestClaimJson = "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"\(authenticationContextId)\"}}}"
//        let authenticationContextATClaimJson = "\"acrs\":[\"\(authenticationContextId)\"]"
//
//        let parameters = MSALNativeAuthSignInParameters(username: username)
//        parameters.password = password
//        var error: NSError? = nil
//
//        parameters.claimsRequest = MSALClaimsRequest(jsonString: authenticationContextRequestClaimJson,
//                                                     error: &error)
//
//        let signInExpectation = expectation(description: "signing in")
//        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)
//
//        application.signIn(parameters: parameters, delegate: signInDelegateSpy)
//
//        await fulfillment(of: [signInExpectation])
//
//        guard signInDelegateSpy.onSignInAwaitingMFACalled, let awaitingMFAState = signInDelegateSpy.newStateAwaitingMFA else {
//            XCTFail("Awaiting MFA not called")
//            return
//        }
//
//        // Request to send challenge to the default strong auth method
//        let mfaExpectation = expectation(description: "mfa")
//        let mfaDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaExpectation)
//
//        awaitingMFAState.requestChallenge(delegate: mfaDelegateSpy)
//
//        await fulfillment(of: [mfaExpectation])
//
//        guard mfaDelegateSpy.onSelectionRequiredCalled, let mfaRequiredState = mfaDelegateSpy.newStateMFARequired, let authMethod = mfaDelegateSpy.authMethods?.first else {
//            XCTFail("Selection required not triggered")
//            return
//        }
//
//        XCTAssertTrue(authMethod.channelTargetType.isEmailType)
//
//        // Request to send challenge to a specific strong auth method
//
//        let mfaSendChallengeExpectation = expectation(description: "mfa")
//        let mfaSendChallengeDelegateSpy = MFARequestChallengeDelegateSpy(expectation: mfaSendChallengeExpectation)
//        mfaRequiredState.requestChallenge(authMethod: authMethod, delegate: mfaSendChallengeDelegateSpy)
//
//        await fulfillment(of: [mfaSendChallengeExpectation])
//
//        guard mfaSendChallengeDelegateSpy.onVerificationRequiredCalled, let newMfaRequiredState = mfaSendChallengeDelegateSpy.newStateMFARequired else {
//            XCTFail("Challenge not sent to MFA method")
//            return
//        }
//
//        XCTAssertNotNil(mfaSendChallengeDelegateSpy.sentTo)
//        XCTAssertNotNil(mfaSendChallengeDelegateSpy.codeLength)
//        XCTAssertTrue(mfaSendChallengeDelegateSpy.channelTargetType!.isEmailType)
//
//        guard let code = await retrieveCodeFor(email: username) else {
//            XCTFail("OTP code could not be retrieved")
//            return
//        }
//
//        let submitChallengeExpectation = expectation(description: "submitChallenge")
//        let mfaSubmitChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)
//
//        newMfaRequiredState.submitChallenge(challenge: code, delegate: mfaSubmitChallengeDelegateSpy)
//
//        await fulfillment(of: [submitChallengeExpectation])
//
//        XCTAssertTrue(mfaSubmitChallengeDelegateSpy.onSignInCompletedCalled)
//        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result)
//        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result?.idToken)
//        XCTAssertEqual(mfaSubmitChallengeDelegateSpy.result?.account.username, username)
//
//        let geAccessTokenExpectation = expectation(description: "get access token")
//        let credentialsDelegateSpy = CredentialsDelegateSpy(expectation: geAccessTokenExpectation)
//
//        signInDelegateSpy.result?.getAccessToken(parameters: MSALNativeAuthGetAccessTokenParameters(), delegate: credentialsDelegateSpy)
//
//        await fulfillment(of: [geAccessTokenExpectation])
//
//        XCTAssertTrue(credentialsDelegateSpy.onAccessTokenRetrieveCompletedCalled)
//        XCTAssertNotNil(credentialsDelegateSpy.result?.accessToken)
//
//        let atParts = credentialsDelegateSpy.result?.accessToken.components(separatedBy: ".")
//
//        // It should have 3 parts
//        guard let atParts, atParts.count == 3 else {
//            XCTFail("Invalid Access token received")
//            return
//        }
//
//        // We need to use the middle part
//        var atBody: String! = atParts[1]
//
//        //There could be the case that the length of the access token is not a multiple of 4 so we pad it with "="
//        let length = Double(atBody.lengthOfBytes(using: String.Encoding.utf8))
//        let requiredLength = 4 * ceil(length / 4.0)
//        let paddingLength = requiredLength - length
//        if paddingLength > 0 {
//            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
//            atBody = atBody + padding
//        }
//        
//        let atEncodedData = Data(base64Encoded: atBody!, options: .ignoreUnknownCharacters)
//        let atString = String(data: atEncodedData!, encoding: .utf8)!
//
//        XCTAssertTrue(atString.contains(authenticationContextATClaimJson))
//    }
//
//    // MARK: private methods
//    
//    private func signInUsernameAndPassword(username: String, password: String) async -> AwaitingMFAState? {
//        guard let application = initialisePublicClientApplication()
//        else {
//            XCTFail("Missing information")
//            return nil
//        }
//        let signInExpectation = expectation(description: "signing in")
//        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)
//        
//        let param = MSALNativeAuthSignInParameters(username: username)
//        param.password = password
//        param.correlationId = correlationId
//
//        application.signIn(parameters: param, delegate: signInDelegateSpy)
//
//        await fulfillment(of: [signInExpectation])
//        
//        guard signInDelegateSpy.onSignInAwaitingMFACalled, let awaitingMFAState = signInDelegateSpy.newStateAwaitingMFA else {
//            XCTFail("Awaiting MFA not called")
//            return nil
//        }
//        return awaitingMFAState
//    }
//    
//    private func completeSignInWithMFAFlow(state: MFARequiredState, username: String) async {
//        guard let code = await retrieveCodeFor(email: username) else {
//            XCTFail("OTP code could not be retrieved")
//            return
//        }
//
//        let submitChallengeExpectation = expectation(description: "submitChallenge")
//        let mfaSubmitChallengeDelegateSpy = MFASubmitChallengeDelegateSpy(expectation: submitChallengeExpectation)
//
//        state.submitChallenge(challenge: code, delegate: mfaSubmitChallengeDelegateSpy)
//
//        await fulfillment(of: [submitChallengeExpectation])
//
//        XCTAssertTrue(mfaSubmitChallengeDelegateSpy.onSignInCompletedCalled)
//        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result)
//        XCTAssertNotNil(mfaSubmitChallengeDelegateSpy.result?.idToken)
//        XCTAssertEqual(mfaSubmitChallengeDelegateSpy.result?.account.username, username)
//    }
}
