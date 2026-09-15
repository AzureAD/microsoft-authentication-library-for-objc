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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import XCTest
import MSAL

@MainActor
final class SignUpV2DelegateSpy: NSObject,
    MSALNativeAuthCodeRequiredDelegate,
    MSALNativeAuthAttributesRequiredDelegate,
    MSALNativeAuthAttributesInvalidDelegate,
    MSALNativeAuthSignInAfterSignUpRequiredDelegate {

    private var expectation: XCTestExpectation

    private(set) var onCodeRequiredCalled = false
    private(set) var onAttributesRequiredCalled = false
    private(set) var onAttributesInvalidCalled = false
    private(set) var onSignInAfterSignUpRequiredCalled = false
    private(set) var onFlowCompletedCalled = false
    private(set) var onFlowErrorCalled = false

    private(set) var codeRequiredState: MSALNativeAuthCodeRequiredState?
    private(set) var attributesRequiredState: MSALNativeAuthAttributesRequiredState?
    private(set) var attributesInvalidState: MSALNativeAuthAttributesInvalidState?
    private(set) var signInAfterSignUpState: MSALNativeAuthSignInAfterSignUpState?
    private(set) var result: MSALNativeAuthUserAccountResult?
    private(set) var error: MSALNativeAuthFlowError?
    private(set) var scenario: MSALNativeAuthFlowScenario?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength = 0
    private(set) var requiredAttributes: [MSALNativeAuthRequiredAttribute] = []
    private(set) var invalidAttributeNames: [String] = []

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
        super.init()
    }

    func reset(expectation: XCTestExpectation) {
        self.expectation = expectation
        onCodeRequiredCalled = false
        onAttributesRequiredCalled = false
        onAttributesInvalidCalled = false
        onSignInAfterSignUpRequiredCalled = false
        onFlowCompletedCalled = false
        onFlowErrorCalled = false
        codeRequiredState = nil
        attributesRequiredState = nil
        attributesInvalidState = nil
        signInAfterSignUpState = nil
        result = nil
        error = nil
        scenario = nil
        sentTo = nil
        channelTargetType = nil
        codeLength = 0
        requiredAttributes = []
        invalidAttributeNames = []
    }

    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario) {
        onCodeRequiredCalled = true
        codeRequiredState = state
        sentTo = state.sentTo
        channelTargetType = state.channel
        codeLength = state.codeLength
        self.scenario = scenario

        expectation.fulfill()
    }

    func onAttributesRequired(state: MSALNativeAuthAttributesRequiredState, scenario: MSALNativeAuthFlowScenario) {
        onAttributesRequiredCalled = true
        attributesRequiredState = state
        requiredAttributes = state.attributes
        self.scenario = scenario

        expectation.fulfill()
    }

    func onAttributesInvalid(state: MSALNativeAuthAttributesInvalidState, scenario: MSALNativeAuthFlowScenario) {
        onAttributesInvalidCalled = true
        attributesInvalidState = state
        invalidAttributeNames = state.attributeNames
        self.scenario = scenario

        expectation.fulfill()
    }

    func onSignInAfterSignUpRequired(
        state: MSALNativeAuthSignInAfterSignUpState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        onSignInAfterSignUpRequiredCalled = true
        signInAfterSignUpState = state
        self.scenario = scenario

        expectation.fulfill()
    }

    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        onFlowCompletedCalled = true
        self.result = result
        self.scenario = scenario

        expectation.fulfill()
    }

    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        onFlowErrorCalled = true
        self.error = error
        self.scenario = scenario

        expectation.fulfill()
    }
}
