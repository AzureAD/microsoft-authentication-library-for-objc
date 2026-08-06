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

final class MSALNativeAuthSignInUsernameEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {
    func test_emailOTPUserPoolRotatesAndWraps() {
        let pool = MSALNativeAuthEmailOTPUserPool(usernames: ["user1", "user2", "user3"])

        XCTAssertEqual(pool.nextUsername(), "user1")
        XCTAssertEqual(pool.nextUsername(), "user2")
        XCTAssertEqual(pool.nextUsername(), "user3")
        XCTAssertEqual(pool.nextUsername(), "user1")
    }

    func test_emailOTPUserPoolRejectsInvalidConfiguration() {
        XCTAssertThrowsError(
            try MSALNativeAuthEmailOTPUserPool.make(
                configuration: ["user1": "first", "user3": "third"],
                keys: ["user1", "user2", "user3"]
            )
        ) { error in
            XCTAssertEqual(
                error as? MSALNativeAuthEmailOTPUserPool.ConfigurationError,
                .missingOrEmptyValue("user2")
            )
        }

        XCTAssertThrowsError(
            try MSALNativeAuthEmailOTPUserPool.make(
                configuration: ["user1": "first", "user2": "", "user3": "third"],
                keys: ["user1", "user2", "user3"]
            )
        ) { error in
            XCTAssertEqual(
                error as? MSALNativeAuthEmailOTPUserPool.ConfigurationError,
                .missingOrEmptyValue("user2")
            )
        }

        XCTAssertThrowsError(
            try MSALNativeAuthEmailOTPUserPool.make(
                configuration: ["user1": "duplicate", "user2": "duplicate", "user3": "third"],
                keys: ["user1", "user2", "user3"]
            )
        ) { error in
            XCTAssertEqual(
                error as? MSALNativeAuthEmailOTPUserPool.ConfigurationError,
                .duplicateValues
            )
        }
    }

    func test_emailOTPUsernameIsRetainedForCurrentTest() throws {
        let firstUsername = try emailOTPUsernameForCurrentTest()
        let secondUsername = try emailOTPUsernameForCurrentTest()

        XCTAssertEqual(firstUsername, secondUsername)
    }

    func test_emailOTPThrottleClassifierUsesErrorCodeAndDescription() {
        XCTAssertTrue(MSALNativeAuthEmailOTPErrorClassifier.isThrottleError(errorCodes: [701014], errorDescription: nil))
        XCTAssertTrue(
            MSALNativeAuthEmailOTPErrorClassifier.isThrottleError(
                errorCodes: [],
                errorDescription: "AADSTS701014: Cannot generate more one time passcodes"
            )
        )
    }

    func test_emailOTPThrottleClassifierIgnoresUnrelatedErrors() {
        XCTAssertFalse(
            MSALNativeAuthEmailOTPErrorClassifier.isThrottleError(
                errorCodes: [50034],
                errorDescription: "AADSTS50034: User account does not exist"
            )
        )
    }

    // Hero Scenario 2.2.1. Sign in - Use email and OTP to get token and sign in
    func test_signInAndSendingCorrectOTPResultsInSuccess() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let param = MSALNativeAuthSignInParameters(username: username)
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        try skipIfEmailOTPThrottled(signInDelegateSpy.error)

