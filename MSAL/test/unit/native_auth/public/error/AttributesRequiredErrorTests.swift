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
@_implementationOnly import MSAL_Unit_Test_Private

final class AttributesRequiredErrorTests: XCTestCase {

    private var sut: AttributesRequiredError!

    func test_customErrorDescription() {
        let expectedMessage = "Custom error message"
        let uuid = UUID(uuidString: DEFAULT_TEST_UID)!

        sut = .init(type: .generalError, message: expectedMessage, correlationId: uuid)
        
        XCTAssertEqual(sut.errorDescription, expectedMessage)
        XCTAssertEqual(sut.correlationId, uuid)
    }

    func test_defaultErrorDescription() {
        let uuid = UUID(uuidString: DEFAULT_TEST_UID)!
        
        let sut: [AttributesRequiredError] = [
            .init(type: .browserRequired, correlationId: uuid),
            .init(type: .generalError, correlationId: uuid)
        ]

        let expectedDescriptions = [
            MSALNativeAuthErrorMessage.browserRequired,
            MSALNativeAuthErrorMessage.generalError
        ]

        for (index, element) in sut.enumerated() {
            XCTAssertEqual(element.errorDescription, expectedDescriptions[index])
            XCTAssertEqual(element.correlationId, uuid)
        }
    }
}
