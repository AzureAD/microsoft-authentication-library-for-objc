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

final class MSALNativeAuthSignOutEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {
    // Hero Scenario 2.4.1. Sign out – Local sign out from app on device (no SSO)
    func test_signOutAfterSignInPasswordSuccess() async throws {
        // TOOD: This will be re-enabled as part of another PBI
#if os(macOS)
        throw XCTSkip("Keychain access is not active on the macOS app")
#endif
        guard let sut = initialisePublicClientApplication(),
              let username = retrieveUsernameForSignInUsernameAndPassword(),
              let password = await retrievePasswordForSignInUsername()
        else {
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

        // Sign out

        var userAccountResult = sut.getNativeAuthUserAccount()
        XCTAssertNotNil(userAccountResult)
        userAccountResult?.signOut()

        userAccountResult = sut.getNativeAuthUserAccount()
        XCTAssertNil(userAccountResult)
    }
}
