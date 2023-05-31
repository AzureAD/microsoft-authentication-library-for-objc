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

final class MSALNativeAuthSignUpControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthSignUpController!
    private var contextMock: MSALNativeAuthRequestContext!
    private var requestProviderMock: MSALNativeAuthSignUpRequestProviderMock!
    private var validatorMock: MSALNativeAuthSignUpResponseValidatorMock!
    private var telemetryDispatcher: MSALNativeAuthTelemetryTestDispatcher!

    private var signUpStartPasswordParams: MSALNativeAuthSignUpStartRequestProviderParameters {
        .init(
            username: "user@contoso.com",
            password: "password",
            attributes: ["key": "value"],
            context: contextMock
        )
    }

    private var signUpStartCodeParams: MSALNativeAuthSignUpStartRequestProviderParameters {
        .init(
            username: "user@contoso.com",
            password: nil,
            attributes: ["key": "value"],
            context: contextMock
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        contextMock = .init(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        requestProviderMock = .init()
        validatorMock = .init()

        sut = MSALNativeAuthSignUpController(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseValidator: validatorMock,
            cacheAccessor: MSALNativeAuthCacheAccessorMock()
        )
    }

    // MARK: - SignUpPasswordStart (/start request) tests

    func test_whenSignUpStartPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        // TODO: Update to `await fulfillment()` in every test
        // Note: use of wait() instead of `await fulfillment()` to pass CI (which uses Xcode 13.4.1)
        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returnsVerificationRequired_it_callsChallenge() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: prepareSignUpPasswordStartDelegateSpy())
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    func test_whenSignUpStartPassword_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.error(.passwordTooLong))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .invalidPassword)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartPassword_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpPasswordStart (/challenge request) tests

    func test_whenSignUpStartPassword_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_succeeds_it_callsDelegate() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successOOB("sentTo", .email, 4, "signUpToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "signUpToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: true)
    }

    func test_whenSignUpStartPassword_challenge_returns_succeedPassword_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successPassword(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.error(.expiredToken))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.expiredToken)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartPassword_challenge_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpPasswordStartDelegateSpy(exp)

        await sut.signUpStartPassword(parameters: signUpStartPasswordParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/start request) tests

    func test_whenSignUpStartCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returnsVerificationRequired_it_callsChallenge() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: prepareSignUpCodeStartDelegateSpy())
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    func test_whenSignUpStartCode_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.error(.invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartCode_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/challenge request) tests

    func test_whenSignUpStartCode_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_succeeds_it_callsDelegate() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successOOB("sentTo", .email, 4, "signUpToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "signUpToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: true)
    }

    func test_whenSignUpStartCode_challenge_succeedsPassword_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successPassword(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.error(.expiredToken))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.expiredToken)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartCode_challenge_returns_unexpectedError_it_callsDelegateGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: ""))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpCodeStartDelegateSpy(exp)

        await sut.signUpStartCode(parameters: signUpStartCodeParams, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - ResendCode tests

    func test_whenSignUpResendCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(context: contextMock, signUpToken: "flowToken", delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successOOB("sentTo", .email, 4, "flowToken response"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(context: contextMock, signUpToken: "", delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeCodeRequiredCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "flowToken response")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.codeLength, 4)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: true)
    }

    func test_whenSignUpResendCode_succeedsPassword_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successPassword(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(context: contextMock, signUpToken: "", delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.error(.invalidRequest))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(context: contextMock, signUpToken: "", delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_redirect_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(context: contextMock, signUpToken: "", delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpResendCodeDelegateSpy(exp)

        await sut.resendCode(context: contextMock, signUpToken: "", delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    // MARK: - SubmitCode tests

    func test_whenSignUpSubmitCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSubmitCode_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.success(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCompletedCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_invalidUserInput_it_callsDelegateInvalidCode() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.invalidUserInput(.invalidOOBValue, "flowToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertEqual(delegate.newCodeRequiredState?.flowToken, "flowToken")
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .invalidCode)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_it_callsDelegateAttributesRequired() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired("flowToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(delegate.newAttributesRequiredState?.flowToken, "flowToken")
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_but_developerDoesnNotImplementDelegate_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.error(.invalidRequest))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState?.flowToken)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitPassword + credential_required error tests

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andCantCreateRequest() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andSucceeds() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successPassword("flowToken"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertEqual(delegate.newPasswordRequiredState?.flowToken, "flowToken")
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andSucceeds_butUserHasNotImplementedOptionalProtocol() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successPassword(""))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpVerifyCodeDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andSucceedOOB_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.successOOB("", .email, 4, ""))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andRedirects() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andReturnsError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.error(.expiredToken))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_callsChallengeEndpoint_andReturnsUnexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired("flowToken"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitCodeDelegateSpy(exp)

        await sut.submitCode("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitPassword tests

    func test_whenSignUpSubmitPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSubmitPassword_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.success(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCompletedCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_invalidUserInput_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.invalidUserInput(.passwordTooWeak, "flowToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertEqual(delegate.newPasswordRequiredState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.passwordTooWeak)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired("flowToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(delegate.newAttributesRequiredState?.flowToken, "flowToken")
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_it_callsDelegateError_butDeveloperHasNotImplementedOptionalDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired("flowToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = SignUpPasswordRequiredDelegateOptionalMethodsNotImplemented(expectation: exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(delegate.error?.errorDescription, MSALNativeAuthErrorMessage.delegateNotImplemented)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.error(.invalidRequest))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_credentialRequired_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitPasswordDelegateSpy(exp)

        await sut.submitPassword("", signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    // MARK: - SubmitAttributes tests

    func test_whenSignUpSubmitAttributes_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes([:], signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSubmitAttributes_succeeds_it_callsDelegate() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.success(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes([:], signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpCompletedCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: true)
    }

    func test_whenSignUpSubmitAttributes_returns_invalidUserInput_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.invalidUserInput(.invalidAttributes, "flowToken"))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes([:], signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertEqual(delegate.newState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.error?.type, .invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_error_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.error(.invalidRequest))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes([:], signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_attributesRequired_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes([:], signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_credentialRequired_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes([:], signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_unexpectedError_it_callsDelegateError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let delegate = prepareSignUpSubmitAttributesDelegateSpy(exp)

        await sut.submitAttributes([:], signUpToken: "", context: contextMock, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertEqual(delegate.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    // MARK: - Common Methods

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

    private func prepareSignUpPasswordStartDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpPasswordStartDelegateSpy {
        let delegate = SignUpPasswordStartDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpPasswordErrorCalled)
        XCTAssertFalse(delegate.onSignUpCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpCodeStartDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpCodeStartDelegateSpy {
        let delegate = SignUpCodeStartDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCodeErrorCalled)
        XCTAssertFalse(delegate.onSignUpCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.channelTargetType)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpResendCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpResendCodeDelegateSpy {
        let delegate = SignUpResendCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpResendCodeErrorCalled)
        XCTAssertFalse(delegate.onSignUpResendCodeCodeRequiredCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.sentTo)
        XCTAssertNil(delegate.codeLength)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpSubmitCodeDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpVerifyCodeDelegateSpy {
        let delegate = SignUpVerifyCodeDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCompletedCalled)
        XCTAssertFalse(delegate.onSignUpPasswordRequiredCalled)
        XCTAssertFalse(delegate.onSignUpVerifyCodeErrorCalled)
        XCTAssertFalse(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertNil(delegate.newCodeRequiredState)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpSubmitPasswordDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpPasswordRequiredDelegateSpy {
        let delegate = SignUpPasswordRequiredDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCompletedCalled)
        XCTAssertFalse(delegate.onSignUpPasswordRequiredErrorCalled)
        XCTAssertFalse(delegate.onSignUpAttributesRequiredCalled)
        XCTAssertNil(delegate.newAttributesRequiredState)
        XCTAssertNil(delegate.newPasswordRequiredState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareSignUpSubmitAttributesDelegateSpy(_ expectation: XCTestExpectation? = nil) -> SignUpAttributesRequiredDelegateSpy {
        let delegate = SignUpAttributesRequiredDelegateSpy(expectation: expectation)
        XCTAssertFalse(delegate.onSignUpCompletedCalled)
        XCTAssertFalse(delegate.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(delegate.newState)
        XCTAssertNil(delegate.error)

        return delegate
    }

    private func prepareMockRequest() -> MSIDHttpRequest {
        let request = MSIDHttpRequest()
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        return request
    }
}
