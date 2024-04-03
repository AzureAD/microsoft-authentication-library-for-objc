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

class SignInPasswordStartTestsValidatorHelper: SignInPasswordStartDelegateSpy {

    func onSignInPasswordError(_ input: MSALNativeAuthSignInController.SignInControllerResponse) {
        guard case let .error(error) = input.result else {
            expectation.fulfill()
            return XCTFail("input should be .error")
        }
        
        Task { await self.onSignInStartError(error: error) }
    }

    func onSignInCodeRequired(_ input: MSALNativeAuthSignInController.SignInControllerResponse) {

        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation.fulfill()
            return XCTFail("input should be .codeRequired")
        }

        Task { await self.onSignInCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength) }
    }
    
    func onSignInCompleted(_ input: MSALNativeAuthSignInController.SignInControllerResponse) {
        guard case let .completed(result) = input.result else {
            expectation.fulfill()
            return XCTFail("input should be .success")
        }

        Task { await self.onSignInCompleted(result: result) }
    }
}

class SignInPasswordRequiredTestsValidatorHelper: SignInPasswordRequiredDelegateSpy {

    func onSignInPasswordRequiredError(_ input: SignInPasswordRequiredResult) {
        guard case let .error(error, newState) = input else {
            expectation.fulfill()
            return XCTFail("input should be .error")
        }

        Task { await self.onSignInPasswordRequiredError(error: error, newState: newState) }
    }

    func onSignInCompleted(_ input: SignInPasswordRequiredResult) {
        guard case let .completed(result) = input else {
            expectation.fulfill()
            return XCTFail("input should be .complete")
        }

        Task { await self.onSignInCompleted(result: result) }
    }
}

class SignInCodeStartTestsValidatorHelper: SignInCodeStartDelegateSpy {
    
    func onSignInError(_ input: MSALNativeAuthSignInControlling.SignInControllerResponse) {
        guard case let .error(error) = input.result else {
            expectation.fulfill()
            return XCTFail("input should be .error")
        }

        Task { await self.onSignInStartError(error: error) }
    }
    
    func onSignInCodeRequired(_ input: MSALNativeAuthSignInControlling.SignInControllerResponse) {
        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation.fulfill()
            return XCTFail("input should be .codeRequired")
        }

        Task { await self.onSignInCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength) }
    }
}

class SignInResendCodeTestsValidatorHelper: SignInResendCodeDelegateSpy {
    
    func onSignInResendCodeError(_ input: MSALNativeAuthSignInController.SignInResendCodeControllerResponse) {
        guard case let .error(error, newState) = input.result else {
            expectation.fulfill()
            return XCTFail("input should be .error")
        }

        Task { await self.onSignInResendCodeError(error: error, newState: newState) }
    }

    func onSignInResendCodeCodeRequired(_ input: MSALNativeAuthSignInController.SignInResendCodeControllerResponse) {
        guard case let .codeRequired(newState, sentTo, channelTargetType, codeLength) = input.result else {
            expectation.fulfill()
            return XCTFail("input should be .codeRequired")
        }

        Task {
            await self.onSignInResendCodeCodeRequired(newState: newState, sentTo: sentTo, channelTargetType: channelTargetType, codeLength: codeLength)
        }
    }
}

class SignInCodeStartWithPasswordRequiredTestsValidatorHelper: SignInCodeStartDelegateWithPasswordRequiredSpy {
    func onSignInPasswordRequired(_ input: SignInStartResult) {
        guard case let .passwordRequired(newState) = input else {
            expectation.fulfill()
            return XCTFail("input should be .passwordRequired")
        }

        self.onSignInPasswordRequired(newState: newState)
    }
}
