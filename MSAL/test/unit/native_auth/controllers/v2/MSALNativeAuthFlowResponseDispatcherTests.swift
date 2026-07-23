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
@_implementationOnly import MSAL_Private

final class MSALNativeAuthFlowResponseDispatcherTests: XCTestCase {

    private let sut = MSALNativeAuthFlowResponseDispatcher()

    // MARK: - completed

    func test_dispatch_completed_callsOnFlowCompletedAndTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .completed(MSALNativeAuthUserAccountResultStub.result),
            correlationId: UUID(),
            scenario: .signIn,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.completedScenario, .signIn)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    // MARK: - error

    func test_dispatch_error_callsOnFlowErrorAndDoesNotFireTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryFired = false
        let error = MSALNativeAuthFlowError(type: .invalidCode)
        let response = MSALNativeAuthFlowControllerResponse(
            .error(error: error, newState: nil),
            correlationId: UUID(),
            scenario: .passwordReset,
            telemetryUpdate: { _ in telemetryFired = true }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.error === error)
        XCTAssertEqual(delegate.errorScenario, .passwordReset)
        XCTAssertFalse(telemetryFired)
    }

    // MARK: - browserRequired

    func test_dispatch_browserRequired_callsOnFlowErrorWithBrowserRequiredAndTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .browserRequired(url: URL(string: "https://contoso.com/fallback")!, newState: makeInternalState()),
            correlationId: UUID(),
            scenario: .signUp,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.errorScenario, .signUp)
        XCTAssertTrue(delegate.error?.isBrowserRequired ?? false)
        assertTelemetrySuccess(telemetryResult)
    }

    // MARK: - actionRequired: delegate conforms

    func test_dispatch_actionRequired_conformingDelegate_callsTypedCallbackAndTelemetry() async {
        let delegate = CodeRequiredDelegateSpy()
        let internalState = makeInternalState(scenario: .signUp)
        let state = MSALNativeAuthCodeRequiredState(
            internalState: internalState,
            sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.codeRequiredState === state)
        // The scenario is taken from the state's continuation, not from response.scenario.
        XCTAssertEqual(delegate.codeRequiredScenario, .signUp)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    // MARK: - actionRequired: delegate does not conform

    func test_dispatch_actionRequired_nonConformingDelegate_callsNotImplementedAndSkipsTelemetry() async {
        let delegate = BaseDelegateSpy()
        let internalState = makeInternalState(scenario: .signIn)
        let state = MSALNativeAuthCodeRequiredState(
            internalState: internalState,
            sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        var telemetryFired = false
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { _ in telemetryFired = true }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.errorScenario, .signIn)
        XCTAssertTrue(delegate.error?.isNotImplemented ?? false)
        XCTAssertFalse(telemetryFired)
    }

    // MARK: - Helpers

    private func makeInternalState(scenario: MSALNativeAuthFlowScenario = .signIn) -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: scenario,
            continuationToken: "ct",
            links: [:],
            username: nil
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: MSALNativeAuthFlowControllerMock())
    }

    private func assertTelemetrySuccess(
        _ result: Result<Void, MSALNativeAuthError>?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .success = result else {
            return XCTFail("Expected telemetry success", file: file, line: line)
        }
    }
}

// MARK: - Delegate spies

private class BaseDelegateSpy: NSObject, MSALNativeAuthFlowDelegate {

    var completedScenario: MSALNativeAuthFlowScenario?
    var error: MSALNativeAuthFlowError?
    var errorScenario: MSALNativeAuthFlowScenario?

    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        completedScenario = scenario
    }

    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        self.error = error
        errorScenario = scenario
    }
}

private final class CodeRequiredDelegateSpy: BaseDelegateSpy, MSALNativeAuthCodeRequiredDelegate {

    var codeRequiredState: MSALNativeAuthCodeRequiredState?
    var codeRequiredScenario: MSALNativeAuthFlowScenario?

    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario) {
        codeRequiredState = state
        codeRequiredScenario = scenario
    }
}
