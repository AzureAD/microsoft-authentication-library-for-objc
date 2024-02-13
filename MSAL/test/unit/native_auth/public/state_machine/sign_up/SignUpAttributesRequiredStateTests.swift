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
    private var correlationId: UUID = UUID()

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = .init()
        sut = SignUpAttributesRequiredState(controller: controller, username: "<username>", continuationToken: "<token>", correlationId: correlationId)
    }

    // MARK: - Delegate

    func test_submitPassword_delegate_whenError_shouldReturnAttributesRequiredError() {
        let expectedError = AttributesRequiredError(correlationId: correlationId)

        let expectedResult: SignUpAttributesRequiredResult = .error(error: expectedError)
        controller.submitAttributesResult = .init(expectedResult, correlationId: correlationId)

        let exp = expectation(description: "sign-up states")
        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp])

        XCTAssertEqual(delegate.error, expectedError)
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func test_submitPassword_delegate_whenSuccess_shouldReturnCompleted() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", continuationToken: "continuationToken", correlationId: correlationId)

        let expectedResult: SignUpAttributesRequiredResult = .completed(expectedState)
        controller.submitAttributesResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newSignInAfterSignUpState, expectedState)
    }

    func test_submitPassword_delegate_whenSuccess_butMethodNotImplemented_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignInAfterSignUpState(controller: MSALNativeAuthSignInControllerMock(), username: "", continuationToken: "continuationToken", correlationId: UUID())

        let expectedResult: SignUpAttributesRequiredResult = .completed(expectedState)
        controller.submitAttributesResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpAttributesRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpCompleted"))
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func test_submitPassword_delegate_whenAttributesRequired_shouldReturnAttributesRequired() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignUpAttributesRequiredState(controller: MSALNativeAuthSignUpControllerMock(), username: "", continuationToken: "continuationToken", correlationId: correlationId)
        let expectedAttributes: [MSALNativeAuthRequiredAttribute] = [
            .init(name: "anAttribute", type: "aType", required: true)
        ]

        let expectedResult: SignUpAttributesRequiredResult = .attributesRequired(attributes: expectedAttributes, state: expectedState)
        controller.submitAttributesResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.attributes, expectedAttributes)
        XCTAssertEqual(delegate.newState, expectedState)
    }

    func test_submitPassword_delegate_whenAttributesRequired_butMethodNotImplemented_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignUpAttributesRequiredState(controller: MSALNativeAuthSignUpControllerMock(), username: "", continuationToken: "continuationToken", correlationId: correlationId)
        let expectedAttributes: [MSALNativeAuthRequiredAttribute] = [
            .init(name: "anAttribute", type: "aType", required: true)
        ]

        let expectedResult: SignUpAttributesRequiredResult = .attributesRequired(attributes: expectedAttributes, state: expectedState)
        controller.submitAttributesResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpAttributesRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesRequired"))
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func test_submitPassword_delegate_whenAttributesAreInvalid_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignUpAttributesRequiredState(controller: MSALNativeAuthSignUpControllerMock(), username: "", continuationToken: "continuationToken", correlationId: correlationId)
        let expectedAttributes = ["anAttribute"]

        let expectedResult: SignUpAttributesRequiredResult = .attributesInvalid(attributes: expectedAttributes, newState: expectedState)
        controller.submitAttributesResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.invalidAttributes, expectedAttributes)
        XCTAssertEqual(delegate.newState, expectedState)
    }

    func test_submitPassword_delegate_whenAttributesAreInvalid_butMethodNotImplemented_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up states")
        let exp2 = expectation(description: "telemetry expectation")
        let expectedState = SignUpAttributesRequiredState(controller: MSALNativeAuthSignUpControllerMock(), username: "", continuationToken: "continuationToken", correlationId: correlationId)
        let expectedAttributes = ["anAttribute"]

        let expectedResult: SignUpAttributesRequiredResult = .attributesInvalid(attributes: expectedAttributes, newState: expectedState)
        controller.submitAttributesResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let delegate = SignUpAttributesRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        sut.submitAttributes(attributes: ["key":"value"], delegate: delegate)
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.errorDescription, String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesInvalid"))
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }
}
