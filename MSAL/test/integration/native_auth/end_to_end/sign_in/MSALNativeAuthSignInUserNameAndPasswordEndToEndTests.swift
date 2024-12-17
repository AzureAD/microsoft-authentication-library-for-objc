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

    // Hero Scenario 1.2.1. Sign in - Use email and password to get token
    func test_signInUsingPasswordWithKnownUsernameResultsInSuccess() async throws {
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
    
    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/<tenantName>.onmicrosoft.com"
    func test_signInCustomDomain1InSuccess() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: AuthorityURLFormat.tenantSubdomainLongVersion) else {
            XCTFail("Failed to initialise auth client")
            return
        }

        guard let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "Signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)
        
        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
    }
    
    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/<tenantId>"
    func test_signInCustomDomain2InSuccess() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: AuthorityURLFormat.tenantSubdomainTenantId) else {
            XCTFail("Failed to initialise auth client")
            return
        }

        guard let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "Signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)


        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)
        
        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
    }
    
    // Sign In - Verify Custom URL Domain - "https://<tenantName>.ciamlogin.com/"
    func test_signInCustomDomain3InSuccess() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: AuthorityURLFormat.tenantSubdomainShortVersion) else {
            XCTFail("Failed to initialise auth client")
            return
        }

        guard let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "Signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        
        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
    }
}
