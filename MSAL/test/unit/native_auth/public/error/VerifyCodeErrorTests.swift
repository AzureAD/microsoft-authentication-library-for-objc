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

final class VerifyCodeErrorTests: XCTestCase {

    private var sut: VerifyCodeError!

    func test_totalCases() {
        XCTAssertEqual(VerifyCodeError.ErrorType.allCases.count, 3)
    }

    func test_customErrorDescription() {
        let expectedMessage = "Custom error message"
        sut = .init(type: .generalError, message: expectedMessage, correlationId: .init())
        XCTAssertEqual(sut.errorDescription, expectedMessage)
    }

    func test_defaultErrorDescription() {
        let sut: [VerifyCodeError] = [
            .init(type: .browserRequired, correlationId: .init()),
            .init(type: .invalidCode, correlationId: .init()),
            .init(type: .generalError, correlationId: .init())
        ]

        let expectedDescriptions = [
            MSALNativeAuthErrorMessage.browserRequired,
            MSALNativeAuthErrorMessage.invalidCode,
            MSALNativeAuthErrorMessage.generalError
        ]

        let errorDescriptions = sut.map { $0.errorDescription }

        zip(errorDescriptions, expectedDescriptions).forEach {
            XCTAssertEqual($0, $1)
        }
    }

    func test_isBrowserRequired() {
        sut = .init(type: .browserRequired, correlationId: .init())
        XCTAssertTrue(sut.isBrowserRequired)
        XCTAssertFalse(sut.isInvalidCode)
    }

    func test_isInvalidCode() {
        sut = .init(type: .invalidCode, correlationId: .init())
        XCTAssertTrue(sut.isInvalidCode)
        XCTAssertFalse(sut.isBrowserRequired)
    }
}
