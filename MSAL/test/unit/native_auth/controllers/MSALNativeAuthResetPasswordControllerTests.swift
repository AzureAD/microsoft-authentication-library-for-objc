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

final class MSALNativeAuthResetPasswordControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthResetPasswordController!
    private var contextMock: MSALNativeAuthRequestContext!
    private var requestProviderMock: MSALNativeAuthResetPasswordRequestProviderMock!
    private var validatorMock: MSALNativeAuthResetPasswordResponseValidatorMock!
    private var correlationId: UUID!

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
        correlationId = .init(uuidString: DEFAULT_TEST_UID)!

        sut = .init(config: MSALNativeAuthConfigStubs.configuration,
                    requestProvider: requestProviderMock,
                    responseValidator: validatorMock, 
                    signInController: MSALNativeAuthControllerFactoryMock().signInController
        )
    }

    // MARK: - ResetPasswordStart (/start request) tests

    func test_whenResetPasswordStart_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_returnsSuccess_it_callsChallenge() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateResetPasswordChallengeFunc(.unexpectedError(nil))
        _ = prepareResetPasswordStartValidatorHelper()

        _ = await sut.resetPassword(parameters: resetPasswordStartParams)

        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    func test_whenResetPasswordStartPassword_returns_redirect_it_returnsBrowserRequiredError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.redirect)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        let apiError = MSALNativeAuthResetPasswordStartResponseError(
            error: .userNotFound,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            target: nil
        )
        validatorMock.mockValidateResetPasswordStartFunc(.error(.userNotFound(apiError)))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .userNotFound)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInResetPasswordStart_returns_unexpectedError_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    // MARK: - ResetPasswordStart (/challenge request) tests

    func test_whenResetPasswordStart_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_challenge_succeeds_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateResetPasswordChallengeFunc(.success("sentTo", .email, 4, "continuationToken"))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        result.telemetryUpdate?(.success(()))
        helper.onResetPasswordCodeRequired(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.continuationToken, "continuationToken")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: true)
    }

    func test_whenResetPasswordStart_challenge_returns_redirect_it_returnsRedirectError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateResetPasswordChallengeFunc(.redirect)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenResetPasswordStart_challenge_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthResetPasswordChallengeValidatedResponse = .error(
            MSALNativeAuthResetPasswordChallengeResponseError(error: .expiredToken,
                                                              errorDescription: "Expired Token",
                                                              errorCodes: nil,
                                                              errorURI: nil,
                                                              innerErrors: nil,
                                                              target: nil))
        validatorMock.mockValidateResetPasswordChallengeFunc(error)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Expired Token")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInResetPasswordStart_challenge_returns_unexpectedError_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = resetPasswordStartParams
        validatorMock.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateResetPasswordChallengeFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordStartValidatorHelper(exp)

        let result = await sut.resetPassword(parameters: resetPasswordStartParams)
        helper.onResetPasswordError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordStart, isSuccessful: false)
    }

    // MARK: - ResendCode tests

    func test_whenResetPasswordResendCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordResendCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_succeeds_it_returnsResetPasswordResendCodeRequired() async {
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        validatorMock.mockValidateResetPasswordChallengeFunc(.success("sentTo", .email, 4, "continuationToken response"))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))
        helper.onResetPasswordResendCodeRequired(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordResendCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.continuationToken, "continuationToken response")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: true)
    }

    func test_whenResetPasswordResendCode_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthResetPasswordChallengeValidatedResponse = .error(
            MSALNativeAuthResetPasswordChallengeResponseError(error: .invalidRequest,
                                                              errorDescription: nil,
                                                              errorCodes: nil,
                                                              errorURI: nil,
                                                              innerErrors: nil,
                                                              target: nil))
        validatorMock.mockValidateResetPasswordChallengeFunc(error)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordResendCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_returns_redirect_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateResetPasswordChallengeFunc(.redirect)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordResendCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    func test_whenResetPasswordResendCode_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateResetPasswordChallengeFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordResendCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordResendCode, isSuccessful: false)
    }

    // MARK: - SubmitCode tests

    func test_whenResetPasswordSubmitCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode(code: "1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordVerifyCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmitCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_succeeds_it_returnsPasswordRequired() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateResetPasswordContinueFunc(.success(continuationToken: ""))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode(code: "1234", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))
        helper.onPasswordRequired(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onPasswordRequiredCalled)
        XCTAssertNotNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmitCode, isSuccessful: true)
    }

    func test_whenResetPasswordSubmitCode_returns_invalidOOB_it_returnsInvalidCode() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        let apiError = MSALNativeAuthResetPasswordContinueResponseError(
            error: .invalidGrant,
            subError: nil,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            target: nil,
            continuationToken: nil
        )
        validatorMock.mockValidateResetPasswordContinueFunc(.invalidOOB(apiError))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode(code: "1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordVerifyCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertEqual(helper.newCodeRequiredState?.continuationToken, "continuationToken")
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .invalidCode)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmitCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        let error : MSALNativeAuthResetPasswordContinueValidatedResponse = .error(
            MSALNativeAuthResetPasswordContinueResponseError(error: .invalidRequest,
                                                             subError: nil,
                                                             errorDescription: nil,
                                                             errorCodes: nil,
                                                             errorURI: nil,
                                                             innerErrors: nil,
                                                             target: nil,
                                                             continuationToken: nil))
        validatorMock.mockValidateResetPasswordContinueFunc(error)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode(code: "1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordVerifyCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(helper.newCodeRequiredState?.continuationToken)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmitCode, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitCode_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateResetPasswordContinueFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode(code: "1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordVerifyCodeError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(helper.newCodeRequiredState?.continuationToken)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitPassword tests

    func test_whenResetPasswordSubmitPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockSubmitRequestFunc(nil, throwError: true)
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_succeeds_it_returnsCompleted() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .succeeded, continuationToken: nil))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))
        helper.onResetPasswordCompleted(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordCompletedCalled)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: true)
    }

    func test_whenResetPasswordSubmitPassword_returns_passwordError_it_returnsCorrectError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        let error : MSALNativeAuthResetPasswordSubmitValidatedResponse = .passwordError(error:
            MSALNativeAuthResetPasswordSubmitResponseError(error: .invalidGrant,
                                                           subError: .passwordTooWeak,
                                                           errorDescription: "Password too weak",
                                                           errorCodes: nil,
                                                           errorURI: nil,
                                                           innerErrors: nil,
                                                           target: nil))
        validatorMock.mockValidateResetPasswordSubmitFunc(error)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.newPasswordRequiredState?.continuationToken, "continuationToken")
        XCTAssertEqual(helper.error?.type, .invalidPassword)
        XCTAssertEqual(helper.error?.errorDescription, "Password too weak")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitPassword_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        let error : MSALNativeAuthResetPasswordSubmitValidatedResponse = .error(
            MSALNativeAuthResetPasswordSubmitResponseError(error: .invalidRequest,
                                                           subError: nil,
                                                           errorDescription: nil,
                                                           errorCodes: nil,
                                                           errorURI: nil,
                                                           innerErrors: nil,
                                                           target: nil))
        validatorMock.mockValidateResetPasswordSubmitFunc(error)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenResetPasswordSubmitPassword_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    // MARK: - SubmitPassword - poll completion tests

    func test_whenSubmitPassword_pollCompletion_returns_failed_it_returnsResetPasswordRequiredError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")
        
        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_passwordError_it_returnsCorrectError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        let error : MSALNativeAuthResetPasswordPollCompletionValidatedResponse =
            .passwordError(error:
                            MSALNativeAuthResetPasswordPollCompletionResponseError(error: .invalidGrant,
                                                                                   subError: .passwordBanned,
                                                                                   errorDescription: "Password banned",
                                                                                   errorCodes: nil,
                                                                                   errorURI: nil,
                                                                                   innerErrors: nil,
                                                                                   target: nil))
        
        validatorMock.mockValidateResetPasswordPollCompletionFunc(error)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.newPasswordRequiredState?.continuationToken, "continuationToken")
        XCTAssertEqual(helper.error?.type, .invalidPassword)
        XCTAssertEqual(helper.error?.errorDescription, "Password banned")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        let error : MSALNativeAuthResetPasswordPollCompletionValidatedResponse = .error(
            MSALNativeAuthResetPasswordPollCompletionResponseError(error: .expiredToken,
                                                             subError: nil,
                                                             errorDescription: "Expired Token",
                                                             errorCodes: nil,
                                                             errorURI: nil,
                                                             innerErrors: nil,
                                                             target: nil))
        validatorMock.mockValidateResetPasswordPollCompletionFunc(error)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Expired Token")

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_notStarted_it_returnsCorrectErrorAfterRetries() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 1))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()

        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .notStarted, continuationToken: "<continuationToken>"))

        prepareMockRequestsForPollCompletionRetries(5)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_failed_it_returnsError() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .failed, continuationToken: ""))

        prepareMockRequestsForPollCompletionRetries(5)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    func test_whenSubmitPassword_pollCompletion_returns_inProgress_it_returnsErrorAfterRetries() async {
        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .inProgress, continuationToken: "<continuationToken>"))

        prepareMockRequestsForPollCompletionRetries(5)

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onResetPasswordRequiredError(result)

        await fulfillment(of: [exp])
        XCTAssertTrue(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: false)
    }

    // MARK: - Sign-in with continuationToken

    func test_whenResetPasswordSucceeds_and_userCallsSignInWithContinuationToken_ResetPasswordControllerPassesCorrectParams() async {
        let username = "username"
        let continuationToken = "continuationToken"

        class SignInAfterResetPasswordDelegateStub: SignInAfterResetPasswordDelegate {
            func onSignInAfterResetPasswordError(error: MSAL.SignInAfterResetPasswordError) {}
        }

        let signInControllerMock = MSALNativeAuthSignInControllerMock()

        sut = .init(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseValidator: validatorMock,
            signInController: signInControllerMock
        )

        requestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedSubmitRequestParameters = expectedSubmitParams()
        validatorMock.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken", pollInterval: 0))
        requestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedPollCompletionParameters = expectedPollCompletionParameters()
        validatorMock.mockValidateResetPasswordPollCompletionFunc(.success(status: .succeeded, continuationToken: continuationToken))

        let exp = expectation(description: "ResetPasswordController expectation")
        let helper = prepareResetPasswordSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword(password: "password", username: username, continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onResetPasswordCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onResetPasswordCompletedCalled)

        checkTelemetryEventResult(id: .telemetryApiIdResetPasswordSubmit, isSuccessful: true)

        let exp2 = expectation(description: "SignInAfterResetPassword expectation")
        signInControllerMock.expectation = exp2
        signInControllerMock.continuationTokenResult = .init(.failure(SignInAfterResetPasswordError(correlationId: correlationId)), correlationId: correlationId)

        helper.signInAfterResetPasswordState?.signIn(delegate: SignInAfterResetPasswordDelegateStub())
        await fulfillment(of: [exp2], timeout: 1)

        XCTAssertEqual(signInControllerMock.username, username)
        XCTAssertEqual(signInControllerMock.continuationToken, continuationToken)
    }

    // MARK: - Common Methods

    private func checkTelemetryEventResult(id: MSALNativeAuthTelemetryApiId, isSuccessful: Bool) {
        XCTAssertEqual(receivedEvents.count, 1)

        guard let telemetryEventDict = receivedEvents.first else {
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

    private func prepareResetPasswordStartValidatorHelper(_ expectation: XCTestExpectation? = nil) -> ResetPasswordStartTestsValidatorHelper {
        let helper = ResetPasswordStartTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onResetPasswordErrorCalled)
        XCTAssertFalse(helper.onResetPasswordCodeRequiredCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareResetPasswordResendCodeValidatorHelper(_ expectation: XCTestExpectation? = nil) -> ResetPasswordResendCodeTestsValidatorHelper {
        let helper = ResetPasswordResendCodeTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onResetPasswordResendCodeErrorCalled)
        XCTAssertFalse(helper.onResetPasswordResendCodeRequiredCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareResetPasswordSubmitCodeValidatorHelper(_ expectation: XCTestExpectation? = nil) -> ResetPasswordVerifyCodeTestsValidatorHelper {
        let helper = ResetPasswordVerifyCodeTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onPasswordRequiredCalled)
        XCTAssertFalse(helper.onResetPasswordVerifyCodeErrorCalled)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareResetPasswordSubmitPasswordValidatorHelper(_ expectation: XCTestExpectation? = nil) -> ResetPasswordRequiredTestsValidatorHelper {
        let helper = ResetPasswordRequiredTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onResetPasswordCompletedCalled)
        XCTAssertFalse(helper.onResetPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        return helper
    }

    private func expectedChallengeParams(token: String = "continuationToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }

    private func expectedContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "continuationToken",
        oobCode: String? = "1234"
    ) -> MSALNativeAuthResetPasswordContinueRequestParameters {
        .init(
            context: contextMock,
            continuationToken: token,
            grantType: grantType,
            oobCode: oobCode
        )
    }

    private func expectedSubmitParams(
        token: String = "continuationToken",
        password: String = "password"
    ) -> MSALNativeAuthResetPasswordSubmitRequestParameters {
        .init(
            context: contextMock,
            continuationToken: token,
            newPassword: password)
    }

    private func expectedPollCompletionParameters(
        token: String = "continuationToken"
    ) -> MSALNativeAuthResetPasswordPollCompletionRequestParameters {
        .init(
            context: contextMock,
            continuationToken: token)
    }

    private func prepareMockRequestsForPollCompletionRetries(_ count: Int) {
        for _ in 1...count {
            _ = MSALNativeAuthHTTPRequestMock.prepareMockRequest()
        }
    }
}
