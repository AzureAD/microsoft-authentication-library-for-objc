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

final class MSALNativeAuthSubErrorCodeTests: XCTestCase {
    private typealias sut = MSALNativeAuthSubErrorCode

    func test_allCases() {
        XCTAssertEqual(sut.allCases.count, 9)
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

    func test_passwordInvalid() {
        XCTAssertEqual(sut.passwordInvalid.rawValue, "password_is_invalid")
    }

    func test_attributeValidationFailed() {
        XCTAssertEqual(sut.attributeValidationFailed.rawValue, "attribute_validation_failed")
    }

    func test_invalidOOBValue() {
        XCTAssertEqual(sut.invalidOOBValue.rawValue, "invalid_oob_value")
    }
}
