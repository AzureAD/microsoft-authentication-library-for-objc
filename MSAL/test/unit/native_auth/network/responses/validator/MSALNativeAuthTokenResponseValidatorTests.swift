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
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!
    private var tokenResponse = MSIDTokenResponse()
    private var factory: MSALNativeAuthResultFactoryMock!
    private var context: MSALNativeAuthRequestContext!

    private let accountIdentifier = MSIDAccountIdentifier(displayableId: "aDisplayableId", homeAccountId: "home.account.id")!
    private let configuration = MSIDConfiguration()


    override func setUpWithError() throws {
        try super.setUpWithError()

        context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        factory =  MSALNativeAuthResultFactoryMock()
        sut = MSALNativeAuthTokenResponseValidator(factory: factory, msidValidator: MSIDDefaultTokenResponseValidator())
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
        let refreshToken = MSIDRefreshToken()
        refreshToken.familyId = "familyId"
        refreshToken.refreshToken = "refreshToken"
        let tokenResponse = MSIDCIAMTokenResponse()
        factory.mockMakeUserAccountResult(userAccountResult)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .success(tokenResponse))
        if case .success(tokenResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenInvalidErrorTokenResponse_anErrorIsReturned() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(MSALNativeAuthInternalError.headerNotSerialized))
        if case .error(.invalidServerResponse) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_invalidGrantTokenResponse_isTranslatedToProperErrorResult() {
        invalidResponseIsTranslatedToProperErrorResult(error: .invalidGrant)
    }
    
    func test_invalidRequestTokenResponse_isTranslatedToProperErrorResult() {
        invalidResponseIsTranslatedToProperErrorResult(error: .invalidRequest)
    }

    func test_invalidGrantTokenResponse_withEmptyErrorCodesArray_isProperlyHandled() {
        invalidResponseWithEmptyErrorCodesArrayIsProperlyHandled(errorCode: .invalidGrant)
    }
    
    func test_invalidRequestTokenResponse_withEmptyErrorCodesArray_isProperlyHandled() {
        invalidResponseWithEmptyErrorCodesArrayIsProperlyHandled(errorCode: .invalidRequest)
    }

    func test_invalidGrantTokenResponse_withSeveralUnknownErrorCodes_isProperlyHandled() {
        invalidResponseWithSeveralUnknownErrorCodesIsProperlyHandled(error: .invalidGrant)
    }
    
    func test_invalidRequestTokenResponse_withSeveralUnknownErrorCodes_isProperlyHandled() {
        invalidResponseWithSeveralUnknownErrorCodesIsProperlyHandled(error: .invalidRequest)
    }

    func test_invalidGrantTokenResponse_withKnownError_andSeveralUnknownErrorCodes_isProperlyHandled() {
        invalidResponseWithKnownErrorAndSeveralUnknownErrorCodesIsProperlyHandled(errorCode: .invalidGrant)
    }
    
    func test_invalidRequestTokenResponse_withKnownError_andSeveralUnknownErrorCodes_isProperlyHandled() {
        invalidResponseWithKnownErrorAndSeveralUnknownErrorCodesIsProperlyHandled(errorCode: .invalidRequest)
    }

    func test_invalidGrantTokenResponse_withUnknownErrorCode_andKnownErrorCodes_isProperlyHandled() {
        invalidResponseWithUnknownErrorCodeAndKnownErrorCodesIsProperlyHandled(errorCode: .invalidGrant)
    }
    
    func test_invalidRequestTokenResponse_withUnknownErrorCode_andKnownErrorCodes_isProperlyHandled() {
        invalidResponseWithUnknownErrorCodeAndKnownErrorCodesIsProperlyHandled(errorCode: .invalidRequest)
    }

    func test_errorTokenResponse_isTranslatedToProperErrorResult() {
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


    // MARK: - ValidateAccount tests

    func test_validateAccount_successfully() throws {
        var accountValid: Bool?
         XCTAssertNoThrow(accountValid = try sut.validateAccount(with: MSIDTokenResult(), context: context, accountIdentifier: accountIdentifier))
        XCTAssertTrue(accountValid!)
    }

    func test_validateAccount_error() throws {
        accountIdentifier.uid = "differentUid"
        XCTAssertThrowsError(try sut.validateAccount(with: MSIDTokenResult(), context: context, accountIdentifier: accountIdentifier))
    }

    private func checkRelationBetweenErrorResponseAndValidatedErrorResult(
        responseError: MSALNativeAuthTokenResponseError,
        expectedError: MSALNativeAuthTokenValidatedErrorType) {
            let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
            let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(responseError))
            if case .error(expectedError) = result {} else {
                XCTFail("Unexpected result: \(result)")
            }
    }
    
    private func invalidResponseIsTranslatedToProperErrorResult(error: MSALNativeAuthTokenOauth2ErrorCode) {
        let userNotFoundError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: userNotFoundError, expectedError: .userNotFound)
        let invalidPasswordError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.invalidCredentials.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidPasswordError, expectedError: .invalidPassword)
        let invalidOTPCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.invalidOTP.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: invalidOTPCodeError, expectedError: .invalidOOBCode)
        let genericErrorCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: genericErrorCodeError, expectedError: .generalError)
        let strongAuthRequiredError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.strongAuthRequired.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: strongAuthRequiredError, expectedError: .strongAuthRequired)
        let incorrectOTPCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.incorrectOTP.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: incorrectOTPCodeError, expectedError: .invalidOOBCode)
        let otpNoCacheEntryCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.OTPNoCacheEntryForUser.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: otpNoCacheEntryCodeError, expectedError: .invalidOOBCode)
        let otpCacheCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.OTPCacheError.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: otpCacheCodeError, expectedError: .invalidOOBCode)
        let expiredOTPCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.expiredOTP.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: expiredOTPCodeError, expectedError: .invalidOOBCode)
        let cannotGenerateOTPCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.cannotGenerateOTP.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: cannotGenerateOTPCodeError, expectedError: .invalidOOBCode)
        let userNotHaveAPasswordCodeError = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes.userNotHaveAPassword.rawValue], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: userNotHaveAPasswordCodeError, expectedError: .generalError)
    }

    func invalidResponseWithEmptyErrorCodesArrayIsProperlyHandled(errorCode: MSALNativeAuthTokenOauth2ErrorCode) {
        let error = MSALNativeAuthTokenResponseError(error: errorCode, errorDescription: nil, errorCodes: [], errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .generalError)
    }

    func invalidResponseWithSeveralUnknownErrorCodesIsProperlyHandled(error: MSALNativeAuthTokenOauth2ErrorCode) {
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        let errorCodes: [Int] = [unknownErrorCode1, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: error, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .generalError)
    }

    func invalidResponseWithKnownErrorAndSeveralUnknownErrorCodesIsProperlyHandled(errorCode: MSALNativeAuthTokenOauth2ErrorCode) {
        let knownErrorCode = MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        let errorCodes: [Int] = [knownErrorCode, unknownErrorCode1, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: errorCode, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .userNotFound)
    }

    func invalidResponseWithUnknownErrorCodeAndKnownErrorCodesIsProperlyHandled(errorCode: MSALNativeAuthTokenOauth2ErrorCode) {
        let knownErrorCode = MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        // We only check for the first error, if it's unknown, we return .generalError

        let errorCodes: [Int] = [unknownErrorCode1, knownErrorCode, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: errorCode, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, credentialToken: nil)
        checkRelationBetweenErrorResponseAndValidatedErrorResult(responseError: error, expectedError: .generalError)
    }
}
