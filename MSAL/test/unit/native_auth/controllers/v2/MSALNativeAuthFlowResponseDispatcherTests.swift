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
@_implementationOnly import MSAL_Unit_Test_Private

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class MSALNativeAuthFlowResponseDispatcherTests: XCTestCase {

    private let sut = MSALNativeAuthFlowResponseDispatcher()
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var accountResult: MSALNativeAuthUserAccountResult!

    override func setUpWithError() throws {
        try super.setUpWithError()

        cacheAccessorMock = .init(
            tokenCache: try XCTUnwrap(MSIDDefaultTokenCacheAccessor(dataSource: MSIDTestCacheDataSource(), otherCacheAccessors: [])),
            accountMetadataCache: try XCTUnwrap(MSIDAccountMetadataCacheAccessor(dataSource: MSIDTestCacheDataSource()))
        )
        accountResult = .init(
            account: MSALNativeAuthUserAccountResultStub.account,
            rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
            configuration: MSALNativeAuthConfigStubs.configuration,
            cacheAccessor: cacheAccessorMock
        )
    }

    // MARK: - completed

    func test_dispatch_completed_callsOnFlowCompletedAndTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .completed(accountResult),
            correlationId: UUID(),
            scenario: .signIn,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.completedScenario, .signIn)
        XCTAssertTrue(delegate.completedResult === accountResult)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
        XCTAssertFalse(cacheAccessorMock.clearCacheWasCalled)
        delegate.completedResult?.signOut()
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
    }

    // MARK: - error

    func test_dispatch_error_callsOnFlowErrorAndDoesNotFireTelemetry() async {
        let delegate = BaseDelegateSpy()
        var telemetryFired = false
        let error = MSALNativeAuthFlowError(type: .invalidCode)
        let response = MSALNativeAuthFlowControllerResponse(
            .error(error: error),
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
            .browserRequired,
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

    func test_existingAccountStates_deliverDedicatedCallbacksOnMainThread() async {
        let internalState = makeInternalState()
        let codeState = MSALNativeAuthExistingAccountCodeRequiredState(
            internalState: internalState, sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"), codeLength: 6
        )
        let passwordState = MSALNativeAuthExistingAccountPasswordRequiredState(internalState: internalState)
        let delegate = ExistingAccountDelegateSpy()
        for state: MSALNativeAuthState in [codeState, passwordState] {
            var telemetryResult: Result<Void, MSALNativeAuthError>?
            await sut.dispatch(MSALNativeAuthFlowControllerResponse(
                .actionRequired(state: state), correlationId: internalState.continuation.correlationId,
                telemetryUpdate: { telemetryResult = $0 }
            ), delegate: delegate)
            XCTAssertEqual(delegate.scenario, .signIn)
            XCTAssertTrue(delegate.calledOnMainThread)
            XCTAssertNil(delegate.error)
            assertTelemetrySuccess(telemetryResult)
        }
        XCTAssertTrue(delegate.existingCodeState === codeState)
        XCTAssertTrue(delegate.existingPasswordState === passwordState)
        XCTAssertEqual(delegate.callbackCount, 2)
        XCTAssertEqual(delegate.ordinaryCallbackCount, 0)
    }

    func test_existingAccountStates_requireDedicatedDelegates() async {
        let codeState = MSALNativeAuthExistingAccountCodeRequiredState(
            internalState: makeInternalState(), sentTo: "***",
            channel: MSALNativeAuthChannelType(value: "email"), codeLength: 6
        )
        let passwordState = MSALNativeAuthExistingAccountPasswordRequiredState(internalState: makeInternalState())
        await assertNotImplemented(
            for: codeState, expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthExistingAccountCodeRequiredDelegate"
        )
        await assertNotImplemented(
            for: passwordState, expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthExistingAccountPasswordRequiredDelegate"
        )
        let ordinaryDelegate = OrdinaryCredentialsDelegateSpy()
        for state: MSALNativeAuthState in [codeState, passwordState] {
            await sut.dispatch(
                MSALNativeAuthFlowControllerResponse(.actionRequired(state: state), correlationId: UUID()),
                delegate: ordinaryDelegate
            )
            XCTAssertTrue(ordinaryDelegate.error?.isNotImplemented == true)
            XCTAssertEqual(ordinaryDelegate.errorScenario, .signIn)
        }
        XCTAssertEqual(ordinaryDelegate.ordinaryCallbackCount, 0)
    }

    @MainActor
    func test_existingAccountStates_forwardSubmissionToSharedSignInOperations() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(controller: controller)
        let codeState = MSALNativeAuthExistingAccountCodeRequiredState(
            internalState: internalState, sentTo: "***",
            channel: MSALNativeAuthChannelType(value: "email"), codeLength: 6
        )
        let passwordState = MSALNativeAuthExistingAccountPasswordRequiredState(internalState: internalState)
        let error = MSALNativeAuthFlowError(type: .invalidCode)
        controller.submitCodeResponse = MSALNativeAuthFlowControllerResponse(
            .error(error: error), correlationId: UUID(), scenario: .signIn
        )
        controller.submitPasswordResponse = MSALNativeAuthFlowControllerResponse(
            .completed(accountResult), correlationId: UUID(), scenario: .signIn
        )
        let delegate = ExistingAccountDelegateSpy()
        let codeCallback = expectation(description: "Code submission")
        delegate.callbackExpectation = codeCallback
        codeState.submitCode("123456", delegate: delegate)
        await fulfillment(of: [codeCallback], timeout: 5)
        XCTAssertEqual(controller.submittedCode, "123456")
        XCTAssertTrue(controller.submittedCodeState === internalState)
        XCTAssertTrue(delegate.error === error)
        XCTAssertEqual(delegate.errorScenario, .signIn)

        let passwordCallback = expectation(description: "Password submission")
        delegate.callbackExpectation = passwordCallback
        passwordState.submitPassword("current-password", delegate: delegate)
        await fulfillment(of: [passwordCallback], timeout: 5)
        XCTAssertEqual(controller.submittedPassword, "current-password")
        XCTAssertTrue(controller.submittedPasswordState === internalState)
        XCTAssertTrue(delegate.completedResult === accountResult)
        XCTAssertEqual(delegate.completedScenario, .signIn)

    }

    @MainActor
    func test_existingAccountCode_resendWrapsFreshStateAndSupportsRepeatedResends() async throws {
        let controller = MSALNativeAuthFlowControllerMock()
        var state = MSALNativeAuthExistingAccountCodeRequiredState(
            internalState: makeInternalState(controller: controller), sentTo: "***",
            channel: MSALNativeAuthChannelType(value: "email"), codeLength: 6
        )
        let delegate = ExistingAccountDelegateSpy()
        var telemetryCount = 0
        for length in [7, 8] {
            let freshInternalState = makeInternalState(controller: controller)
            let freshState = MSALNativeAuthCodeRequiredState(
                internalState: freshInternalState, sentTo: "f***@contoso.com",
                channel: MSALNativeAuthChannelType(value: "email"), codeLength: length
            )
            let telemetryCallback = expectation(description: "Resend telemetry")
            controller.resendCodeResponse = MSALNativeAuthFlowControllerResponse(
                .actionRequired(state: freshState), correlationId: UUID(), scenario: .signIn,
                telemetryUpdate: { result in
                    self.assertTelemetrySuccess(result)
                    telemetryCount += 1
                    telemetryCallback.fulfill()
                }
            )
            let callback = expectation(description: "Existing-account code resent")
            delegate.callbackExpectation = callback
            state.resendCode(delegate: delegate)
            await fulfillment(of: [callback, telemetryCallback], timeout: 5)

            XCTAssertTrue(controller.resendCodeState === state.internalState)
            let next = try XCTUnwrap(delegate.existingCodeState)
            XCTAssertTrue(next.internalState === freshInternalState)
            XCTAssertEqual(next.sentTo, freshState.sentTo)
            XCTAssertTrue(next.channel === freshState.channel)
            XCTAssertEqual(next.codeLength, length)
            XCTAssertEqual(delegate.scenario, .signIn)
            XCTAssertEqual(delegate.ordinaryCallbackCount, 0)
            state = next
        }
        XCTAssertEqual(telemetryCount, 2)
    }

    @MainActor
    func test_existingAccountCode_resendPreservesCorrelationWhenDelegateIsMissing() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(controller: controller)
        let state = MSALNativeAuthExistingAccountCodeRequiredState(
            internalState: internalState, sentTo: "***",
            channel: MSALNativeAuthChannelType(value: "email"), codeLength: 6
        )
        let correlationId = UUID()
        let freshState = MSALNativeAuthCodeRequiredState(
            internalState: makeInternalState(controller: controller), sentTo: "***",
            channel: MSALNativeAuthChannelType(value: "email"), codeLength: 8
        )
        controller.resendCodeResponse = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: freshState), correlationId: correlationId
        )
        let delegate = BaseDelegateSpy()
        let callback = expectation(description: "Missing existing-account delegate")
        delegate.callbackExpectation = callback
        state.resendCode(delegate: delegate)
        await fulfillment(of: [callback], timeout: 5)
        XCTAssertTrue(delegate.error?.isNotImplemented == true)
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
        XCTAssertEqual(delegate.errorScenario, .signIn)
    }

    @MainActor
    func test_existingAccountCode_resendPassesThroughErrorsBrowserAndEnrollment() async {
        let controller = MSALNativeAuthFlowControllerMock()
        let state = MSALNativeAuthExistingAccountCodeRequiredState(
            internalState: makeInternalState(controller: controller), sentTo: "***",
            channel: MSALNativeAuthChannelType(value: "email"), codeLength: 6
        )
        let registration = MSALNativeAuthStrongAuthRegistrationRequiredState(
            internalState: makeInternalState(), authMethods: []
        )
        let error = MSALNativeAuthFlowError(type: .generalError)
        let correlationId = UUID()
        var telemetryCount = 0
        for result: MSALNativeAuthFlowResult in [
            .error(error: error), .browserRequired, .actionRequired(state: registration)
        ] {
            controller.resendCodeResponse = MSALNativeAuthFlowControllerResponse(
                result, correlationId: correlationId, scenario: .signIn,
                telemetryUpdate: { _ in telemetryCount += 1 }
            )
            let delegate = StrongAuthDelegateSpy()
            let callback = expectation(description: "Resend non-code result")
            delegate.callbackExpectation = callback
            state.resendCode(delegate: delegate)
            await fulfillment(of: [callback], timeout: 5)
            switch result {
            case .error:
                XCTAssertTrue(delegate.error === error)
                XCTAssertEqual(delegate.errorScenario, .signIn)
            case .browserRequired:
                XCTAssertTrue(delegate.error?.isBrowserRequired == true)
                XCTAssertEqual(delegate.error?.correlationId, correlationId)
                XCTAssertEqual(delegate.errorScenario, .signIn)
            default:
                XCTAssertTrue(delegate.registrationState === registration)
                XCTAssertEqual(delegate.strongAuthScenario, .signIn)
            }
        }
        XCTAssertEqual(telemetryCount, 2)
    }

    func test_dispatch_registrationRequired_deliversTypedCallbackOnMainThread() async {
        let delegate = StrongAuthDelegateSpy()
        let state = MSALNativeAuthStrongAuthRegistrationRequiredState(
            internalState: makeInternalState(), authMethods: []
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state), correlationId: UUID(),
            telemetryUpdate: { telemetryResult = $0 }
        )
        await sut.dispatch(response, delegate: delegate)
        XCTAssertTrue(delegate.registrationState === state)
        XCTAssertEqual(delegate.strongAuthScenario, .signIn)
        XCTAssertTrue(delegate.calledOnMainThread)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    func test_dispatch_activationRequired_deliversTypedCallbackOnMainThread() async {
        let delegate = StrongAuthDelegateSpy()
        let state = MSALNativeAuthStrongAuthVerificationRequiredState(
            internalState: makeInternalState(),
            sentTo: "+1******0100",
            channel: MSALNativeAuthChannelType(value: "sms"),
            codeLength: 6
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state), correlationId: UUID(),
            telemetryUpdate: { telemetryResult = $0 }
        )
        await sut.dispatch(response, delegate: delegate)
        XCTAssertTrue(delegate.activationState === state)
        XCTAssertEqual(delegate.strongAuthScenario, .signIn)
        XCTAssertTrue(delegate.calledOnMainThread)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    func test_dispatch_registrationRequired_missingDelegate_reportsNotImplemented() async {
        await assertNotImplemented(
            for: MSALNativeAuthStrongAuthRegistrationRequiredState(internalState: makeInternalState(), authMethods: []),
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthStrongAuthRegistrationRequiredDelegate"
        )
    }

    func test_dispatch_activationRequired_missingDelegate_reportsNotImplemented() async {
        await assertNotImplemented(
            for: MSALNativeAuthStrongAuthVerificationRequiredState(
                internalState: makeInternalState(),
                sentTo: "+1******0100",
                channel: MSALNativeAuthChannelType(value: "sms"),
                codeLength: 6
            ),
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthStrongAuthVerificationRequiredDelegate"
        )
    }

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

    func test_dispatch_authMethodSelectionRequired_conformingDelegate_callsTypedCallbackAndTelemetry() async {
        let delegate = AuthMethodSelectionRequiredDelegateSpy()
        let internalState = makeInternalState(scenario: .passwordReset)
        let state = MSALNativeAuthAuthMethodSelectionRequiredState(
            internalState: internalState,
            authMethods: [
                MSALAuthMethod(
                    id: "sms-id",
                    challengeType: "sms",
                    channelTargetType: MSALNativeAuthChannelType(value: "sms"),
                    loginHint: "+1********00"
                )
            ]
        )
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.authMethodSelectionRequiredState === state)
        XCTAssertEqual(delegate.authMethodSelectionRequiredScenario, .passwordReset)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    func test_dispatch_signInAfterResetPassword_callsTypedCallbackAndTelemetry() async {
        let delegate = V2SignInAfterResetPasswordDelegateSpy()
        let internalState = makeInternalState(scenario: .passwordReset)
        let state = MSALNativeAuthSignInAfterResetPasswordState(internalState: internalState)
        var telemetryResult: Result<Void, MSALNativeAuthError>?
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { telemetryResult = $0 }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertTrue(delegate.signInAfterResetPasswordState === state)
        XCTAssertEqual(delegate.signInAfterResetPasswordScenario, .passwordReset)
        XCTAssertNil(delegate.error)
        assertTelemetrySuccess(telemetryResult)
    }

    // MARK: - actionRequired: delegate does not conform (notImplemented surfaces the delegate name)

    func test_dispatch_codeRequired_nonConformingDelegate_callsNotImplementedWithDelegateNameAndSkipsTelemetry() async {
        let state = MSALNativeAuthCodeRequiredState(
            internalState: makeInternalState(scenario: .signIn),
            sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthCodeRequiredDelegate"
        )
    }

    func test_dispatch_passwordRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthPasswordRequiredState(internalState: makeInternalState(scenario: .signIn))
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthPasswordRequiredDelegate"
        )
    }

    func test_dispatch_mfaRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthAuthMethodSelectionRequiredState(internalState: makeInternalState(scenario: .signIn), authMethods: [])
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthAuthMethodSelectionRequiredDelegate"
        )
    }

    func test_dispatch_mfaVerificationRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthMFAVerificationRequiredState(
            internalState: makeInternalState(scenario: .signIn),
            sentTo: "u***@contoso.com",
            channel: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        await assertNotImplemented(
            for: state,
            expectedScenario: .signIn,
            expectedDelegateName: "MSALNativeAuthMFAVerificationRequiredDelegate"
        )
    }

    func test_dispatch_authMethodSelectionRequired_nonConformingDelegate_callsNotImplementedWithScenarioAndCorrelation() async {
        let correlationId = UUID()
        let state = MSALNativeAuthAuthMethodSelectionRequiredState(
            internalState: makeInternalState(scenario: .signIn),
            authMethods: []
        )
        let delegate = BaseDelegateSpy()
        var telemetryFired = false
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: correlationId,
            scenario: .unknown,
            telemetryUpdate: { _ in telemetryFired = true }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.errorScenario, .signIn)
        XCTAssertTrue(delegate.error?.isNotImplemented ?? false)
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "MSALNativeAuthAuthMethodSelectionRequiredDelegate")
        )
        XCTAssertFalse(telemetryFired)
    }

    func test_dispatch_newPasswordRequired_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthNewPasswordRequiredState(internalState: makeInternalState(scenario: .passwordReset))
        await assertNotImplemented(
            for: state,
            expectedScenario: .passwordReset,
            expectedDelegateName: "MSALNativeAuthNewPasswordRequiredDelegate"
        )
    }

    func test_dispatch_signInAfterResetPassword_nonConformingDelegate_callsNotImplementedWithDelegateName() async {
        let state = MSALNativeAuthSignInAfterResetPasswordState(internalState: makeInternalState(scenario: .passwordReset))
        await assertNotImplemented(
            for: state,
            expectedScenario: .passwordReset,
            expectedDelegateName: "MSALNativeAuthSignInAfterResetPasswordRequiredDelegate"
        )
    }

    @MainActor
    func test_signInAfterSignUpState_parameterlessSignIn_dispatchesCompletionAndErrors() async {
        await assertParameterlessSignIn(scenario: .signUp)
        await assertParameterlessSignIn(scenario: .signUp, error: MSALNativeAuthFlowError(type: .generalError))
    }

    @MainActor
    func test_signInAfterResetPasswordState_parameterlessSignIn_dispatchesCompletionAndErrors() async {
        await assertParameterlessSignIn(scenario: .passwordReset)
        await assertParameterlessSignIn(scenario: .passwordReset, error: MSALNativeAuthFlowError(type: .generalError))
    }

    // MARK: - Helpers

    @MainActor
    private func assertParameterlessSignIn(
        scenario: MSALNativeAuthFlowScenario,
        error: MSALNativeAuthFlowError? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let controller = MSALNativeAuthFlowControllerMock()
        let internalState = makeInternalState(scenario: scenario, controller: controller)
        let response = MSALNativeAuthFlowControllerResponse(
            error.map { .error(error: $0) } ?? .completed(accountResult),
            correlationId: internalState.continuation.correlationId,
            scenario: scenario
        )
        controller.signInAfterSignUpResponse = response
        controller.signInAfterResetPasswordResponse = response
        let delegate = BaseDelegateSpy()
        let callback = expectation(description: "Parameterless sign-in callback")
        delegate.callbackExpectation = callback

        if scenario == .signUp {
            let state = MSALNativeAuthSignInAfterSignUpState(internalState: internalState)
            XCTAssertFalse(state.responds(to: NSSelectorFromString("signInWithParameters:delegate:")), file: file, line: line)
            XCTAssertTrue(state.responds(to: #selector(MSALNativeAuthSignInAfterSignUpState.signIn(delegate:))), file: file, line: line)
            state.signIn(delegate: delegate)
        } else {
            let state = MSALNativeAuthSignInAfterResetPasswordState(internalState: internalState)
            XCTAssertFalse(state.responds(to: NSSelectorFromString("signInWithParameters:delegate:")), file: file, line: line)
            XCTAssertTrue(state.responds(to: #selector(MSALNativeAuthSignInAfterResetPasswordState.signIn(delegate:))), file: file, line: line)
            state.signIn(delegate: delegate)
        }

        await fulfillment(of: [callback], timeout: 5)

        if scenario == .signUp {
            XCTAssertTrue(controller.signInAfterSignUpState === internalState, file: file, line: line)
            XCTAssertNil(controller.signInAfterResetPasswordState, file: file, line: line)
        } else {
            XCTAssertTrue(controller.signInAfterResetPasswordState === internalState, file: file, line: line)
            XCTAssertNil(controller.signInAfterSignUpState, file: file, line: line)
        }
        if let error = error {
            XCTAssertTrue(delegate.error === error, file: file, line: line)
            XCTAssertEqual(delegate.errorScenario, scenario, file: file, line: line)
            XCTAssertNil(delegate.completedScenario, file: file, line: line)
            XCTAssertNil(delegate.completedResult, file: file, line: line)
        } else {
            XCTAssertEqual(delegate.completedScenario, scenario, file: file, line: line)
            XCTAssertTrue(delegate.completedResult === accountResult, file: file, line: line)
            XCTAssertNil(delegate.error, file: file, line: line)
            XCTAssertFalse(cacheAccessorMock.clearCacheWasCalled, file: file, line: line)
            delegate.completedResult?.signOut()
            XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled, file: file, line: line)
        }
    }

    private func makeInternalState(
        scenario: MSALNativeAuthFlowScenario = .signIn,
        controller: MSALNativeAuthFlowControlling = MSALNativeAuthFlowControllerMock()
    ) -> MSALNativeAuthFlowInternalState {
        let continuation = MSALNativeAuthFlowContinuationState(
            flowScenario: scenario,
            correlationId: UUID(),
            continuationToken: "ct",
            links: [:]
        )
        return MSALNativeAuthFlowInternalState(continuation: continuation, controller: controller)
    }

    private func assertNotImplemented(
        for state: MSALNativeAuthState,
        expectedScenario: MSALNativeAuthFlowScenario,
        expectedDelegateName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let delegate = BaseDelegateSpy()
        var telemetryFired = false
        let response = MSALNativeAuthFlowControllerResponse(
            .actionRequired(state: state),
            correlationId: UUID(),
            scenario: .unknown,
            telemetryUpdate: { _ in telemetryFired = true }
        )

        await sut.dispatch(response, delegate: delegate)

        XCTAssertEqual(delegate.errorScenario, expectedScenario, file: file, line: line)
        XCTAssertTrue(delegate.error?.isNotImplemented ?? false, file: file, line: line)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, expectedDelegateName),
            file: file,
            line: line
        )
        XCTAssertFalse(telemetryFired, file: file, line: line)
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

    var callbackExpectation: XCTestExpectation?
    var completedScenario: MSALNativeAuthFlowScenario?
    var completedResult: MSALNativeAuthUserAccountResult?
    var error: MSALNativeAuthFlowError?
    var errorScenario: MSALNativeAuthFlowScenario?

    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        completedScenario = scenario
        completedResult = result
        callbackExpectation?.fulfill()
    }

    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        self.error = error
        errorScenario = scenario
        callbackExpectation?.fulfill()
    }
}

