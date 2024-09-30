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

import Foundation

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private
@_implementationOnly import MSAL_Unit_Test_Private

class MSALNativeAuthUserAccountResultTests: XCTestCase {
    var sut: MSALNativeAuthUserAccountResult!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var silentTokenProviderFactoryMock: MSALNativeAuthSilentTokenProviderFactoryMock!
    private var account: MSALAccount!
    private let innerCorrelationId = UUID().uuidString
    private let withInnerCorrelationId = UUID().uuidString
    private let withoutInnerCorrelationId = UUID().uuidString
    
    private var innerErrorMock: NSError {
        let innerUserInfo: [String : Any] = [
            MSALInternalErrorCodeKey : -42002,
            MSALErrorDescriptionKey: "inner_user_info_error_description",
            MSALOAuthErrorKey: "inner_invalid_request",
            MSALCorrelationIDKey: innerCorrelationId
        ]
        return NSError(domain: "HttpResponseErrorDomain", code: 401, userInfo: innerUserInfo)
    }
    
    private var errorWithInnerErrorMock: NSError {
        let userInfo: [String : Any] = [
            NSUnderlyingErrorKey : innerErrorMock ,
            MSALErrorDescriptionKey: "user_info_error_description",
            MSALOAuthErrorKey: "invalid_request",
            MSALCorrelationIDKey: withInnerCorrelationId
        ]
        return NSError(domain: "HttpResponseErrorDomain", code: 501, userInfo: userInfo)
    }
    
    private var errorWithoutInnerErrorMock: NSError {
        let userInfo: [String : Any] = [
            MSALInternalErrorCodeKey : -3003,
            MSALErrorDescriptionKey: "user_info_error_description",
            MSALOAuthErrorKey: "invalid_request",
            MSALCorrelationIDKey: withoutInnerCorrelationId
        ]
        return NSError(domain: "HttpResponseErrorDomain", code: 601, userInfo: userInfo)
    }
    
    private var errorWithoutInnerErrorWithoutDescriptionMock: NSError {
        let userInfo: [String : Any] = [
            MSALOAuthErrorKey: "invalid_request",
            MSALCorrelationIDKey: withoutInnerCorrelationId
        ]
        return NSError(domain: "HttpResponseErrorDomain", code: 701, userInfo: userInfo)
    }
    
    private var errorWithoutInnerErrorWithoutCorrelationIdMock: NSError {
        let userInfo: [String : Any] = [
            MSALOAuthErrorKey: "invalid_request",
            MSALErrorDescriptionKey: "user_info_error_description"
        ]
        return NSError(domain: "HttpResponseErrorDomain", code: 701, userInfo: userInfo)
    }

    override func setUpWithError() throws {

        account = MSALNativeAuthUserAccountResultStub.account
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "accessToken"
        let refreshToken = MSIDRefreshToken()
        refreshToken.refreshToken = "refreshToken"
        let rawIdToken = "rawIdToken"

        cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        silentTokenProviderFactoryMock = MSALNativeAuthSilentTokenProviderFactoryMock()

        sut = MSALNativeAuthUserAccountResult(
            account: account!,
            rawIdToken: rawIdToken,
            configuration: MSALNativeAuthConfigStubs.configuration,
            cacheAccessor: cacheAccessorMock,
            silentTokenProviderFactory: silentTokenProviderFactoryMock
        )
        try super.setUpWithError()
    }

    // MARK: - get access token tests

