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

final class MSALNativeAuthSignUpStartOauth2ErrorCodeTests: XCTestCase {

    private typealias sut = MSALNativeAuthSignUpStartOauth2ErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 13)
    }

    func test_invalidRequest() {
        XCTAssertEqual(sut.invalidRequest.rawValue, "invalid_request")
    }

    func test_unauthorizedClient() {
        XCTAssertEqual(sut.unauthorizedClient.rawValue, "unauthorized_client")
    }
    
    func test_unsupportedChallengeType() {
        XCTAssertEqual(sut.unsupportedChallengeType.rawValue, "unsupported_challenge_type")
    }

    func test_passwordTooWeak() {
        XCTAssertEqual(sut.passwordTooWeak.rawValue, "password_too_weak")
    }

    func test_passwordTooShort() {
        XCTAssertEqual(sut.passwordTooShort.rawValue, "password_too_short")
    }

    func test_passwordTooLong() {
        XCTAssertEqual(sut.passwordTooLong.rawValue, "password_too_long")
    }

    func test_passwordRecentlyUsed() {
        XCTAssertEqual(sut.passwordRecentlyUsed.rawValue, "password_recently_used")
    }

    func test_passwordBanned() {
        XCTAssertEqual(sut.passwordBanned.rawValue, "password_banned")
    }

    func test_userAlreadyExists() {
        XCTAssertEqual(sut.userAlreadyExists.rawValue, "user_already_exists")
    }

    func test_attributesRequired() {
        XCTAssertEqual(sut.attributesRequired.rawValue, "attributes_required")
    }

    func test_verificationRequired() {
        XCTAssertEqual(sut.verificationRequired.rawValue, "verification_required")
    }
    
    func test_authNotSupported() {
        XCTAssertEqual(sut.authNotSupported.rawValue, "auth_not_supported")
    }

    func test_attributeValidationFailed() {
        XCTAssertEqual(sut.attributeValidationFailed.rawValue, "attribute_validation_failed")
    }
}
