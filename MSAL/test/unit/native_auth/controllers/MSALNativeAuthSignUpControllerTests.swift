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

final class MSALNativeAuthSignUpControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthSignUpController!
    private var contextMock: MSALNativeAuthRequestContext!
    private var requestProviderMock: MSALNativeAuthSignUpRequestProviderMock!
    private var validatorMock: MSALNativeAuthSignUpResponseValidatorMock!
    private var signInControllerMock: MSALNativeAuthSignInControllerMock!

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
        signInControllerMock = .init()

        sut = MSALNativeAuthSignUpController(
            config: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseValidator: validatorMock,
            signInController: signInControllerMock
        )
    }

    // MARK: - SignUpPasswordStart (/start request) tests

    func test_whenSignUpStartPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)

        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returnsVerificationRequired_it_returnsChallenge() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let helper = prepareSignUpPasswordStartValidatorHelper()

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returnsAttributeValidationFailed_it_returnsChallenge() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpAttributesInvalid(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesInvalidCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.attributeNames, invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_telemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        result.telemetryUpdate?(.failure(.init(identifier: 1, message: "error")))

        helper.onSignUpAttributesInvalid(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesInvalidCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.attributeNames, invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returns_redirect_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let error : MSALNativeAuthSignUpStartValidatedResponse = .error(
            MSALNativeAuthSignUpStartResponseError(error: .passwordTooLong,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(error)
        
        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)
        
        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)
        
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .invalidPassword)
        
        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returns_invalidUsername_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let invalidUsername : MSALNativeAuthSignUpStartValidatedResponse = .invalidUsername(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidUsername)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .invalidUsername)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }
    
    func test_whenSignUpStartPassword_returns_invalidClientId_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let invalidClientId : MSALNativeAuthSignUpStartValidatedResponse = .invalidClientId(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidClientId)
        
        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)
        
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        
        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartPassword_returns_unexpectedError_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpPasswordStart (/challenge request) tests

    func test_whenSignUpStartPassword_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpCodeRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.flowToken, "signUpToken 2")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: true)
    }

    func test_whenSignUpStartPassword_challenge_returns_passwordRequired_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_returns_redirect_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_challenge_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken,
                                                       errorDescription: "Expired Token",
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Expired Token")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartPassword_challenge_returns_unexpectedError_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStartPassword(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/start request) tests

    func test_whenSignUpStartCode_cantCreateRequest_returns_it_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returnsVerificationRequired_it_returnsChallenge() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let helper = prepareSignUpCodeStartValidatorHelper()

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returnsAttributeValidationFailed_it_returnsCorrectError() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        result.telemetryUpdate?(.success(()))
        helper.onSignUpAttributesInvalid(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesInvalidCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.attributeNames, invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_telemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        result.telemetryUpdate?(.failure(.init(identifier: 1, message: "error")))
        helper.onSignUpAttributesInvalid(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesInvalidCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.attributeNames, invalidAttributes)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returns_redirect_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let error : MSALNativeAuthSignUpStartValidatedResponse = .error(
            MSALNativeAuthSignUpStartResponseError(error: .userAlreadyExists,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .userAlreadyExists)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returns_invalidUsername_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let invalidUsername : MSALNativeAuthSignUpStartValidatedResponse = .invalidUsername(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidUsername)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .invalidUsername)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }
    
    func test_whenSignUpStartCode_returns_invalidClientId_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let invalidClientId : MSALNativeAuthSignUpStartValidatedResponse = .invalidClientId(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   signUpToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidClientId)
        
        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)
        
        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        
        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartCode_returns_unexpectedError_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/challenge request) tests

    func test_whenSignUpStartCode_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken 1", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 1")
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpCodeRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.flowToken, "signUpToken 2")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: true)
    }

    func test_whenSignUpStartCode_challenge_succeedsPassword_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_returns_redirect_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_challenge_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken,
                                                       errorDescription: "Expired Token",
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Expired Token")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenValidatorInSignUpStartCode_challenge_it_returns_unexpectedError_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""]))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStartCode(parameters: signUpStartCodeParams)
        helper.onSignUpError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - ResendCode tests

    func test_whenSignUpResendCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken")
        helper.onSignUpResendCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.codeLength)
        XCTAssertNotNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken")
        helper.onSignUpResendCodeCodeRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.flowToken, "signUpToken")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: true)
    }

    func test_whenSignUpResendCode_succeedsPassword_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("signUpToken 1"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken 2")
        helper.onSignUpResendCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.codeLength)
        XCTAssertNotNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .invalidRequest,
                                                       errorDescription: nil,
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken")
        helper.onSignUpResendCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.codeLength)
        XCTAssertNotNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_redirect_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken")
        helper.onSignUpResendCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.codeLength)
        XCTAssertNotNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, signUpToken: "signUpToken")
        helper.onSignUpResendCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.codeLength)
        XCTAssertNotNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    // MARK: - SubmitCode tests

    func test_whenSignUpSubmitCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSubmitCode_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.success(""))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCompletedCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_invalidUserInput_it_returnsInvalidCode() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidOOBValue,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertEqual(helper.newCodeRequiredState?.flowToken, "signUpToken")
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .invalidCode)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_it_returnsAttributesRequired() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken", requiredAttributes: []))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.flowToken, "signUpToken")
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken", requiredAttributes: []))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.failure(.init(identifier: 1, message: "error")))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.flowToken, "signUpToken")
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_attributeValidationFailed_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(signUpToken: "signUpToken 2", invalidAttributes: ["name"]))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.success(()))
        
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState?.flowToken)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState?.flowToken)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitCode + credential_required error tests

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andCantCreateRequest() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andSucceeds() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("signUpToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpPasswordRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertTrue(helper.onSignUpPasswordRequiredCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertEqual(helper.newPasswordRequiredState?.flowToken, "signUpToken 3")
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("signUpToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.failure(.init(identifier: 1, message: "error")))

        helper.onSignUpPasswordRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertTrue(helper.onSignUpPasswordRequiredCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertEqual(helper.newPasswordRequiredState?.flowToken, "signUpToken 3")
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andSucceedOOB_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("", .email, 4, "signUpToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andRedirects() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .browserRequired)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andReturnsError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        let error : MSALNativeAuthSignUpChallengeValidatedResponse = .error(
            MSALNativeAuthSignUpChallengeResponseError(error: .expiredToken,
                                                       errorDescription: nil,
                                                       errorCodes: nil,
                                                       errorURI: nil,
                                                       innerErrors: nil))
        validatorMock.mockValidateSignUpChallengeFunc(error)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andReturnsUnexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))
        requestProviderMock.mockChallengeRequestFunc(prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "signUpToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitPassword tests

    func test_whenSignUpSubmitPassword_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSubmitPassword_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.success("signInSLT"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCompletedCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_invalidUserInput_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .passwordTooWeak,
                                                      errorDescription: "Password too weak",
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertEqual(helper.newPasswordRequiredState?.flowToken, "signUpToken")
        XCTAssertEqual(helper.error?.type, .invalidPassword)
        XCTAssertEqual(helper.error?.errorDescription, "Password too weak")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken 2", requiredAttributes: []))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.flowToken, "signUpToken 2")
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken 2", requiredAttributes: []))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.failure(.init(identifier: 1, message: "error")))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.flowToken, "signUpToken 2")
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_credentialRequired_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_attributeValidationFailed_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(signUpToken: "signUpToken 2", invalidAttributes: ["key"]))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", signUpToken: "signUpToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    // MARK: - SubmitAttributes tests

    func test_whenSignUpSubmitAttributes_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSubmitAttributes_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.success(""))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCompletedCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: true)
    }

    func test_whenSignUpSubmitAttributes_returns_invalidUserInput_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .attributeValidationFailed,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      signUpToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_attributesRequired_it_returnsAttributesRequiredError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(signUpToken: "signUpToken 2", requiredAttributes: []))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newState?.flowToken, "signUpToken 2")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_credentialRequired_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(signUpToken: "signUpToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_attributeValidationFailed_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(signUpToken: "signUpToken 2", invalidAttributes: ["attribute"]))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpAttributesValidationFailed(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpInvalidAttributesCalled)
        XCTAssertEqual(helper.newState?.flowToken, "signUpToken 2")
        XCTAssertEqual(helper.invalidAttributes, ["attribute"])

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    // MARK: - Sign-in with SLT (Short-Lived Token)

    func test_whenSignUpSucceeds_and_userCallsSignInWithSLT_signUpControllerPassesCorrectParams() async {
        let username = "username"
        let slt = "signInSLT"

        class SignInAfterSignUpDelegateStub: SignInAfterSignUpDelegate {
            func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {}
            func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {}
        }

        requestProviderMock.mockContinueRequestFunc(prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.success(slt))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: username, signUpToken: "signUpToken", context: contextMock)
        helper.onSignUpCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCompletedCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)

        let exp2 = expectation(description: "SignInAfterSignUp expectation")
        signInControllerMock.expectation = exp2
        signInControllerMock.signInSLTResult = .failure(.init())
        helper.signInAfterSignUpState?.signIn(delegate: SignInAfterSignUpDelegateStub())
        await fulfillment(of: [exp2], timeout: 1)

        XCTAssertEqual(signInControllerMock.username, username)
        XCTAssertEqual(signInControllerMock.slt, slt)
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

    private func prepareSignUpPasswordStartValidatorHelper(_ expectation: XCTestExpectation? = nil) -> SignUpPasswordStartTestsValidatorHelper {
        let helper = SignUpPasswordStartTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onSignUpPasswordErrorCalled)
        XCTAssertFalse(helper.onSignUpCodeRequiredCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareSignUpCodeStartValidatorHelper(_ expectation: XCTestExpectation? = nil) -> SignUpCodeStartTestsValidatorHelper {
        let helper = SignUpCodeStartTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onSignUpCodeErrorCalled)
        XCTAssertFalse(helper.onSignUpCodeRequiredCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareSignUpResendCodeValidatorHelper(_ expectation: XCTestExpectation? = nil) -> SignUpResendCodeTestsValidatorHelper {
        let helper = SignUpResendCodeTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onSignUpResendCodeErrorCalled)
        XCTAssertFalse(helper.onSignUpResendCodeCodeRequiredCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareSignUpSubmitCodeValidatorHelper(_ expectation: XCTestExpectation? = nil) -> SignUpVerifyCodeTestsValidatorHelper {
        let helper = SignUpVerifyCodeTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onSignUpCompletedCalled)
        XCTAssertFalse(helper.onSignUpPasswordRequiredCalled)
        XCTAssertFalse(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertFalse(helper.onSignUpAttributesRequiredCalled)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareSignUpSubmitPasswordValidatorHelper(_ expectation: XCTestExpectation? = nil) -> SignUpPasswordRequiredTestsValidatorHelper {
        let helper = SignUpPasswordRequiredTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onSignUpCompletedCalled)
        XCTAssertFalse(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertFalse(helper.onSignUpAttributesRequiredCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareSignUpSubmitAttributesValidatorHelper(_ expectation: XCTestExpectation? = nil) -> SignUpAttributesRequiredTestsValidatorHelper {
        let helper = SignUpAttributesRequiredTestsValidatorHelper(expectation: expectation)
        XCTAssertFalse(helper.onSignUpCompletedCalled)
        XCTAssertFalse(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.error)

        return helper
    }

    private func prepareMockRequest() -> MSIDHttpRequest {
        let request = MSIDHttpRequest()
        HttpModuleMockConfigurator.configure(request: request, responseJson: [""])
        
        return request
    }

    private func expectedChallengeParams(token: String = "signUpToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }

    private func expectedContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "signUpToken",
        password: String? = nil,
        oobCode: String? = "1234",
        attributes: [String: Any]? = nil
    ) -> MSALNativeAuthSignUpContinueRequestProviderParams {
        .init(
            grantType: grantType,
            signUpToken: token,
            password: password,
            oobCode: oobCode,
            attributes: attributes,
            context: contextMock
        )
    }
}
