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
        XCTAssertEqual(sut.allCases.count, 12)
    }

    func test_signUp_start() {
        XCTAssertEqual(sut.signUpStart.rawValue, "/signup/v1.0/start")
    }

    func test_signUp_challenge() {
        XCTAssertEqual(sut.signUpChallenge.rawValue, "/signup/v1.0/challenge")
    }

    func test_signUp_continue() {
        XCTAssertEqual(sut.signUpContinue.rawValue, "/signup/v1.0/continue")
    }

    func test_signInInitiate_endpoint() {
        XCTAssertEqual(sut.signInInitiate.rawValue, "/oauth2/v2.0/initiate")
    }

    func test_signInChallenge_endpoint() {
        XCTAssertEqual(sut.signInChallenge.rawValue, "/oauth2/v2.0/challenge")
    }

    func test_token_endpoint() {
        XCTAssertEqual(sut.token.rawValue, "/oauth2/v2.0/token")
    }

    func test_resetPasswordStart_endpoint() {
        XCTAssertEqual(sut.resetPasswordStart.rawValue, "/resetpassword/v1.0/start")
    }

    func test_resetPasswordChallenge_endpoint() {
        XCTAssertEqual(sut.resetPasswordChallenge.rawValue, "/resetpassword/v1.0/challenge")
    }

    func test_resetPasswordContinue_endpoint() {
        XCTAssertEqual(sut.resetPasswordContinue.rawValue, "/resetpassword/v1.0/continue")
    }

    func test_resetPasswordSubmit_endpoint() {
        XCTAssertEqual(sut.resetPasswordSubmit.rawValue, "/resetpassword/v1.0/submit")
    }

    func test_resetPasswordComplete_endpoint() {
        XCTAssertEqual(sut.resetPasswordComplete.rawValue, "/resetpassword/v1.0/complete")
    }
}
