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

final class MSALNativeAuthSignInUsernameAndPasswordEndToEndTests: MSALNativeAuthEndToEndBaseTestCase {
    func test_signInUsingPasswordWithUnknownUsernameResultsInError() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let unknownUsername = UUID().uuidString

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
            try await mockResponse(.userNotFound, endpoint: .signInToken)
        }

        sut.signIn(username: unknownUsername, password: "testpass", correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isUserNotFound)
    }

    func test_signInWithKnownUsernameInvalidPasswordResultsInError() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
            try await mockResponse(.invalidPassword, endpoint: .signInToken)
        }

        sut.signIn(username: username, password: "An Invalid Password", correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInPasswordErrorCalled)
        XCTAssertTrue(signInDelegateSpy.error!.isInvalidCredentials)
    }

    // Hero Scenario 2.2.1. Sign in – Email and Password on SINGLE screen (Email & Password)
    func test_signInUsingPasswordWithKnownUsernameResultsInSuccess() async throws {
        try XCTSkipIf(!usingMockAPI)

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let username = ProcessInfo.processInfo.environment["existingPasswordUserEmail"] ?? "<existingPasswordUserEmail not set>"
        let password = ProcessInfo.processInfo.environment["existingUserPassword"] ?? "<existingUserPassword not set>"

        if usingMockAPI {
            try await mockResponse(.initiateSuccess, endpoint: .signInInitiate)
            try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
            try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        }

        sut.signIn(username: username, password: password, correlationId: correlationId, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation], timeout: 2)

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
    }
}
