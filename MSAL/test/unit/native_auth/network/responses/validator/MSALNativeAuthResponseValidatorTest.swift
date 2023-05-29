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

final class MSALNativeAuthResponseValidatorTest: MSALNativeAuthTestCase {
    
    private var sut: MSALNativeAuthSignInResponseValidator!
    private var responseHandler: MSALNativeAuthResponseHandlerMock!
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private var tokenResponse = MSIDTokenResponse()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        responseHandler = MSALNativeAuthResponseHandlerMock()
        sut = MSALNativeAuthSignInResponseValidator(responseHandler: responseHandler)
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
    }
    
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
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthError.generalError)
        responseHandler.expectedContext = context
        responseHandler.expectedValidateAccount = true
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .success(MSIDAADTokenResponse()))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInvalidErrorTokenResponse_anErrorIsReturned() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthError.generalError)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(MSALNativeAuthError.headerNotSerialized))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_credentialReqResponseDoesNotContainCredentialToken_anErrorIsReturned() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthError.generalError)
        let error = MSALNativeAuthSignInTokenResponseError(error: .credentialRequired, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_credentialReqResponseContainCredentialToken_credentialRequiredStateIsReturned() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthError.generalError)
        let credentialToken = "credentialToken"
        let error = MSALNativeAuthSignInTokenResponseError(error: .credentialRequired, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: credentialToken)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
        if case .credentialRequired(credentialToken) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_invalidGrantTokenResponse_isTranslatedToProperErrorResult() {
        let userNotFoundError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.userNotFound], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: userNotFoundError, expectedError: .userNotFound)
        let invalidPasswordError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.invalidCredentials], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidPasswordError, expectedError: .invalidPassword)
        let genericErrorCodeError = MSALNativeAuthSignInTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [.invalidOTP], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: genericErrorCodeError, expectedError: .generalError)
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
    
    private func checkRelationBetweenErrorResponseAndValidatedErrorResult(
        responseError: MSALNativeAuthSignInTokenResponseError,
        expectedError: MSALNativeAuthSignInTokenValidatedErrorType) {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthError.generalError)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(responseError))
        if case .error(expectedError) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
}
