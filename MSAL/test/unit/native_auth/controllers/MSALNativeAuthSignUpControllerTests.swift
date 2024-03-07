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
    private var correlationId: UUID!

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
        correlationId = .init(uuidString: DEFAULT_TEST_UID)!

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

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)

        helper.onSignUpPasswordStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returnsSuccess_it_callsChallenge() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError(nil))

        let helper = prepareSignUpPasswordStartValidatorHelper()

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    func test_whenSignUpStartPassword_returnsAttributeValidationFailed_it_returnsChallenge() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(error: createInitiateApiError(type: .attributesRequired), invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(error: createInitiateApiError(type: .invalidGrant), invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        result.telemetryUpdate?(.failure(.init(message: "error", correlationId: correlationId)))

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let error : MSALNativeAuthSignUpStartValidatedResponse = .error(
            MSALNativeAuthSignUpStartResponseError(error: .invalidGrant,
                                                   subError: .passwordTooLong,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   continuationToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(error)
        
        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)
        
        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)
        
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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let invalidUsername : MSALNativeAuthSignUpStartValidatedResponse = .invalidUsername(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   subError: nil,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   continuationToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidUsername)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .invalidUsername)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }
    
    func test_whenSignUpStartPassword_returns_unauthorizedClient_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        let unauthorizedClient : MSALNativeAuthSignUpStartValidatedResponse = .unauthorizedClient(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   subError: nil,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   continuationToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(unauthorizedClient)
        
        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)
        
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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError(.init(errorDescription: "Error message")))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error message")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpPasswordStart (/challenge request) tests

    func test_whenSignUpStartPassword_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "continuationToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        result.telemetryUpdate?(.success(()))
        helper.onSignUpCodeRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.continuationToken, "continuationToken 2")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: true)
    }

    func test_whenSignUpStartPassword_challenge_returns_passwordRequired_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
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

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartPasswordParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError(.init(errorDescription: "Error message")))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpPasswordStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartPasswordParams)
        helper.onSignUpPasswordStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error message")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpPasswordStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/start request) tests

    func test_whenSignUpStartCode_cantCreateRequest_returns_it_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(nil, throwError: true)
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returnsSuccess_it_returnsChallenge() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError(nil))

        let helper = prepareSignUpCodeStartValidatorHelper()

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    func test_whenSignUpStartCode_returnsAttributeValidationFailed_it_returnsCorrectError() async {
        let invalidAttributes = ["name"]
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(error: createInitiateApiError(type: .invalidGrant), invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.attributeValidationFailed(error: createInitiateApiError(type: .invalidGrant), invalidAttributes: invalidAttributes))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        result.telemetryUpdate?(.failure(.init(message: "error", correlationId: correlationId)))
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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let error : MSALNativeAuthSignUpStartValidatedResponse = .error(
            MSALNativeAuthSignUpStartResponseError(error: .userAlreadyExists,
                                                   subError: nil,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   continuationToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let invalidUsername : MSALNativeAuthSignUpStartValidatedResponse = .invalidUsername(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   subError: nil,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   continuationToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(invalidUsername)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .invalidUsername)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }
    
    func test_whenSignUpStartCode_returns_unauthorizedClient_it_returnsGeneralError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        let unauthorizedClient : MSALNativeAuthSignUpStartValidatedResponse = .unauthorizedClient(
            MSALNativeAuthSignUpStartResponseError(error: .invalidRequest,
                                                   subError: nil,
                                                   errorDescription: nil,
                                                   errorCodes: nil,
                                                   errorURI: nil,
                                                   innerErrors: nil,
                                                   continuationToken: nil,
                                                   unverifiedAttributes: nil,
                                                   invalidAttributes: nil))
        validatorMock.mockValidateSignUpStartFunc(unauthorizedClient)
        
        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)
        
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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.unexpectedError(.init(errorDescription: "Error Message")))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error Message")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - SignUpCodeStart (/challenge request) tests

    func test_whenSignUpStartCode_challenge_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken 1"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 1")
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "continuationToken 2"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        result.telemetryUpdate?(.success(()))
        helper.onSignUpCodeRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.continuationToken, "continuationToken 2")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: true)
    }

    func test_whenSignUpStartCode_challenge_succeedsPassword_it_returnsCorrectError() async {
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired(""))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
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

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

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
        requestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedStartRequestParameters = signUpStartCodeParams
        validatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError(.init(errorDescription: "Error message")))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpCodeStartValidatorHelper(exp)

        let result = await sut.signUpStart(parameters: signUpStartCodeParams)
        helper.onSignUpStartError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.channelTargetType)
        XCTAssertNil(helper.codeLength)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error message")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpCodeStart, isSuccessful: false)
    }

    // MARK: - ResendCode tests

    func test_whenSignUpResendCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, continuationToken: "continuationToken")
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
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "continuationToken"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, continuationToken: "continuationToken")
        result.telemetryUpdate?(.success(()))
        helper.onSignUpResendCodeCodeRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeCodeRequiredCalled)
        XCTAssertEqual(helper.newState?.continuationToken, "continuationToken")
        XCTAssertEqual(helper.sentTo, "sentTo")
        XCTAssertEqual(helper.channelTargetType, .email)
        XCTAssertEqual(helper.codeLength, 4)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: true)
    }

    func test_whenSignUpResendCode_succeedsPassword_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("continuationToken 1"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, continuationToken: "continuationToken 2")
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
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
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

        let result = await sut.resendCode(username: "", context: contextMock, continuationToken: "continuationToken")
        helper.onSignUpResendCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeErrorCalled)
        XCTAssertNotNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.codeLength)
        XCTAssertNotNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    func test_whenSignUpResendCode_returns_redirect_it_returnsCorrectError() async {
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, continuationToken: "continuationToken")
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
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams()
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError(.init(errorDescription: "Error message")))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpResendCodeValidatorHelper(exp)

        let result = await sut.resendCode(username: "", context: contextMock, continuationToken: "continuationToken")
        helper.onSignUpResendCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpResendCodeErrorCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.sentTo)
        XCTAssertNil(helper.codeLength)
        XCTAssertNotNil(helper.error)
        XCTAssertEqual(helper.error?.errorDescription, "Error message")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpResendCode, isSuccessful: false)
    }

    // MARK: - SubmitCode tests

    func test_whenSignUpSubmitCode_cantCreateRequest_it_returns_unexpectedError() async {
        requestProviderMock.mockContinueRequestFunc(nil, throwError: true)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
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
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: ""))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
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
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidGrant,
                                                      subError: .invalidOOBValue,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      continuationToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertEqual(helper.newCodeRequiredState?.continuationToken, "continuationToken")
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .invalidCode)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_it_returnsAttributesRequired() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(continuationToken: "continuationToken", requiredAttributes: [], error: .init()))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.continuationToken, "continuationToken")
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_attributesRequired_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(continuationToken: "continuationToken", requiredAttributes: [], error: .init()))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.failure(.init(message: "error", correlationId: correlationId)))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.continuationToken, "continuationToken")
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_attributeValidationFailed_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(error: createContinueApiError(type: .invalidGrant), invalidAttributes: ["name"]))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))
        
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      subError: nil,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      continuationToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState?.continuationToken)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpVerifyCodeErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState?.continuationToken)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    // MARK: - SubmitCode + credential_required error tests

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError(nil))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andCantCreateRequest() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.mockChallengeRequestFunc(nil, throwError: true)
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
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
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("continuationToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpPasswordRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertTrue(helper.onSignUpPasswordRequiredCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertEqual(helper.newPasswordRequiredState?.continuationToken, "continuationToken 3")
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: true)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.passwordRequired("continuationToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.failure(.init(message: "error", correlationId: correlationId)))

        helper.onSignUpPasswordRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertTrue(helper.onSignUpPasswordRequiredCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newCodeRequiredState)
        XCTAssertEqual(helper.newPasswordRequiredState?.continuationToken, "continuationToken 3")
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andSucceedOOB_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.codeRequired("", .email, 4, "continuationToken 3"))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpVerifyCodeError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(requestProviderMock.challengeCalled)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitCode, isSuccessful: false)
    }

    func test_whenSignUpSubmitCode_returns_credentialRequired_it_returnsChallengeEndpoint_andRedirects() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.redirect)

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
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
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
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

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
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
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams()
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))
        requestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedChallengeRequestParameters = expectedChallengeParams(token: "continuationToken 2")
        validatorMock.mockValidateSignUpChallengeFunc(.unexpectedError(nil))

        XCTAssertFalse(requestProviderMock.challengeCalled)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitCodeValidatorHelper(exp)

        let result = await sut.submitCode("1234", username: "", continuationToken: "continuationToken", context: contextMock)
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

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSubmitPassword_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: "continuationToken"))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCompletedCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_invalidUserInput_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidGrant,
                                                      subError: .passwordTooWeak,
                                                      errorDescription: "Password too weak",
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      continuationToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertEqual(helper.newPasswordRequiredState?.continuationToken, "continuationToken")
        XCTAssertEqual(helper.error?.type, .invalidPassword)
        XCTAssertEqual(helper.error?.errorDescription, "Password too weak")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(continuationToken: "continuationToken 2", requiredAttributes: [], error: .init()))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.continuationToken, "continuationToken 2")
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)
    }

    func test_whenSignUpSubmitPassword_returns_attributesRequired_butTelemetryUpdateFails_it_updatesTelemetryCorrectly() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(continuationToken: "continuationToken 2", requiredAttributes: [], error: .init()))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.failure(.init(message: "error", correlationId: correlationId)))

        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newAttributesRequiredState?.continuationToken, "continuationToken 2")
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      subError: nil,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      continuationToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_credentialRequired_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError(.init(errorDescription: "Error description")))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpPasswordRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpPasswordRequiredErrorCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertEqual(helper.error?.type, .generalError)
        XCTAssertEqual(helper.error?.errorDescription, "Error description")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: false)
    }

    func test_whenSignUpSubmitPassword_returns_attributeValidationFailed_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(error: createContinueApiError(type: .invalidGrant), invalidAttributes: ["key"]))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: "", continuationToken: "continuationToken", context: contextMock)
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

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSubmitAttributes_succeeds_it_continuesTheFlow() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: ""))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCompletedCalled)
        XCTAssertNil(helper.newState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: true)
    }

    func test_whenSignUpSubmitAttributes_returns_invalidUserInput_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .invalidUserInput(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidGrant,
                                                      subError: .attributeValidationFailed,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      continuationToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_error_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        let error : MSALNativeAuthSignUpContinueValidatedResponse = .error(
            MSALNativeAuthSignUpContinueResponseError(error: .invalidRequest,
                                                      subError: nil,
                                                      errorDescription: nil,
                                                      errorCodes: nil,
                                                      errorURI: nil,
                                                      innerErrors: nil,
                                                      continuationToken: nil,
                                                      requiredAttributes: nil,
                                                      unverifiedAttributes: nil,
                                                      invalidAttributes: nil))
        validatorMock.mockValidateSignUpContinueFunc(error)

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_attributesRequired_it_returnsAttributesRequiredError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.attributesRequired(continuationToken: "continuationToken 2", requiredAttributes: [], error: .init()))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))
        helper.onSignUpAttributesRequired(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredCalled)
        XCTAssertEqual(helper.newState?.continuationToken, "continuationToken 2")

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_credentialRequired_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.credentialRequired(continuationToken: "continuationToken 2", error: .init()))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_unexpectedError_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.unexpectedError(nil))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpAttributesRequiredError(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpAttributesRequiredErrorCalled)
        XCTAssertNil(helper.newState)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    func test_whenSignUpSubmitAttributes_returns_attributeValidationFailed_it_returnsCorrectError() async {
        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(
            grantType: .attributes,
            oobCode: nil,
            attributes: ["key": "value"]
        )
        validatorMock.mockValidateSignUpContinueFunc(.attributeValidationFailed(error: createContinueApiError(type: .invalidGrant), invalidAttributes: ["attribute"]))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitAttributesValidatorHelper(exp)

        let result = await sut.submitAttributes(["key": "value"], username: "", continuationToken: "continuationToken", context: contextMock)
        result.telemetryUpdate?(.success(()))
        helper.onSignUpAttributesValidationFailed(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpInvalidAttributesCalled)
        XCTAssertEqual(helper.newState?.continuationToken, "continuationToken")
        XCTAssertEqual(helper.invalidAttributes, ["attribute"])

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitAttributes, isSuccessful: false)
    }

    // MARK: - Sign-in with ContinuationToken

    func test_whenSignUpSucceeds_and_userCallsSignInWithContinuationToken_signUpControllerPassesCorrectParams() async {
        let username = "username"
        let continuationToken = "continuationToken"

        class SignInAfterSignUpDelegateStub: SignInAfterSignUpDelegate {
            func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {}
            func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {}
        }

        requestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        requestProviderMock.expectedContinueRequestParameters = expectedContinueParams(grantType: .password, password: "password", oobCode: nil)
        validatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: continuationToken))

        let exp = expectation(description: "SignUpController expectation")
        let helper = prepareSignUpSubmitPasswordValidatorHelper(exp)

        let result = await sut.submitPassword("password", username: username, continuationToken: "continuationToken", context: contextMock)
        helper.onSignUpCompleted(result)

        await fulfillment(of: [exp], timeout: 1)
        XCTAssertTrue(helper.onSignUpCompletedCalled)
        XCTAssertNil(helper.newAttributesRequiredState)
        XCTAssertNil(helper.newPasswordRequiredState)
        XCTAssertNil(helper.error)

        checkTelemetryEventResult(id: .telemetryApiIdSignUpSubmitPassword, isSuccessful: true)

        let exp2 = expectation(description: "SignInAfterSignUp expectation")
        signInControllerMock.expectation = exp2
        signInControllerMock.continuationTokenResult = .init(.init(.failure(SignInAfterSignUpError(correlationId: correlationId)), correlationId: correlationId))
        helper.signInAfterSignUpState?.signIn(delegate: SignInAfterSignUpDelegateStub())
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

    private func expectedChallengeParams(token: String = "continuationToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }

    private func expectedContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "continuationToken",
        password: String? = nil,
        oobCode: String? = "1234",
        attributes: [String: Any]? = nil
    ) -> MSALNativeAuthSignUpContinueRequestProviderParams {
        .init(
            grantType: grantType,
            continuationToken: token,
            password: password,
            oobCode: oobCode,
            attributes: attributes,
            context: contextMock
        )
    }

    private func createInitiateApiError(type: MSALNativeAuthSignUpStartOauth2ErrorCode) -> MSALNativeAuthSignUpStartResponseError {
        return .init(
            error: type,
            subError: nil,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            continuationToken: nil,
            unverifiedAttributes: nil,
            invalidAttributes: nil
        )
    }

    private func createContinueApiError(type: MSALNativeAuthSignUpContinueOauth2ErrorCode) -> MSALNativeAuthSignUpContinueResponseError {
        return .init(
            error: type,
            subError: nil,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            continuationToken: nil,
            requiredAttributes: nil,
            unverifiedAttributes: nil,
            invalidAttributes: nil
        )
    }
}
