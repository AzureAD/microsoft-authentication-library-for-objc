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

import XCTest
@testable import MSAL

final class MSALNativeAuthEndpointTests: XCTestCase {

    private typealias sut = MSALNativeAuthEndpoint

    func test_allEndpoints_are_tested() {
        XCTAssertEqual(sut.allCases.count, 14)
    }

    func test_signUp_start() {
        XCTAssertEqual(sut.signUpStart.rawValue, "/signup/start")
    }

    func test_signUp_challenge() {
        XCTAssertEqual(sut.signUpChallenge.rawValue, "/signup/challenge")
    }

    func test_signUp_continue() {
        XCTAssertEqual(sut.signUpContinue.rawValue, "/signup/continue")
    }

    func test_signUp_endpoint() {
        XCTAssertEqual(sut.signUp.rawValue, "/signup")
    }

    func test_signInInitiate_endpoint() {
        XCTAssertEqual(sut.signInInitiate.rawValue, "/oauth/v2.0/initiate")
    }

    func test_signInChallenge_endpoint() {
        XCTAssertEqual(sut.signInChallenge.rawValue, "/oauth/v2.0/challenge")
    }

    func test_signInToken_endpoint() {
        XCTAssertEqual(sut.token.rawValue, "/oauth/v2.0/token")
    }

    func test_signIn_endpoint() {
        XCTAssertEqual(sut.signIn.rawValue, "/signin")
    }

    func test_refreshToken_endpoint() {
        XCTAssertEqual(sut.refreshToken.rawValue, "/refreshtoken")
    }

    func test_resetPasswordStart_endpoint() {
        XCTAssertEqual(sut.resetPasswordStart.rawValue, "/resetpassword/start")
    }

    func test_resetPasswordComplete_endpoint() {
        XCTAssertEqual(sut.resetPasswordComplete.rawValue, "/resetpassword/complete")
    }

    func test_resendCode_endpoint() {
        XCTAssertEqual(sut.resendCode.rawValue, "/resendcode")
    }

    func test_verifyCode_endpoint() {
        XCTAssertEqual(sut.verifyCode.rawValue, "/verifycode")
    }

    func test_signOut_endpoint() {
        XCTAssertEqual(sut.signOut.rawValue, "/signout")
    }
}
