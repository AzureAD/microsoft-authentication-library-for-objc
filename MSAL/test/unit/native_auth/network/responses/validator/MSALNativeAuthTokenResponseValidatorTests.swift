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

final class MSALNativeAuthTokenResponseValidatorTest: MSALNativeAuthTestCase {

    private let baseUrl = URL(string: DEFAULT_TEST_AUTHORITY)!
    private var sut: MSALNativeAuthTokenResponseValidator!
    private var responseHandler: MSALNativeAuthTokenResponseHandlerMock!
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private var tokenResponse = MSIDTokenResponse()
    private var factory: MSALNativeAuthResultFactoryMock!

    override func setUpWithError() throws {
        try super.setUpWithError()

        responseHandler = MSALNativeAuthTokenResponseHandlerMock()
        factory =  MSALNativeAuthResultFactoryMock()
        sut = MSALNativeAuthTokenResponseValidator(tokenResponseHandler: responseHandler, factory: factory)
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
    }
    
    // MARK: token API tests

    func test_whenValidTokenResponse_validationIsSuccessful() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let userAccountResult = MSALNativeAuthUserAccountResult(account:
                                                                    MSALNativeAuthUserAccountResultStub.account,
                                                                authTokens: MSALNativeAuthTokens(accessToken: nil,
                                                                                                 refreshToken: nil,
                                                                                                 rawIdToken: nil),
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        let tokenResult = MSIDTokenResult()
        let refreshToken = MSIDRefreshToken()
        refreshToken.familyId = "familyId"
        refreshToken.refreshToken = "refreshToken"
        tokenResult.refreshToken = refreshToken
        let tokenResponse = MSIDCIAMTokenResponse()
        responseHandler.mockHandleTokenFunc(result: tokenResult)
        factory.mockMakeUserAccountResult(userAccountResult)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .success(tokenResponse))
        if case .success(userAccountResult, tokenResult, tokenResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenInvalidTokenResponse_anErrorIsReturned() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthInternalError.generalError)
        responseHandler.expectedContext = context
        responseHandler.expectedValidateAccount = true
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .success(MSIDCIAMTokenResponse()))
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
        let userNotFoundError = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: userNotFoundError, expectedError: .userNotFound)
        let invalidPasswordError = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.invalidCredentials.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidPasswordError, expectedError: .invalidPassword)
        let invalidOTPCodeError = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.invalidOTP.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidOTPCodeError, expectedError: .invalidOOBCode)
        let genericErrorCodeError = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: genericErrorCodeError, expectedError: .generalError)
        let strongAuthRequiredError = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.strongAuthRequired.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: strongAuthRequiredError, expectedError: .strongAuthRequired)
    }

    func test_invalidGrantTokenResponse_withEmptyErrorCodesArray_isProperlyHandled() {
        let error = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: [], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .generalError)
    }

    func test_invalidGrantTokenResponse_withSeveralUnknownErrorCodes_isProperlyHandled() {
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        let errorCodes: [Int] = [unknownErrorCode1, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .generalError)
    }

    func test_invalidGrantTokenResponse_withKnownError_andSeveralUnknownErrorCodes_isProperlyHandled() {
        let knownErrorCode = MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        let errorCodes: [Int] = [knownErrorCode, unknownErrorCode1, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .userNotFound)
    }

    func test_invalidGrantTokenResponse_withUnknownErrorCode_andKnownErrorCodes_isProperlyHandled() {
        let knownErrorCode = MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        // We only check for the first error, if it's unknown, we return .generalError

        let errorCodes: [Int] = [unknownErrorCode1, knownErrorCode, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: .invalidGrant, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .generalError)
    }

    func test_errorTokenResponse_isTranslatedToProperErrorResult() {
        let invalidReqError = MSALNativeAuthTokenResponseError(error: .invalidRequest, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidReqError, expectedError: .invalidRequest)
        let invalidClientError = MSALNativeAuthTokenResponseError(error: .invalidClient, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidClientError, expectedError: .invalidClient)
        let expiredTokenError = MSALNativeAuthTokenResponseError(error: .expiredToken, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: expiredTokenError, expectedError: .expiredToken)
        let expiredRefreshTokenError = MSALNativeAuthTokenResponseError(error: .expiredRefreshToken, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: expiredRefreshTokenError, expectedError: .expiredRefreshToken)
        let unsupportedChallengeTypeError = MSALNativeAuthTokenResponseError(error: .unsupportedChallengeType, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: unsupportedChallengeTypeError, expectedError: .unsupportedChallengeType)
        let invalidScopeError = MSALNativeAuthTokenResponseError(error: .invalidScope, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidScopeError, expectedError: .invalidScope)
        let authPendingError = MSALNativeAuthTokenResponseError(error: .authorizationPending, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: authPendingError, expectedError: .authorizationPending)
        let slowDownError = MSALNativeAuthTokenResponseError(error: .slowDown, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: slowDownError, expectedError: .slowDown)
    }

    private func checkRelationBetweenErrorResponseAndValidatedErrorResult(
        responseError: MSALNativeAuthTokenResponseError,
        expectedError: MSALNativeAuthTokenValidatedErrorType) {
            let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
            responseHandler.mockHandleTokenFunc(throwingError: MSALNativeAuthInternalError.generalError)
            let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(responseError))
            if case .error(expectedError) = result {} else {
                XCTFail("Unexpected result: \(result)")
            }
        }
}