    func test_getAccessToken_successfullyReturnsAccessToken() async {
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "accessToken"
        accessToken.scopes = ["scope1", "scope2"]
        let contextCorrelationId = UUID()
        let homeAccountId = MSALAccountId(accountIdentifier: "fedcba98-7654-3210-0000-000000000000.00000000-0000-1234-5678-90abcdefffff", objectId: "", tenantId: "https://contoso.com/tfp/tenantName")
        let idToken = "newIdToken"
        let account = MSALAccount(username: "1234567890", homeAccountId: homeAccountId, environment: "contoso.com", tenantProfiles: [])!
        let silentTokenResult = MSALNativeAuthSilentTokenResult(accessTokenResult: MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                                                                             scopes: accessToken.scopes?.array as? [String] ?? [],
                                                                                                             expiresOn: nil),
                                                                rawIdToken: idToken,
                                                                account: account,
                                                                correlationId: contextCorrelationId)
        silentTokenProviderFactoryMock.silentTokenProvider.result = silentTokenResult

        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedResult = MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                       scopes: accessToken.scopes?.array as? [String] ?? [],
                                                       expiresOn: accessToken.expiresOn)

        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedResult: expectedResult)
        delegate.expectedAccessToken = accessToken.accessToken
        delegate.expectedScopes = accessToken.scopes?.array as? [String] ?? []
        sut.getAccessToken(delegate: delegate)

        await fulfillment(of: [delegateExp])

        XCTAssertEqual(delegate.expectedResult, expectedResult)
        XCTAssertEqual(sut.idToken, idToken)
        XCTAssertEqual(sut.account, account)
    }

    func test_getAccessTokenScopesAndForceRefresh_successfullyReturnsNewAccessToken() async {
        let accessToken = MSIDAccessToken()
        accessToken.accessToken = "newAccessToken"
        accessToken.scopes = ["scope1", "scope2"]
        let contextCorrelationId = UUID()
        let homeAccountId = MSALAccountId(accountIdentifier: "fedcba98-7654-3210-0000-000000000000.00000000-0000-1234-5678-90abcdefffff", objectId: "", tenantId: "https://contoso.com/tfp/tenantName")
        let idToken = "newIdToken"
        let account = MSALAccount(username: "1234567890", homeAccountId: homeAccountId, environment: "contoso.com", tenantProfiles: [])!
        let silentTokenResult = MSALNativeAuthSilentTokenResult(accessTokenResult: MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                                                                             scopes: accessToken.scopes?.array as? [String] ?? [],
                                                                                                             expiresOn: nil),
                                                                rawIdToken: idToken,
                                                                account: account,
                                                                correlationId: contextCorrelationId)
        silentTokenProviderFactoryMock.silentTokenProvider.result = silentTokenResult

        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedResult = MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                       scopes: accessToken.scopes?.array as? [String] ?? [],
                                                       expiresOn: accessToken.expiresOn)

        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedResult: expectedResult)
        delegate.expectedAccessToken = accessToken.accessToken
        delegate.expectedScopes = accessToken.scopes?.array as? [String] ?? []
        sut.getAccessToken(scopes: accessToken.scopes?.array as? [String] ?? [],
                           forceRefresh: true,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])

        XCTAssertEqual(delegate.expectedResult, expectedResult)
        XCTAssertEqual(sut.idToken, idToken)
        XCTAssertEqual(sut.account, account)
    }

    func test_getAccessToken_successfullyReturnsError() async {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithInnerErrorMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = sut.createRetrieveAccessTokenError(error: errorWithInnerErrorMock,
                                                               context: context)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(delegate: delegate)

        await fulfillment(of: [delegateExp])
    }


    // MARK: - sign-out tests

    func test_signOut_successfullyCallsCacheAccessor() {
        sut.signOut()
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
    }
    
    // MARK: - error tests
    
    func test_errorWithInnerError() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        
        let result = sut.createRetrieveAccessTokenError(error: errorWithInnerErrorMock,
                                                        context: context)
        
        XCTAssertEqual(result.errorDescription, "inner_user_info_error_description")
        XCTAssertEqual(result.errorCodes, [])
        XCTAssertEqual(result.correlationId.uuidString, innerCorrelationId)
    }
    
    func test_errorWithoutInnerError() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        
        let result = sut.createRetrieveAccessTokenError(error: errorWithoutInnerErrorMock,
                                                        context: context)
        
        XCTAssertEqual(result.errorDescription, "user_info_error_description")
        XCTAssertEqual(result.errorCodes, [])
        XCTAssertEqual(result.correlationId.uuidString, withoutInnerCorrelationId)
    }
    
    func test_errorWithoutInnerErrorWithoutDescription() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        
        let result = sut.createRetrieveAccessTokenError(error: errorWithoutInnerErrorWithoutDescriptionMock,
                                                        context: context)
        
        XCTAssertEqual(result.errorDescription, errorWithoutInnerErrorWithoutDescriptionMock.localizedDescription)
        XCTAssertEqual(result.errorCodes, [])
        XCTAssertEqual(result.correlationId.uuidString, withoutInnerCorrelationId)
    }
    
    func test_errorWithoutInnerErrorWithoutCorrelationId() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        
        let result = sut.createRetrieveAccessTokenError(error: errorWithoutInnerErrorWithoutCorrelationIdMock,
                                                        context: context)
        
        XCTAssertEqual(result.errorDescription, "user_info_error_description")
        XCTAssertEqual(result.errorCodes, [])
        XCTAssertEqual(result.correlationId, contextCorrelationId)
    }
    
    func test_errorWithValidExternalErrorCodes_ParseShouldWorks() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        let errorCodes = [1, 2, 3]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)
        
        let result = sut.createRetrieveAccessTokenError(error: error, context: context)
        
        XCTAssertEqual(result.errorCodes, errorCodes)
    }
    
    func test_errorWithInvalidExternalErrorCodes_ParseShouldWorks() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        let errorCodes = ["123"]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)
        
        let result = sut.createRetrieveAccessTokenError(error: error, context: context)
        
        XCTAssertEqual(result.errorCodes, [])
    }
    
    func test_errorWithValidInnerErrorWithErrorCodes_ParseShouldWorks() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        let errorCodes = [1, 2, 3]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let innerError = NSError(domain: "", code: 1, userInfo: userInfo)
        let error = NSError(domain: "", code: 1, userInfo: [NSUnderlyingErrorKey: innerError])
        
        let result = sut.createRetrieveAccessTokenError(error: error, context: context)
        
        XCTAssertEqual(result.errorCodes, errorCodes)
    }
    
    func test_errorWithInvalidInnerErrorWithErrorCodes_ParseShouldWorks() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        let errorCodes = ["123"]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let innerError = NSError(domain: "", code: 1, userInfo: userInfo)
        let error = NSError(domain: "", code: 1, userInfo: [NSUnderlyingErrorKey: innerError])
        
        let result = sut.createRetrieveAccessTokenError(error: error, context: context)
        
        XCTAssertEqual(result.errorCodes, [])
    }
    
    func test_errorWithMFARequiredErrorCode_ErrorMessageShouldContainsCorrectMessage() {
        let contextCorrelationId = UUID()
        let context = MSALNativeAuthRequestContext(correlationId: contextCorrelationId)
        let errorCodes = [50076]
        let message = "message"
        let userInfo: [String : Any] = [
            MSALErrorDescriptionKey: message,
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)
        
        let result = sut.createRetrieveAccessTokenError(error: error, context: context)
        
        XCTAssertEqual(result.errorCodes, errorCodes)
        XCTAssertEqual(result.errorDescription, MSALNativeAuthErrorMessage.refreshTokenMFARequiredError + message)
    }
}
