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

    private var controller: MSALNativeAuthSignUpControllerMock!
    private var sut: SignUpAttributesRequiredState!

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init()
        sut = SignUpAttributesRequiredState(controller: controller, username: "<username>", continuationToken: "<continuation_token>")
    }

    // MARK: - Delegate

    func test_submitPassword_delegate_whenError_shouldReturnAttributesRequiredError() {
        let expectedError = AttributesRequiredError()

        let expectedResult: SignUpAttributesRequiredResult = .error(error: expectedError)
        controller.submitAttributesResult = .init(expectedResult)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
    }

    func test_submitPassword_delegate_whenSuccess_shouldReturnCompleted() {
        let expectedState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", slt: "slt")

        let expectedResult: SignUpAttributesRequiredResult = .completed(expectedState)
        controller.submitAttributesResult = .init(expectedResult)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.newSignInAfterSignUpState, expectedState)
    }

    func test_submitPassword_delegate_whenAttributesRequired_shouldReturnAttributesRequired() {
        let expectedState = SignUpAttributesRequiredState(controller: MSALNativeAuthSignUpControllerMock(), username: "", continuationToken: "slt")
        let expectedAttributes: [MSALNativeAuthRequiredAttributes] = [
            .init(name: "anAttribute", type: "aType", required: true)
        ]

        let expectedResult: SignUpAttributesRequiredResult = .attributesRequired(attributes: expectedAttributes, state: expectedState)
        controller.submitAttributesResult = .init(expectedResult)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.attributes, expectedAttributes)
        XCTAssertEqual(delegate.newState, expectedState)
    }

    func test_submitPassword_delegate_whenAttributesAreInvalud_shouldReturnAttributesInvalid() {
        let expectedState = SignUpAttributesRequiredState(controller: MSALNativeAuthSignUpControllerMock(), username: "", continuationToken: "slt")
        let expectedAttributes = ["anAttribute"]

        let expectedResult: SignUpAttributesRequiredResult = .attributesInvalid(attributes: expectedAttributes, newState: expectedState)
        controller.submitAttributesResult = .init(expectedResult)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.invalidAttributes, expectedAttributes)
        XCTAssertEqual(delegate.newState, expectedState)
    }
}
