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

final class MSALNativeAuthAuthMethodSelectionRequiredStateTests: XCTestCase {

    func test_state_exposesAuthMethods() {
        let methods = [
            MSALAuthMethod(
                id: "email-id",
                challengeType: "email",
                channelTargetType: MSALNativeAuthChannelType(value: "email"),
                loginHint: "u***@contoso.com"
            ),
            MSALAuthMethod(id: "sms-id", challengeType: "sms", channelTargetType: MSALNativeAuthChannelType(value: "sms"), loginHint: "+1********00")
        ]
        let state = makeState(methods: methods)

        XCTAssertEqual(state.authMethods.count, 2)
        XCTAssertEqual(state.authMethods[0].id, "email-id")
        XCTAssertEqual(state.authMethods[0].loginHint, "u***@contoso.com")
        XCTAssertEqual(state.authMethods[1].id, "sms-id")
        XCTAssertTrue(state.authMethods[1].channelTargetType.isSMSType)
        XCTAssertEqual(state.description, "authMethodSelectionRequired")
    }

    func test_selectAuthMethod_forwardsSelectionToController() async {
        let expectation = expectation(description: "delegate called")
        let controller = MSALNativeAuthFlowControllerMock()
        let method = MSALAuthMethod(
            id: "sms-id",
            challengeType: "sms",
            channelTargetType: MSALNativeAuthChannelType(value: "sms"),
            loginHint: "+1********00"
        )
        controller.selectAuthMethodResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: MSALNativeAuthFlowError(type: .generalError)),
            correlationId: UUID(),
            scenario: .passwordReset
        )
        let state = makeState(methods: [method], controller: controller)
        let delegate = FlowDelegateSpy(expectation: expectation)

        state.selectAuthMethod(method, verificationContact: "+1********00", delegate: delegate)

        await fulfillment(of: [expectation])
        XCTAssertTrue(controller.selectedAuthMethod === method)
        XCTAssertEqual(controller.selectedVerificationContact, "+1********00")
        XCTAssertTrue(controller.selectedAuthMethodState === state.internalState)
        XCTAssertEqual(delegate.errorScenario, .passwordReset)
    }

    private func makeState(
        methods: [MSALAuthMethod],
        controller: MSALNativeAuthFlowControllerMock = MSALNativeAuthFlowControllerMock()
    ) -> MSALNativeAuthAuthMethodSelectionRequiredState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: .passwordReset,
            correlationId: UUID(),
            continuationToken: "ct",
            links: [:]
        )
        let internalState = MSALNativeAuthFlowInternalState(continuation: continuation, controller: controller)
        return MSALNativeAuthAuthMethodSelectionRequiredState(internalState: internalState, authMethods: methods)
    }
}

private final class FlowDelegateSpy: NSObject, MSALNativeAuthFlowDelegate {

    private let expectation: XCTestExpectation
    private(set) var errorScenario: MSALNativeAuthFlowScenario?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
        super.init()
    }

    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        expectation.fulfill()
    }

    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        errorScenario = scenario
        expectation.fulfill()
    }
}
