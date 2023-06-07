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

final class MSALNativeAuthSignInResponseValidatorTest: MSALNativeAuthTestCase {
    
    private var sut: MSALNativeAuthSignInResponseValidator!
    private var responseHandler: MSALNativeAuthTokenResponseHandlerMock!
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private var tokenResponse = MSIDTokenResponse()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        responseHandler = MSALNativeAuthTokenResponseHandlerMock()
        sut = MSALNativeAuthSignInResponseValidator(tokenResponseHandler: responseHandler)
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
    }
    
    // MARK: token API tests
    
    func test_whenValidSignInTokenResponse_validationIsSuccessful() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let tokenResult = MSIDTokenResult()
        let tokenResponse = MSIDAADTokenResponse()
        responseHandler.mockHandleTokenFunc(result: tokenResult)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .success(tokenResponse))
        if case .success(tokenResult, tokenResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInvalidSignInTokenResponse_anErrorIsReturned() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthInternalError.generalError)
        responseHandler.expectedContext = context
        responseHandler.expectedValidateAccount = true
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .success(MSIDAADTokenResponse()))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInvalidErrorTokenResponse_anErrorIsReturned() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthInternalError.generalError)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(MSALNativeAuthInternalError.headerNotSerialized))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_invalidGrantTokenResponse_isTranslatedToProperErrorResult() {
        let userNotFoundError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.userNotFound], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: userNotFoundError, expectedError: .userNotFound)
        let invalidPasswordError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.invalidCredentials], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidPasswordError, expectedError: .invalidPassword)
        let invalidOTPCodeError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.invalidOTP], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidOTPCodeError, expectedError: .invalidOOBCode)
        let invalidAuthTypeError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.invalidAuthenticationType], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidAuthTypeError, expectedError: .invalidAuthenticationType)
        let genericErrorCodeError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: genericErrorCodeError, expectedError: .generalError)
        let strongAuthRequiredError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.strongAuthRequired], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: strongAuthRequiredError, expectedError: .strongAuthRequired)
    }
    
    func test_errorTokenResponse_isTranslatedToProperErrorResult() {
        let invalidReqError = MSALNativeAuthSignInTokenResponseError(error: .invalidRequest, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidReqError, expectedError: .invalidRequest)
        let invalidClientError = MSALNativeAuthSignInTokenResponseError(error: .invalidClient, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidClientError, expectedError: .invalidClient)
        let expiredTokenError = MSALNativeAuthSignInTokenResponseError(error: .expiredToken, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: expiredTokenError, expectedError: .expiredToken)
        let unsupportedChallengeTypeError = MSALNativeAuthSignInTokenResponseError(error: .unsupportedChallengeType, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: unsupportedChallengeTypeError, expectedError: .unsupportedChallengeType)
        let invalidScopeError = MSALNativeAuthSignInTokenResponseError(error: .invalidScope, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidScopeError, expectedError: .invalidScope)
        let authPendingError = MSALNativeAuthSignInTokenResponseError(error: .authorizationPending, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: authPendingError, expectedError: .authorizationPending)
        let slowDownError = MSALNativeAuthSignInTokenResponseError(error: .slowDown, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: slowDownError, expectedError: .slowDown)
    }
    
    // MARK: challenge API tests
    
    func test_whenChallengeTypeRedirect_validationShouldReturnRedirectError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(credentialToken: nil, challengeType: .redirect, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validate(context: context, result: .success(challengeResponse))
        if case .error(.redirect) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypePassword_validationShouldReturnPasswordRequired() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(credentialToken: credentialToken, challengeType: .password, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validate(context: context, result: .success(challengeResponse))
        if case .passwordRequired(credentialToken: credentialToken) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypePasswordAndNoCredentialToken_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(credentialToken: nil, challengeType: .password, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validate(context: context, result: .success(challengeResponse))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypeOOB_validationShouldReturnCodeRequired() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"
        let targetLabel = "targetLabel"
        let codeLength = 4
        let channelType = MSALNativeAuthInternalChannelType.email
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(credentialToken: credentialToken, challengeType: .oob, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: channelType, codeLength: codeLength, interval: nil)
        let result = sut.validate(context: context, result: .success(challengeResponse))
        if case .codeRequired(credentialToken: credentialToken, sentTo: targetLabel, channelType: .email, codeLength: codeLength) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypeOOBButMissingAttributes_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"
        let targetLabel = "targetLabel"
        let codeLength = 4
        let channelType = MSALNativeAuthInternalChannelType.email
        let missingCredentialToken = MSALNativeAuthSignInChallengeResponse(credentialToken: nil, challengeType: .oob, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: channelType, codeLength: codeLength, interval: nil)
        var result = sut.validate(context: context, result: .success(missingCredentialToken))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingTargetLabel = MSALNativeAuthSignInChallengeResponse(credentialToken: credentialToken, challengeType: .oob, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: channelType, codeLength: codeLength, interval: nil)
        result = sut.validate(context: context, result: .success(missingTargetLabel))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingChannelType = MSALNativeAuthSignInChallengeResponse(credentialToken: credentialToken, challengeType: .oob, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: nil, codeLength: codeLength, interval: nil)
        result = sut.validate(context: context, result: .success(missingChannelType))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingCodeLength = MSALNativeAuthSignInChallengeResponse(credentialToken: credentialToken, challengeType: .oob, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: channelType, codeLength: nil, interval: nil)
        result = sut.validate(context: context, result: .success(missingCodeLength))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypeOTP_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(credentialToken: "something", challengeType: .otp, bindingMethod: nil, challengeTargetLabel: "some", challengeChannel: .email, codeLength: 2, interval: nil)
        let result = sut.validate(context: context, result: .success(challengeResponse))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeErrorResponse_errorShouldBeMappedCorrectly() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let genericError = MSALNativeAuthInternalError.generalError
        let result: MSALNativeAuthSignInChallengeValidatedResponse = sut.validate(context: context, result: .failure(genericError))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        checkRelationBetweenErrorResponseAndValidatedErrorResult(errorCode: .expiredToken, expectedValidatedError: .expiredToken)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(errorCode: .invalidClient, expectedValidatedError: .invalidClient)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(errorCode: .invalidGrant, expectedValidatedError: .invalidToken)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(errorCode: .invalidRequest, expectedValidatedError: .invalidRequest)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(errorCode: .unsupportedChallengeType, expectedValidatedError: .unsupportedChallengeType)
    }
    
    // MARK: initiate API tests
    
    func test_whenInitiateResponseIsValid_validationShouldBeSuccessful() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let credentialToken = "credentialToken"
        let initiateResponse = MSALNativeAuthSignInInitiateResponse(credentialToken: credentialToken, challengeType: nil)
        let result = sut.validate(context: context, result: .success(initiateResponse))
        if case .success(credentialToken: credentialToken) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInitiateResponseIsInvalid_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let initiateResponse = MSALNativeAuthSignInInitiateResponse(credentialToken: nil, challengeType: nil)
        let result = sut.validate(context: context, result: .success(initiateResponse))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInitiateChallengeTypeIsRedirect_validationShouldReturnRedirectError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let initiateResponse = MSALNativeAuthSignInInitiateResponse(credentialToken: nil, challengeType: .redirect)
        let result = sut.validate(context: context, result: .success(initiateResponse))
        if case .error(.redirect) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInitiateChallengeTypeIsInvalid_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        var initiateResponse = MSALNativeAuthSignInInitiateResponse(credentialToken: nil, challengeType: .oob)
        var result = sut.validate(context: context, result: .success(initiateResponse))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        initiateResponse = MSALNativeAuthSignInInitiateResponse(credentialToken: nil, challengeType: .otp)
        result = sut.validate(context: context, result: .success(initiateResponse))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        initiateResponse = MSALNativeAuthSignInInitiateResponse(credentialToken: nil, challengeType: .password)
        result = sut.validate(context: context, result: .success(initiateResponse))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInitiateErrorResponse_errorShouldBeMappedCorrectly() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let result: MSALNativeAuthSignInInitiateValidatedResponse = sut.validate(context: context, result: .failure(MSALNativeAuthInternalError.generalError))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        checkRelationBetweenInitiateErrorResponseAndValidatedErrorResult(errorCode: .invalidRequest, expectedValidatedError: .invalidRequest)
        checkRelationBetweenInitiateErrorResponseAndValidatedErrorResult(errorCode: .invalidClient, expectedValidatedError: .invalidClient)
        checkRelationBetweenInitiateErrorResponseAndValidatedErrorResult(errorCode: .invalidGrant, expectedValidatedError: .userNotFound)
        checkRelationBetweenInitiateErrorResponseAndValidatedErrorResult(errorCode: .unsupportedChallengeType, expectedValidatedError: .unsupportedChallengeType)
    }
    
    // MARK: private methods
    
    private func checkRelationBetweenInitiateErrorResponseAndValidatedErrorResult(
        errorCode: MSALNativeAuthSignInInitiateOauth2ErrorCode,
        expectedValidatedError: MSALNativeAuthSignInInitiateValidatedErrorType) {
        let initiateError = MSALNativeAuthSignInInitiateResponseError(error: errorCode, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        let result: MSALNativeAuthSignInInitiateValidatedResponse = sut.validate(context: MSALNativeAuthRequestContext(correlationId: defaultUUID), result: .failure(initiateError))
        if case .error(expectedValidatedError) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    private func checkRelationBetweenErrorResponseAndValidatedErrorResult(
        errorCode: MSALNativeAuthSignInChallengeOauth2ErrorCode,
        expectedValidatedError: MSALNativeAuthSignInChallengeValidatedErrorType) {
        let challengeError = MSALNativeAuthSignInChallengeResponseError(error: errorCode, errorDescription: nil, errorURI: nil, innerErrors: nil)
        let result: MSALNativeAuthSignInChallengeValidatedResponse = sut.validate(context: MSALNativeAuthRequestContext(correlationId: defaultUUID), result: .failure(challengeError))
        if case .error(expectedValidatedError) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    private func checkRelationBetweenErrorResponseAndValidatedErrorResult(
        responseError: MSALNativeAuthSignInTokenResponseError,
        expectedError: MSALNativeAuthSignInTokenValidatedErrorType) {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthInternalError.generalError)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(responseError))
        if case .error(expectedError) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
}