private final class StrongAuthDelegateSpy: BaseDelegateSpy,
    MSALNativeAuthStrongAuthRegistrationRequiredDelegate,
    MSALNativeAuthStrongAuthVerificationRequiredDelegate {

    var registrationState: MSALNativeAuthStrongAuthRegistrationRequiredState?
    var activationState: MSALNativeAuthStrongAuthVerificationRequiredState?
    var strongAuthScenario: MSALNativeAuthFlowScenario?
    var calledOnMainThread = false

    func onStrongAuthRegistrationRequired(
        state: MSALNativeAuthStrongAuthRegistrationRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        registrationState = state
        strongAuthScenario = scenario
        calledOnMainThread = Thread.isMainThread
        callbackExpectation?.fulfill()
    }

    func onStrongAuthVerificationRequired(
        state: MSALNativeAuthStrongAuthVerificationRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        activationState = state
        strongAuthScenario = scenario
        calledOnMainThread = Thread.isMainThread
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

private class OrdinaryCredentialsDelegateSpy: BaseDelegateSpy,
    MSALNativeAuthCodeRequiredDelegate,
    MSALNativeAuthPasswordRequiredDelegate {

    var ordinaryCallbackCount = 0

    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario) {
        ordinaryCallbackCount += 1
    }

    func onPasswordRequired(state: MSALNativeAuthPasswordRequiredState, scenario: MSALNativeAuthFlowScenario) {
        ordinaryCallbackCount += 1
    }
}

private final class ExistingAccountDelegateSpy: OrdinaryCredentialsDelegateSpy,
    MSALNativeAuthExistingAccountCodeRequiredDelegate,
    MSALNativeAuthExistingAccountPasswordRequiredDelegate {

    var existingCodeState: MSALNativeAuthExistingAccountCodeRequiredState?
    var existingPasswordState: MSALNativeAuthExistingAccountPasswordRequiredState?
    var scenario: MSALNativeAuthFlowScenario?
    var calledOnMainThread = false
    var callbackCount = 0

    func onExistingAccountCodeRequired(
        state: MSALNativeAuthExistingAccountCodeRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        existingCodeState = state
        self.scenario = scenario
        calledOnMainThread = Thread.isMainThread
        callbackCount += 1
        callbackExpectation?.fulfill()
    }

    func onExistingAccountPasswordRequired(
        state: MSALNativeAuthExistingAccountPasswordRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        existingPasswordState = state
        self.scenario = scenario
        calledOnMainThread = Thread.isMainThread
        callbackCount += 1
        callbackExpectation?.fulfill()
    }
}

private final class AuthMethodSelectionRequiredDelegateSpy: BaseDelegateSpy, MSALNativeAuthAuthMethodSelectionRequiredDelegate {

    var authMethodSelectionRequiredState: MSALNativeAuthAuthMethodSelectionRequiredState?
    var authMethodSelectionRequiredScenario: MSALNativeAuthFlowScenario?

    func onAuthMethodSelectionRequired(
        state: MSALNativeAuthAuthMethodSelectionRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        authMethodSelectionRequiredState = state
        authMethodSelectionRequiredScenario = scenario
    }
}

private final class V2SignInAfterResetPasswordDelegateSpy: BaseDelegateSpy, MSALNativeAuthSignInAfterResetPasswordRequiredDelegate {

    var signInAfterResetPasswordState: MSALNativeAuthSignInAfterResetPasswordState?
    var signInAfterResetPasswordScenario: MSALNativeAuthFlowScenario?

    func onSignInAfterResetPasswordRequired(
        state: MSALNativeAuthSignInAfterResetPasswordState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        signInAfterResetPasswordState = state
        signInAfterResetPasswordScenario = scenario
    }
}
