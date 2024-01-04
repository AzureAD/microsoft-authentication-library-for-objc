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

@testable import MSAL
import XCTest

class ResetPasswordStartTestsValidatorHelper: ResetPasswordStartDelegateSpy {

    func onResetPasswordError(_ input: MSALNativeAuthResetPasswordController.ResetPasswordStartControllerResponse) {
        guard case let .error(error) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be an .error")
        }

        Task { await self.onResetPasswordStartError(error: error) }
    }

    func onResetPasswordCodeRequired(_ input: MSALNativeAuthResetPasswordController.ResetPasswordStartControllerResponse) {
        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .codeRequired")
        }

        Task {
            await self.onResetPasswordCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength)
        }
    }
}

class ResetPasswordResendCodeTestsValidatorHelper: ResetPasswordResendCodeDelegateSpy {

    func onResetPasswordResendCodeError(_ input: MSALNativeAuthResetPasswordController.ResetPasswordResendCodeControllerResponse) {
        guard case let .error(error, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("should be .error")
        }

        Task { await self.onResetPasswordResendCodeError(error: error, newState: newState) }
    }

    func onResetPasswordResendCodeRequired(_ input: MSALNativeAuthResetPasswordController.ResetPasswordResendCodeControllerResponse) {
        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation?.fulfill()
            return XCTFail("Should be .codeRequired")
        }

        Task {
            await self.onResetPasswordResendCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength)
        }
    }
}

class ResetPasswordVerifyCodeTestsValidatorHelper: ResetPasswordVerifyCodeDelegateSpy {

    func onResetPasswordVerifyCodeError(_ input: MSALNativeAuthResetPasswordController.ResetPasswordSubmitCodeControllerResponse) {
        guard case let .error(error, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("should be .error")
        }

        Task { await self.onResetPasswordVerifyCodeError(error: error, newState: newState) }
    }

    func onPasswordRequired(_ input: MSALNativeAuthResetPasswordController.ResetPasswordSubmitCodeControllerResponse) {
        guard case let .passwordRequired(newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("should be .success")
        }

        Task { await self.onPasswordRequired(newState: newState) }
    }
}

class ResetPasswordRequiredTestsValidatorHelper: ResetPasswordRequiredDelegateSpy {

    func onResetPasswordRequiredError(_ input: MSALNativeAuthResetPasswordController.ResetPasswordSubmitPasswordControllerResponse) {
        guard case let .error(error, newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("should be .error")
        }

        Task { await self.onResetPasswordRequiredError(error: error, newState: newState) }
    }

    func onResetPasswordCompleted(_ input: MSALNativeAuthResetPasswordController.ResetPasswordSubmitPasswordControllerResponse) {
        guard case let .completed(newState) = input.result else {
            expectation?.fulfill()
            return XCTFail("should be .success")
        }

        Task { await self.onResetPasswordCompleted(newState: newState) }
    }
}
