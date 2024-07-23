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

    // Hero Scenario 2.2.1. Sign in – Email and Password on SINGLE screen (Email & Password)
    func test_signInUsingPasswordWithKnownUsernameResultsInSuccess() async throws {
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        guard signInDelegateSpy.error == nil else {
            XCTFail("Error: \(signInDelegateSpy.error?.errorDescription)")
            return
        }

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
    }
    
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

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordRequiredCalled)
        XCTAssertNotNil(signInDelegateSpy.newStatePasswordRequired)

        // Now submit the password..

        signInDelegateSpy.newStatePasswordRequired?.submitPassword(password: "An Invalid Password", delegate: signInPasswordRequiredDelegateSpy)

        await fulfillment(of: [passwordRequiredExpectation])

        XCTAssertTrue(signInPasswordRequiredDelegateSpy.onSignInPasswordRequiredErrorCalled)
        XCTAssertEqual(signInPasswordRequiredDelegateSpy.error?.isInvalidPassword, true)
    }
}
