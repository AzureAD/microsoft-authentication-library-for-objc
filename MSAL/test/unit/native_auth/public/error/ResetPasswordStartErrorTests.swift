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

final class ResetPasswordStartErrorTests: XCTestCase {

    private var sut: ResetPasswordStartError!

    func test_totalCases() {
        XCTAssertEqual(ResetPasswordStartError.ErrorType.allCases.count, 5)
    }

    func test_customErrorDescription() {
        let expectedMessage = "Custom error message"
        sut = .init(type: .generalError, message: expectedMessage, correlationId: .init())
        XCTAssertEqual(sut.errorDescription, expectedMessage)
    }

    func test_defaultErrorDescription() {
        let sut: [ResetPasswordStartError] = [
            .init(type: .browserRequired, correlationId: .init()),
            .init(type: .userDoesNotHavePassword, correlationId: .init()),
            .init(type: .userNotFound, correlationId: .init()),
            .init(type: .invalidUsername, correlationId: .init()),
            .init(type: .generalError, correlationId: .init())
        ]

        let expectedIdentifiers = [
            MSALNativeAuthErrorMessage.browserRequired,
            MSALNativeAuthErrorMessage.userDoesNotHavePassword,
            MSALNativeAuthErrorMessage.userNotFound,
            MSALNativeAuthErrorMessage.invalidUsername,
            MSALNativeAuthErrorMessage.generalError
        ]

        let errorDescriptions = sut.map { $0.errorDescription }

        zip(errorDescriptions, expectedIdentifiers).forEach {
            XCTAssertEqual($0, $1)
        }
    }

    func test_isBrowserRequired() {
        sut = .init(type: .browserRequired, correlationId: .init())
        XCTAssertTrue(sut.isBrowserRequired)
        XCTAssertFalse(sut.isUserDoesNotHavePassword)
        XCTAssertFalse(sut.isUserNotFound)
        XCTAssertFalse(sut.isInvalidUsername)
    }

    func test_isUserDoesNotHaveAPassword() {
        sut = .init(type: .userDoesNotHavePassword, correlationId: .init())
        XCTAssertTrue(sut.isUserDoesNotHavePassword)
        XCTAssertFalse(sut.isBrowserRequired)
        XCTAssertFalse(sut.isUserNotFound)
        XCTAssertFalse(sut.isInvalidUsername)
    }

    func test_isUserNotFound() {
        sut = .init(type: .userNotFound, correlationId: .init())
        XCTAssertTrue(sut.isUserNotFound)
        XCTAssertFalse(sut.isBrowserRequired)
        XCTAssertFalse(sut.isUserDoesNotHavePassword)
        XCTAssertFalse(sut.isInvalidUsername)
    }

    func test_isInvalidUsername() {
        sut = .init(type: .invalidUsername, correlationId: .init())
        XCTAssertTrue(sut.isInvalidUsername)
        XCTAssertFalse(sut.isBrowserRequired)
        XCTAssertFalse(sut.isUserDoesNotHavePassword)
        XCTAssertFalse(sut.isUserNotFound)
    }
}
