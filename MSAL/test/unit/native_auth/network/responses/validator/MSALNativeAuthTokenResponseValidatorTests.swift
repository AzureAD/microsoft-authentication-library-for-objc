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
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = nil
        let refreshToken = MSIDRefreshToken()
        refreshToken.refreshToken = nil
        let rawIdToken = "rawIdToken"
        let authTokens = MSALNativeAuthTokens(accessToken: accessToken,
                                              refreshToken: refreshToken,
                                              rawIdToken: rawIdToken)
        let userAccountResult = MSALNativeAuthUserAccountResult(account:
                                                                    MSALNativeAuthUserAccountResultStub.account,
                                                                authTokens:authTokens,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
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
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_invalidGrantTokenResponse_withSeveralUnknownErrorCodes_isProperlyHandled() {
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        let errorCodes: [Int] = [unknownErrorCode1, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: .invalidGrant, subError: nil, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, continuationToken: nil)
        
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
        
        guard case .error(let innerError) = result else {
            return XCTFail("Unexpected response")
        }
        
        if case .generalError = innerError {} else {
            XCTFail("Unexpected Error")
        }
    }
    
    func test_invalidClient_isProperlyHandled() {
        let error = MSALNativeAuthTokenResponseError(error: .invalidClient, subError: nil, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, continuationToken: nil)

        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
        
        guard case .error(let innerError) = result else {
            return XCTFail("Unexpected response")
        }
        
        if case .unauthorizedClient(error) = innerError {} else {
            XCTFail("Unexpected Error")
        }
    }
    
    func test_unauthorizedClient_isProperlyHandled() {
        let error = MSALNativeAuthTokenResponseError(error: .unauthorizedClient, subError: nil, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, continuationToken: nil)

        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
        
        guard case .error(let innerError) = result else {
            return XCTFail("Unexpected response")
        }
        
        if case .unauthorizedClient(error) = innerError {} else {
            XCTFail("Unexpected Error")
        }
    }
    

    func test_invalidGrantTokenResponse_withKnownError_andSeveralUnknownErrorCodes_isProperlyHandled() {
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        var errorCodes: [Int] = [MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue, unknownErrorCode1, unknownErrorCode2]

        guard case .userNotFound(createError(errorCodes)) = checkErrorCodes() else {
            return XCTFail("Unexpected Error")
        }
        errorCodes = [MSALNativeAuthESTSApiErrorCodes.strongAuthRequired.rawValue, unknownErrorCode1, unknownErrorCode2]
        guard case .strongAuthRequired(createError(errorCodes)) = checkErrorCodes() else {
            return XCTFail("Unexpected Error")
        }
        errorCodes = [MSALNativeAuthESTSApiErrorCodes.strongAuthRequired.rawValue, unknownErrorCode1, unknownErrorCode2]
        guard case .strongAuthRequired(createError(errorCodes)) = checkErrorCodes() else {
            return XCTFail("Unexpected Error")
        }
        errorCodes = [MSALNativeAuthESTSApiErrorCodes.invalidCredentials.rawValue, unknownErrorCode1, unknownErrorCode2]
        guard case .invalidPassword(createError(errorCodes)) = checkErrorCodes() else {
            return XCTFail("Unexpected Error")
        }
        errorCodes = [MSALNativeAuthESTSApiErrorCodes.userNotHaveAPassword.rawValue, unknownErrorCode1, unknownErrorCode2]
        guard case .generalError = checkErrorCodes() else {
            return XCTFail("Unexpected Error")
        }
        func checkErrorCodes() -> MSALNativeAuthTokenValidatedErrorType? {
            let error = MSALNativeAuthTokenResponseError(error: .invalidGrant, subError: nil, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, continuationToken: nil)
            let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
            
            guard case .error(let innerError) = result else {
                return nil
            }
            return innerError
        }
        func createError(_ errorCodes: [Int]) -> MSALNativeAuthTokenResponseError {
            MSALNativeAuthTokenResponseError(error: .invalidGrant, subError: nil, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, continuationToken: nil)
        }
    }

    func test_invalidGrantTokenResponse_withUnknownErrorCode_andKnownErrorCodes_isProperlyHandled() {
        let knownErrorCode = MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue
        let unknownErrorCode1 = Int.max
        let unknownErrorCode2 = unknownErrorCode1 - 1

        // We only check for the first error, if it's unknown, we return .generalError

        let errorCodes: [Int] = [unknownErrorCode1, knownErrorCode, unknownErrorCode2]

        let error = MSALNativeAuthTokenResponseError(error: .invalidGrant, subError: nil, errorDescription: nil, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, continuationToken: nil)

        let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
        
        guard case .error(let innerError) = result else {
            return XCTFail("Unexpected response")
        }
        
        if case .generalError = innerError {} else {
            XCTFail("Unexpected Error")
        }
    }
    
    func test_invalidRequesTokenResponse_withGenericErrorCode_isTranslatedToGeneralError() {
        let description = "description"
        let unknownErrorCode1 = Int.max
        var errorCodes: [Int] = [unknownErrorCode1]
        checkErrorCodes()
        errorCodes = [MSALNativeAuthESTSApiErrorCodes.strongAuthRequired.rawValue]
        checkErrorCodes()
        errorCodes = [MSALNativeAuthESTSApiErrorCodes.userNotFound.rawValue]
        checkErrorCodes()
        func checkErrorCodes() {
            let error = MSALNativeAuthTokenResponseError(error: .invalidRequest, subError: nil, errorDescription: description, errorCodes: errorCodes, errorURI: nil, innerErrors: nil, continuationToken: nil)

            let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
            let result = sut.validate(context: context, msidConfiguration: MSALNativeAuthConfigStubs.msidConfiguration, result: .failure(error))
            
            guard case .error(let innerError) = result else {
                return XCTFail("Unexpected response")
            }
            
            guard case .invalidRequest(error) = innerError else {
                return XCTFail("Unexpected Error")
            }
        }
    }
}