        guard signInDelegateSpy.onSignInCodeRequiredCalled else {
            XCTFail("onSignInCodeRequired not called")
            return
        }

        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: code, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation])

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)
    }

    // Hero Scenario 2.2.2. Sign in - User is not registered with given email
    func test_signInWithUnknownUsernameResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let unknownUsername = UUID().uuidString + "@contoso.com"

        let param = MSALNativeAuthSignInParameters(username: unknownUsername)
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isUserNotFound)
    }
    
    // User Case 2.2.3 Sign In - User email is registered with password method, which is not supported by client (aka redirect flow)
    func test_signInWithPasswordConfigInsufficientChallengeInError() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .password, challengeTypes: .OOB), let username = retrieveUsernameForSignInUsernameAndPassword() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let param = MSALNativeAuthSignInParameters(username: username)
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        // Verify error condition
        XCTAssertTrue(signInDelegateSpy.onSignInErrorCalled)
        XCTAssertEqual(signInDelegateSpy.error?.isBrowserRequired, true)
    }
    
    // User Case 2.2.5 Sign In - Resend email OTP
    func test_signUpWithEmailOTP_resendEmail_success() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegate = SignInStartDelegateSpy(expectation: signInExpectation)

        let param = MSALNativeAuthSignInParameters(username: username)
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegate)

        await fulfillment(of: [signInExpectation])
        try skipIfEmailOTPThrottled(signInDelegate.error)

        guard signInDelegate.onSignInCodeRequiredCalled else {
            XCTFail("OTP not sent")
            return
        }
        XCTAssertNotNil(signInDelegate.newStateCodeRequired)
        XCTAssertNotNil(signInDelegate.sentTo)
        
        // Now get code1...
        guard let code1 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }
        
        // Resend code
        let resendCodeRequiredExp = expectation(description: "code required again")
        let signInResendCodeDelegate = SignInResendCodeDelegateSpy(expectation: resendCodeRequiredExp)
        
        // Call resend code method
        signInDelegate.newStateCodeRequired?.resendCode(delegate: signInResendCodeDelegate)
        
        await fulfillment(of: [resendCodeRequiredExp])
        try skipIfEmailOTPThrottled(signInResendCodeDelegate.error)
            
        // Verify that resend code method was called
        XCTAssertTrue(signInResendCodeDelegate.onSignInResendCodeCodeRequiredCalled,
                          "Resend code method should have been called")
            
        // Now get code2...
        guard let code2 = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }
        
        // Verify that the codes are different
        XCTAssertNotEqual(code1, code2, "Resent code should be different from the original code")
        
        // Now submit the code..
        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        signInDelegate.newStateCodeRequired?.submitCode(code: code2, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation])

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)
    }
    
    /* User Case 2.2.6 Sign In - Ability to provide scope to control auth strength of the token
        Please refer to Crendentials test (test_signInWithExtraScopes())
     
        sut.signIn(username: username, password: password, scopes: ["User.Read"], correlationId: correlationId, delegate: signInDelegateSpy)
        ...
        XCTAssertTrue(credentialsDelegateSpy.result!.scopes.contains("User.Read"))
     */
    
    // Hero Scenario 2.2.7. Sign in - Invalid OTP code
    func test_signInAndSendingIncorrectOTPResultsInError() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let param = MSALNativeAuthSignInParameters(username: username)
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        try skipIfEmailOTPThrottled(signInDelegateSpy.error)

        guard signInDelegateSpy.onSignInCodeRequiredCalled else {
            XCTFail("OTP not sent")
            return
        }
        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: "00000000", delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation])

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInVerifyCodeErrorCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.error)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.error?.isInvalidCode, true)
    }
    
    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/<tenantName>.onmicrosoft.com"
    func test_signInCustomSubdomainLongInSuccess() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(clientIdType: .code, customAuthorityURLFormat: .tenantSubdomainLongVersion) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let param = MSALNativeAuthSignInParameters(username: username)
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        try skipIfEmailOTPThrottled(signInDelegateSpy.error)

        guard signInDelegateSpy.onSignInCodeRequiredCalled else {
            XCTFail("onSignInCodeRequired not called")
            return
        }

        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: code, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation])

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)
    }
    
    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/<tenantId>"
    func test_signInCustomSubdomainIdInSuccess() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(clientIdType: .code, customAuthorityURLFormat: .tenantSubdomainTenantId) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let param = MSALNativeAuthSignInParameters(username: username)
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        try skipIfEmailOTPThrottled(signInDelegateSpy.error)

        guard signInDelegateSpy.onSignInCodeRequiredCalled else {
            XCTFail("onSignInCodeRequired not called")
            return
        }

        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: code, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation])

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)
    }
    
    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/"
    func test_signInCustomSubdomainShortInSuccess() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(clientIdType: .code, customAuthorityURLFormat: .tenantSubdomainShortVersion) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let signInParam = MSALNativeAuthSignInParameters(username: username)
        signInParam.correlationId = correlationId
        sut.signIn(parameters: signInParam, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])
        try skipIfEmailOTPThrottled(signInDelegateSpy.error)

        guard signInDelegateSpy.onSignInCodeRequiredCalled else {
            XCTFail("onSignInCodeRequired not called")
            return
        }

        XCTAssertNotNil(signInDelegateSpy.newStateCodeRequired)
        XCTAssertNotNil(signInDelegateSpy.sentTo)

        // Now submit the code..

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let verifyCodeExpectation = expectation(description: "verifying code")
        let signInVerifyCodeDelegateSpy = SignInVerifyCodeDelegateSpy(expectation: verifyCodeExpectation)

        signInDelegateSpy.newStateCodeRequired?.submitCode(code: code, delegate: signInVerifyCodeDelegateSpy)

        await fulfillment(of: [verifyCodeExpectation])

        XCTAssertTrue(signInVerifyCodeDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result)
        XCTAssertNotNil(signInVerifyCodeDelegateSpy.result?.idToken)
        XCTAssertEqual(signInVerifyCodeDelegateSpy.result?.account.username, username)
    }
}
