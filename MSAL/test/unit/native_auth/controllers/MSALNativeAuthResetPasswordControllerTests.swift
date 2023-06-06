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

    func test_whenResetPasswordStart_correctParamsArePassedToRequestProvider() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordStartDelegateSpy()

        let params = MSALNativeAuthResetPasswordStartRequestProviderParameters(
            username: "user@contoso.com",
            context: contextMock
        )

        await sut.resetPassword(parameters: params, delegate: delegate)


        XCTAssertEqual(requestProviderMock.startParameters?.username, params.username)
        XCTAssertEqual(requestProviderMock.startParameters?.context.correlationId(), params.context.correlationId())
        XCTAssertEqual(requestProviderMock.startParameters?.context.telemetryRequestId(), params.context.telemetryRequestId())
    }

    func test_whenResetPasswordStart_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
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

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.error(.unsupportedChallengeType))

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .userDoesNotHavePassword)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInResetPasswordStart_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.unexpectedError)

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    // MARK: - ResetPasswordStart (/challenge request) tests

    func test_whenResetPasswordStart_challenge_correctParamsArePassedToRequestProvider() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: "passwordResetToken"))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertEqual(requestProviderMock.challengeTokenParam, "passwordResetToken")
        XCTAssertEqual(requestProviderMock.challengeContextParam?.correlationId(), resetPasswordStartParams.context.correlationId())
        XCTAssertEqual(requestProviderMock.challengeContextParam?.telemetryRequestId(), resetPasswordStartParams.context.telemetryRequestId())
    }

    func test_whenResetPasswordStart_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_challenge_succeeds_it_callsDelegate() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.success("sentTo", .email, 4, "resetPasswordToken"))

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "resetPasswordToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: true)
    }

    func test_whenResetPasswordStart_challenge_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.redirect)

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_challenge_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordStartFunc(.success(passwordResetToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.error(.expiredToken))

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
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

        let delegate = prepareResetPasswordStartDelegateSpy()

        await sut.resetPassword(parameters: resetPasswordStartParams, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    // MARK: - ResendCode tests

    func test_whenResetPasswordResendCode_correctParamsArePassedToRequestProvider() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordResendCodeDelegateSpy()

        await sut.resendCode(flowToken: "flowToken", context: contextMock, delegate: delegate)

        XCTAssertEqual(requestProviderMock.challengeTokenParam, "flowToken")
        XCTAssertEqual(requestProviderMock.challengeContextParam?.correlationId(), resetPasswordStartParams.context.correlationId())
        XCTAssertEqual(requestProviderMock.challengeContextParam?.telemetryRequestId(), resetPasswordStartParams.context.telemetryRequestId())
    }

    func test_whenResetPasswordResendCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordResendCodeDelegateSpy()

        await sut.resendCode(flowToken: "flowToken", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.success("sentTo", .email, 4, "flowToken response"))

        let delegate = prepareResetPasswordResendCodeDelegateSpy()

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordResendCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "flowToken response")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: true)
    }

    func test_whenResetPasswordResendCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.error(.invalidRequest))

        let delegate = prepareResetPasswordResendCodeDelegateSpy()

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.redirect)

        let delegate = prepareResetPasswordResendCodeDelegateSpy()

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordChallengeFunc(.unexpectedError)

        let delegate = prepareResetPasswordResendCodeDelegateSpy()

        await sut.resendCode(flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    // MARK: - SubmitCode tests

    func test_whenResetPasswordSubmitCode_correctParamsArePassedToRequestProvider() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordSubmitCodeDelegateSpy()
        let oobCode = "oobCode"
        let flowToken = "flowToken"

        await sut.submitCode(code: oobCode, flowToken: flowToken, context: contextMock, delegate: delegate)

        XCTAssertEqual(requestProviderMock.continueParameters?.oobCode, oobCode)
        XCTAssertEqual(requestProviderMock.continueParameters?.passwordResetToken, flowToken)
        XCTAssertEqual(requestProviderMock.continueParameters?.grantType, MSALNativeAuthGrantType.oobCode)
        XCTAssertEqual(requestProviderMock.continueParameters?.context.correlationId(), contextMock.correlationId())
        XCTAssertEqual(requestProviderMock.continueParameters?.context.telemetryRequestId(), contextMock.telemetryRequestId())
    }

    func test_whenResetPasswordSubmitCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordSubmitCodeDelegateSpy()

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.success(passwordSubmitToken: ""))

        let delegate = prepareResetPasswordSubmitCodeDelegateSpy()

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onPasswordRequiredCalled)
        XCTAssertNotNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: true)
    }

    func test_whenResetPasswordSubmitCode_returns_invalidOOB_it_callsDelegateInvalidCode() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.invalidOOB(passwordResetToken: "flowToken"))

        let delegate = prepareResetPasswordSubmitCodeDelegateSpy()

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertEqual(delegate.newCodeRequiredState?.flowToken, "flowToken")
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .invalidCode)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.error(.invalidRequest))

        let delegate = prepareResetPasswordSubmitCodeDelegateSpy()

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeRequiredState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordContinueFunc(.unexpectedError)

        let delegate = prepareResetPasswordSubmitCodeDelegateSpy()

        await sut.submitCode(code: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeRequiredState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordVerifyCode, isSuccessful: false)
    }

    // MARK: - SubmitPassword tests

    func test_whenResetPasswordSubmitPassword_correctParamsArePassedToRequestProvider() async {
        requestProviderMock.mockSubmitRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        let password = "password"
        let flowToken = "flowToken"

        await sut.submitPassword(password: password, flowToken: flowToken, context: contextMock, delegate: delegate)

        XCTAssertEqual(requestProviderMock.submitParameters?.newPassword, password)
        XCTAssertEqual(requestProviderMock.submitParameters?.passwordSubmitToken, flowToken)
        XCTAssertEqual(requestProviderMock.submitParameters?.context.correlationId(), contextMock.correlationId())
        XCTAssertEqual(requestProviderMock.submitParameters?.context.telemetryRequestId(), contextMock.telemetryRequestId())
    }

    func test_whenResetPasswordSubmitPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockSubmitRequestFunc(nil, throwError: true)

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

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

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordCompletedCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: true)
    }

    func test_whenResetPasswordSubmitPassword_returns_passwordError_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.passwordError(error: .passwordTooWeak, passwordSubmitToken: "flowToken"))

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(delegate.newPasswordRequiredState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.passwordTooWeak)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitPassword_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.error(.invalidRequest))

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitPassword_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.unexpectedError)

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    // MARK: - SubmitPassword - poll completion tests

    func test_whenSubmitPassword_pollCompletion_correctParamsArePassedToRequestProvider() async {
        let passwordResetToken = "passwordResetToken"

        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: passwordResetToken, pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.unexpectedError)

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertEqual(requestProviderMock.pollCompletionParameters?.passwordResetToken, passwordResetToken)
        XCTAssertEqual(requestProviderMock.pollCompletionParameters?.context.correlationId(), contextMock.correlationId())
        XCTAssertEqual(requestProviderMock.pollCompletionParameters?.context.telemetryRequestId(), contextMock.telemetryRequestId())
    }

    func test_whenSubmitPassword_pollCompletion_returns_failed_it_callsDelegate() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.unexpectedError)

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertNotNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.unexpectedError)

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_passwordError_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.passwordError(error: .passwordBanned, passwordSubmitToken: "flowToken"))

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(delegate.newPasswordRequiredState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.passwordBanned)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.error(.expiredToken))

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.expiredToken)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }


    func test_whenSubmitPassword_pollCompletion_returns_notStarted_it_callsDelegateErrorAfterRetries() async throws {
        throw XCTSkip("This test needs more work to allow it to properly work with mocked MSIDHTTPRequests")

        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 1))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .notStarted))

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_failed_it_callsDelegateError() async throws {
        throw XCTSkip("This test needs more work to allow it to properly work with mocked MSIDHTTPRequests")

        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .failed))

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_inProgress_it_callsDelegateErrorAfterRetries() async throws {
        throw XCTSkip("This test needs more work to allow it to properly work with mocked MSIDHTTPRequests")

        requestProviderMock.mockSubmitRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "", pollInterval: 5))
        requestProviderMock.mockPollCompletionRequestFunc(prepareMockRequest())
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .inProgress))

        let delegate = prepareResetPasswordSubmitPasswordDelegateSpy()

        await sut.submitPassword(password: "", flowToken: "", context: contextMock, delegate: delegate)

        XCTAssertTrue(delegate.onResetPasswordRequiredErrorCalled)
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
        XCTAssertFalse(delegate.onResetPasswordCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareResetPasswordResendCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> ResetPasswordResendCodeDelegateSpy {
        let delegate = ResetPasswordResendCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onResetPasswordResendCodeErrorCalled)
        XCTAssertFalse(delegate.onResetPasswordResendCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareResetPasswordSubmitCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> ResetPasswordVerifyCodeDelegateSpy {
        let delegate = ResetPasswordVerifyCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onPasswordRequiredCalled)
        XCTAssertFalse(delegate.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newCodeRequiredState)
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

    private func prepareMockRequest() -> MSIDHttpRequest {
        let request = MSIDHttpRequest()
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])

        return request
    }

}
