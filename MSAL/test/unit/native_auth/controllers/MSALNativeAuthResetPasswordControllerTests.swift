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

final class MSALNativeAuthResetPasswordControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthResetPasswordController!
    private var contextMock: MSALNativeAuthRequestContext!
    private var requestProviderMock: MSALNativeAuthResetPasswordRequestProviderMock!
    private var validatorMock: MSALNativeAuthResetPasswordResponseValidatorMock!


    private var resetPasswordStartParams: MSALNativeAuthResetPasswordStartRequestProviderParameters {
        .init(
            username: "user@contoso.com",
            context: contextMock
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        contextMock = .init(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        requestProviderMock = .init()
        validatorMock = .init()

        sut = .init(config: MSALNativeAuthConfigStubs.configuration,
                    requestProvider: requestProviderMock,
                    responseValidator: validatorMock,
                    cacheAccessor: MSALNativeAuthCacheAccessorMock()
        )
    }

    // MARK: - ResetPasswordStart (/start request) tests

    func test_whenResetPasswordStart_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_returnsSuccess_it_callsChallenge() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.unexpectedError)
        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    func test_whenResetPasswordStartPassword_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.redirect)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.error(.unsupportedChallengeType))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .userDoesNotHavePassword)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInResetPasswordStart_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.unexpectedError)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    // MARK: - ResetPasswordStart (/challenge request) tests

    func test_whenResetPasswordStart_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_challenge_succeeds_it_callsDelegate() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.success("sentTo", "email", 4, "resetPasswordToken"))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordCodeSentCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "resetPasswordToken")
        XCTAssertEqual(delegate.displayName, "sentTo")
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: true)
    }

    func test_whenResetPasswordStart_challenge_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.redirect)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_challenge_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.error(.expiredToken))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.expiredToken)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInResetPasswordStart_challenge_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.unexpectedError)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordStartDelegateSpy(exp)

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    // MARK: - ResendCode tests

    func test_whenResetPasswordResendCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordResendCodeDelegateSpy(exp)

        await sut.resendCode(flowToken: "flowToken", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.success("sentTo", "email", 4, "flowToken response"))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordResendCodeDelegateSpy(exp)

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordResendCodeSentCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "flowToken response")
        XCTAssertEqual(delegate.displayName, "sentTo")
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: true)
    }

    func test_whenResetPasswordResendCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.error(.invalidRequest))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordResendCodeDelegateSpy(exp)

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.redirect)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordResendCodeDelegateSpy(exp)

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.unexpectedError)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordResendCodeDelegateSpy(exp)

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    // MARK: - SubmitCode tests

    func test_whenResetPasswordSubmitCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitCodeDelegateSpy(exp)

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeSentState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.success(passwordSubmitToken: ""))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitCodeDelegateSpy(exp)

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onPasswordRequiredCalled)
        XCTAssertNotNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.newCodeSentState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: true)
    }

    func test_whenResetPasswordSubmitCode_returns_invalidOOB_it_callsDelegateInvalidCode() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.invalidOOB(passwordResetToken: "flowToken"))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitCodeDelegateSpy(exp)

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertEqual(delegate.newCodeSentState?.flowToken, "flowToken")
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .invalidCode)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.error(.invalidRequest))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitCodeDelegateSpy(exp)

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeSentState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.unexpectedError)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitCodeDelegateSpy(exp)

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeSentState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    // MARK: - SubmitPassword tests

    func test_whenResetPasswordSubmitPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockSubmitRequestFunc(nil, throwError: true)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_succeeds_it_callsDelegate() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .succeeded))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordCompletedCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: true)
    }

    func test_whenResetPasswordSubmitPassword_returns_passwordError_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.passwordError(error: .passwordTooWeak, passwordSubmitToken: "flowToken"))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(delegate.newPasswordRequiredState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.passwordTooWeak)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitPassword_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.error(.invalidRequest))

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitPassword_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.unexpectedError)

        let exp = expectation(description: "ResetPasswordController expectation")
        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    // MARK: - Common Methods

    // TODO: Reuse function from Sign Up tests
    private func checkTelemetryEventResult(id: MSALNativeAuthTelemetryApiId, isSuccessful: Bool) {
        XCTAssertEqual(receivedEvents.count, 1)

        guard let telemetryEventDict = receivedEvents.first?.propertyMap else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(id.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event" )
        XCTAssertEqual(telemetryEventDict["correlation_id" ] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, isSuccessful ? "yes" : "no")
        XCTAssertEqual(telemetryEventDict["status"] as? String, isSuccessful ? "succeeded" : "failed")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
    }

    private func prepareResetPasswordStartDelegateSpy(_ expectation: XCTestExpectation? = nil) -> ResetPasswordStartDelegateSpy {
        let delegate = ResetPasswordStartDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onResetPasswordErrorCalled)
        XCTAssertFalse(delegate.onResetPasswordCodeSentCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareResetPasswordResendCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> ResetPasswordResendCodeDelegateSpy {
        let delegate = ResetPasswordResendCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertFalse(delegate.onResetPasswordResendCodeSentCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.displayName)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareResetPasswordSubmitCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> ResetPasswordVerifyCodeDelegateSpy {
        let delegate = ResetPasswordVerifyCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onPasswordRequiredCalled)
        XCTAssertFalse(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeSentState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareResetPasswordSubmitPasswordDelegateSpy(_ expectation: XCTestExpectation? = nil) -> ResetPasswordRequiredDelegateSpy {
        let delegate = ResetPasswordRequiredDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onResetPasswordCompletedCalled)
        XCTAssertFalse(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    //TODO: Reuse function from Sign Up tests
    private func prepareMockRequest() -> MSIDHttpRequest {
        let request = MSIDHttpRequest()
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        return request
    }

}
