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

import Foundation

import XCTest
@testable import MSAL

final class SignUpAttributesRequiredStateTests: XCTestCase {

    private var exp: XCTestExpectation!
    private var correlationId: UUID!
    private var controller: MSALNativeAuthSignUpControllerSpy!
    private var sut: SignUpAttributesRequiredState!

    override func setUpWithError() throws {
        try super.setUpWithError()

        correlationId = UUID()
        exp = expectation(description: "SignUpAttributesRequiredState expectation")
        controller = MSALNativeAuthSignUpControllerSpy(expectation: exp)
        sut = SignUpAttributesRequiredState(controller: controller, flowToken: "<token>")
    }

    func test_submitAttributes_usesControllerSuccessfully() {
        XCTAssertNil(controller.context)
        XCTAssertFalse(controller.submitAttributesCalled)

        sut.submitAttributes(attributes: ["city": "Dublin"], delegate: SignUpAttributesRequiredDelegateSpy(), correlationId: correlationId)

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(controller.context?.correlationId(), correlationId)
        XCTAssertTrue(controller.submitAttributesCalled)
    }
}
