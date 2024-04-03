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

class SignUpPasswordStartTestsValidatorHelper: SignUpPasswordStartDelegateSpy {

    func onSignUpPasswordStartError(_ input: MSALNativeAuthSignUpControlling.SignUpStartControllerResponse) {
        guard case let .error(error) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpStartError(error: error)
        }
    }

    func onSignUpCodeRequired(_ input: MSALNativeAuthSignUpControlling.SignUpStartControllerResponse) {
        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .codeRequired")
        }

        Task {
            await self.onSignUpCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength)
        }
    }

    func onSignUpAttributesInvalid(_ input: MSALNativeAuthSignUpControlling.SignUpStartControllerResponse) {
        guard case let .attributesInvalid(attributes) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .attributeValidationFailed")
        }

        Task {
            await self.onSignUpAttributesInvalid(attributeNames: attributes)
        }
    }
}

class SignUpCodeStartTestsValidatorHelper: SignUpCodeStartDelegateSpy {

    func onSignUpStartError(_ input: MSALNativeAuthSignUpControlling.SignUpStartControllerResponse) {
        guard case let .error(error) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpStartError(error: error)
        }
    }

    func onSignUpCodeRequired(_ input: MSALNativeAuthSignUpControlling.SignUpStartControllerResponse) {
        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .codeRequired")
        }

        Task {
            await self.onSignUpCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength)
        }
    }

    func onSignUpAttributesInvalid(_ input: MSALNativeAuthSignUpControlling.SignUpStartControllerResponse) {
        guard case let .attributesInvalid(attributes) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .attributeValidationFailed")
        }

        Task {
            await self.onSignUpAttributesInvalid(attributeNames: attributes)
        }
    }
}

class SignUpResendCodeTestsValidatorHelper: SignUpResendCodeDelegateSpy {

    func onSignUpResendCodeError(_ input: MSALNativeAuthSignUpController.SignUpResendCodeControllerResponse) {
        guard case let .error(error, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpResendCodeError(error: error, newState: newState)
        }
    }

    func onSignUpResendCodeCodeRequired(_ input: MSALNativeAuthSignUpController.SignUpResendCodeControllerResponse) {
        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .codeRequired")
        }
        
        Task {
            await self.onSignUpResendCodeCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength)
        }
    }
}

class SignUpVerifyCodeTestsValidatorHelper: SignUpVerifyCodeDelegateSpy {

    func onSignUpVerifyCodeError(_ input: MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse) {
        guard case let .error(error, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpVerifyCodeError(error: error, newState: newState)
        }
    }

    func onSignUpAttributesRequired(_ input: MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse) {
        guard case let .attributesRequired(attributes, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpAttributesRequired(attributes: attributes, newState: newState)
        }
    }

    func onSignUpPasswordRequired(_ input: MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse) {
        guard case let .passwordRequired(newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpPasswordRequired(newState: newState)
        }
    }

    func onSignUpCompleted(_ input: MSALNativeAuthSignUpControlling.SignUpSubmitCodeControllerResponse) {
        guard case let .completed(newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpCompleted(newState: newState)
        }
    }
}

class SignUpPasswordRequiredTestsValidatorHelper: SignUpPasswordRequiredDelegateSpy {

    func onSignUpPasswordRequiredError(_ input: MSALNativeAuthSignUpControlling.SignUpSubmitPasswordControllerResponse) {
        guard case let .error(error, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpPasswordRequiredError(error: error, newState: newState)
        }
    }

    func onSignUpAttributesRequired(_ input: MSALNativeAuthSignUpControlling.SignUpSubmitPasswordControllerResponse) {
        guard case let .attributesRequired(attributes, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpAttributesRequired(attributes: attributes, newState: newState)
        }
    }

    func onSignUpCompleted(_ input: MSALNativeAuthSignUpControlling.SignUpSubmitPasswordControllerResponse) {
        guard case let .completed(newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task {
            await self.onSignUpCompleted(newState: newState)
        }
    }
}

class SignUpAttributesRequiredTestsValidatorHelper {
    private let expectation: XCTestExpectation?
    private(set) var onSignUpAttributesRequiredCalled = false
    private(set) var onSignUpInvalidAttributesCalled = false
    private(set) var onSignUpAttributesRequiredErrorCalled = false
    private(set) var onSignUpCompletedCalled = false
    private(set) var error: AttributesRequiredError?
    private(set) var newState: SignUpAttributesRequiredState?
    private(set) var signInAfterSignUpState: SignInAfterSignUpState?
    private(set) var attributes: [MSALNativeAuthRequiredAttribute]?
    private(set) var invalidAttributes: [String]?

    init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    func onSignUpAttributesRequired(_ input: MSALNativeAuthSignUpController.SignUpSubmitAttributesControllerResponse) {
        guard case let .attributesRequired(attributes, state) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .attributesInvalid")
        }

        onSignUpAttributesRequiredCalled = true
        self.attributes = attributes
        self.newState = state

        expectation?.fulfill()
    }

    func onSignUpAttributesRequiredError(_ input: MSALNativeAuthSignUpController.SignUpSubmitAttributesControllerResponse) {
        guard case let .error(error) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        onSignUpAttributesRequiredErrorCalled = true
        self.error = error

        expectation?.fulfill()
    }

    func onSignUpAttributesValidationFailed(_ input: MSALNativeAuthSignUpController.SignUpSubmitAttributesControllerResponse) {
        guard case let .attributesInvalid(attributes, state) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        self.onSignUpInvalidAttributesCalled = true
        self.invalidAttributes = attributes
        self.newState = state

        expectation?.fulfill()
    }

    func onSignUpCompleted(_ input: MSALNativeAuthSignUpController.SignUpSubmitAttributesControllerResponse) {
        guard case .completed = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        onSignUpCompletedCalled = true

        expectation?.fulfill()
    }
}
