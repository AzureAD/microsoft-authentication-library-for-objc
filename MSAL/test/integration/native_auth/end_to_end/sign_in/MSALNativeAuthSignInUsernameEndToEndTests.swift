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

final class MSALNativeAuthSignInUsernameEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {

    // Hero Scenario 2.2.2. Sign in - User is not registered with given email
    func test_signInWithUnknownUsernameResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code) else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        let unknownUsername = UUID().uuidString + "@contoso.com"

        sut.signIn(username: unknownUsername, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isUserNotFound)
    }

    // Hero Scenario 2.2.7. Sign in - Invalid OTP code
    func test_signInAndSendingIncorrectOTPResultsInError() async throws {

        guard let sut = initialisePublicClientApplication(clientIdType: .code), let username = retrieveUsernameForSignInCode() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

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

    // Hero Scenario 2.2.1. Sign in - Use email and OTP to get token and sign in
    func test_signInAndSendingCorrectOTPResultsInSuccess() async throws {

        guard let sut = initialisePublicClientApplication(clientIdType: .code), let username = retrieveUsernameForSignInCode() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

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
    
    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/<tenantName>.onmicrosoft.com"
    func test_signInCustomSubdomainLongInSuccess() async throws {
        guard let sut = initialisePublicClientApplication(clientIdType: .code, customAuthorityURLFormat: .tenantSubdomainLongVersion), let username = retrieveUsernameForSignInCode() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

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
        guard let sut = initialisePublicClientApplication(clientIdType: .code, customAuthorityURLFormat: .tenantSubdomainTenantId), let username = retrieveUsernameForSignInCode() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

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
        guard let sut = initialisePublicClientApplication(clientIdType: .code, customAuthorityURLFormat: .tenantSubdomainShortVersion), let username = retrieveUsernameForSignInCode() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

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
