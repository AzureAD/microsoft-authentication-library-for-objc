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
    private let innerCorrelationId = UUID()
    private let withInnerCorrelationId = UUID()
    private let withoutInnerCorrelationId = UUID()

    private var innerErrorMock: NSError {
        let innerUserInfo: [String : Any] = [
            MSALInternalErrorCodeKey : -42002,
            MSALErrorDescriptionKey: "inner_user_info_error_description",
            MSALOAuthErrorKey: "inner_invalid_request",
            MSALCorrelationIDKey: innerCorrelationId.uuidString
        ]
        return NSError(domain: "HttpResponseErrorDomain", code: 401, userInfo: innerUserInfo)
    }

    private var errorWithInnerErrorMock: NSError {
        let userInfo: [String : Any] = [
            NSUnderlyingErrorKey : innerErrorMock ,
            MSALErrorDescriptionKey: "user_info_error_description",
            MSALOAuthErrorKey: "invalid_request",
            MSALCorrelationIDKey: withInnerCorrelationId.uuidString
        ]
        return NSError(domain: "HttpResponseErrorDomain", code: 501, userInfo: userInfo)
    }

    private var errorWithoutInnerErrorMock: NSError {
        let userInfo: [String : Any] = [
            MSALInternalErrorCodeKey : -3003,
            MSALErrorDescriptionKey: "user_info_error_description",
            MSALOAuthErrorKey: "invalid_request",
            MSALCorrelationIDKey: withoutInnerCorrelationId.uuidString
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
        let params = MSALSilentTokenParameters(scopes: accessToken.scopes?.array as? [String] ?? [], account: account)
        params.forceRefresh = false
        params.correlationId = contextCorrelationId

        silentTokenProviderFactoryMock.silentTokenProvider.result = silentTokenResult
        silentTokenProviderFactoryMock.silentTokenProvider.expectedParameters = params

        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedResult = MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                       scopes: accessToken.scopes?.array as? [String] ?? [],
                                                       expiresOn: accessToken.expiresOn)

        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedResult: expectedResult)
        delegate.expectedAccessToken = accessToken.accessToken
        delegate.expectedScopes = accessToken.scopes?.array as? [String] ?? []
        sut.getAccessToken(correlationId: contextCorrelationId, delegate: delegate)

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

        let params = MSALSilentTokenParameters(scopes: accessToken.scopes?.array as? [String] ?? [], account: account)
        params.forceRefresh = true
        params.correlationId = contextCorrelationId

        silentTokenProviderFactoryMock.silentTokenProvider.result = silentTokenResult
        silentTokenProviderFactoryMock.silentTokenProvider.expectedParameters = params

        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedResult = MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                       scopes: accessToken.scopes?.array as? [String] ?? [],
                                                       expiresOn: accessToken.expiresOn)

        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedResult: expectedResult)
        delegate.expectedAccessToken = accessToken.accessToken
        delegate.expectedScopes = accessToken.scopes?.array as? [String] ?? []
        sut.getAccessToken(scopes: accessToken.scopes?.array as? [String] ?? [],
                           forceRefresh: true,
                           correlationId: contextCorrelationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])

        XCTAssertEqual(delegate.expectedResult, expectedResult)
        XCTAssertEqual(sut.idToken, idToken)
        XCTAssertEqual(sut.account, account)
    }

    func test_getAccessTokenWithRedirectURI_thenInternalConfigIsCreatedCorrectly() async {
        let factory = MSALNativeAuthSilentTokenProviderFactoryConfigTester()
        factory.expectedBypassRedirectURIValidation = false
        let correlationId = UUID()
        let configuration = try! MSALNativeAuthConfiguration (
            clientId: DEFAULT_TEST_CLIENT_ID,
            authority: try! .init(
                url: URL(string: DEFAULT_TEST_AUTHORITY)!
            ),
            challengeTypes: [.redirect], redirectUri: "contoso.com"
        )
        sut = MSALNativeAuthUserAccountResult(
            account: account!,
            rawIdToken: "rawIdToken",
            configuration: configuration,
            cacheAccessor: cacheAccessorMock,
            silentTokenProviderFactory: factory
        )

        let expectedError = RetrieveAccessTokenError(type: .generalError, message: nil, correlationId: correlationId, errorCodes: [], errorUri: nil)
        factory.silentTokenProvider.error = expectedError
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(scopes: ["scope"],
                           forceRefresh: true,
                           correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_getAccessTokenWithoutRedirectURI_thenInternalConfigIsCreatedCorrectly() async {
        let factory = MSALNativeAuthSilentTokenProviderFactoryConfigTester()
        factory.expectedBypassRedirectURIValidation = true
        let correlationId = UUID()
        let configuration = try! MSALNativeAuthConfiguration (
            clientId: DEFAULT_TEST_CLIENT_ID,
            authority: try! .init(
                url: URL(string: DEFAULT_TEST_AUTHORITY)!
            ),
            challengeTypes: [.redirect],
            redirectUri: nil
        )
        sut = MSALNativeAuthUserAccountResult(
            account: account!,
            rawIdToken: "rawIdToken",
            configuration: configuration,
            cacheAccessor: cacheAccessorMock,
            silentTokenProviderFactory: factory
        )

        let expectedError = RetrieveAccessTokenError(type: .generalError, message: nil, correlationId: correlationId, errorCodes: [], errorUri: nil)
        factory.silentTokenProvider.error = expectedError
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(scopes: ["scope"],
                           forceRefresh: true,
                           correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    // MARK: - get access token using parameters tests

    func test_getAccessTokenUsingParameters_successfullyReturnsAccessToken() async {
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
        let params = MSALSilentTokenParameters(scopes: accessToken.scopes?.array as? [String] ?? [], account: account)
        params.forceRefresh = false
        params.correlationId = contextCorrelationId

        silentTokenProviderFactoryMock.silentTokenProvider.result = silentTokenResult
        silentTokenProviderFactoryMock.silentTokenProvider.expectedParameters = params

        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedResult = MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                       scopes: accessToken.scopes?.array as? [String] ?? [],
                                                       expiresOn: accessToken.expiresOn)

        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedResult: expectedResult)
        delegate.expectedAccessToken = accessToken.accessToken
        delegate.expectedScopes = accessToken.scopes?.array as? [String] ?? []
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: contextCorrelationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])

        XCTAssertEqual(delegate.expectedResult, expectedResult)
        XCTAssertEqual(sut.idToken, idToken)
        XCTAssertEqual(sut.account, account)
    }

    func test_getAccessTokenScopesUsingParametersAndForceRefresh_successfullyReturnsNewAccessToken() async {
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

        let params = MSALSilentTokenParameters(scopes: accessToken.scopes?.array as? [String] ?? [], account: account)
        params.forceRefresh = true
        params.correlationId = contextCorrelationId

        silentTokenProviderFactoryMock.silentTokenProvider.result = silentTokenResult
        silentTokenProviderFactoryMock.silentTokenProvider.expectedParameters = params

        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedResult = MSALNativeAuthTokenResult(accessToken: accessToken.accessToken,
                                                       scopes: accessToken.scopes?.array as? [String] ?? [],
                                                       expiresOn: accessToken.expiresOn)

        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedResult: expectedResult)
        delegate.expectedAccessToken = accessToken.accessToken
        delegate.expectedScopes = accessToken.scopes?.array as? [String] ?? []
        let parameters = MSALNativeAuthGetAccessTokenParameters(forceRefresh: true,
                                                                scopes: accessToken.scopes?.array as? [String] ?? [],
                                                                correlationId: contextCorrelationId)

        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])

        XCTAssertEqual(delegate.expectedResult, expectedResult)
        XCTAssertEqual(sut.idToken, idToken)
        XCTAssertEqual(sut.account, account)
    }

    func test_getAccessTokenUsingParametersWithRedirectURI_thenInternalConfigIsCreatedCorrectly() async {
        let factory = MSALNativeAuthSilentTokenProviderFactoryConfigTester()
        factory.expectedBypassRedirectURIValidation = false
        let correlationId = UUID()
        let configuration = try! MSALNativeAuthConfiguration (
            clientId: DEFAULT_TEST_CLIENT_ID,
            authority: try! .init(
                url: URL(string: DEFAULT_TEST_AUTHORITY)!
            ),
            challengeTypes: [.redirect], redirectUri: "contoso.com"
        )
        sut = MSALNativeAuthUserAccountResult(
            account: account!,
            rawIdToken: "rawIdToken",
            configuration: configuration,
            cacheAccessor: cacheAccessorMock,
            silentTokenProviderFactory: factory
        )

        let expectedError = RetrieveAccessTokenError(type: .generalError, message: nil, correlationId: correlationId, errorCodes: [], errorUri: nil)
        factory.silentTokenProvider.error = expectedError
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)

        let parameters = MSALNativeAuthGetAccessTokenParameters(forceRefresh: true,
                                                                scopes: ["scope"],
                                                                correlationId: correlationId)

        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_getAccessTokenUsingParametersWithoutRedirectURI_thenInternalConfigIsCreatedCorrectly() async {
        let factory = MSALNativeAuthSilentTokenProviderFactoryConfigTester()
        factory.expectedBypassRedirectURIValidation = true
        let correlationId = UUID()
        let configuration = try! MSALNativeAuthConfiguration (
            clientId: DEFAULT_TEST_CLIENT_ID,
            authority: try! .init(
                url: URL(string: DEFAULT_TEST_AUTHORITY)!
            ),
            challengeTypes: [.redirect],
            redirectUri: nil
        )
        sut = MSALNativeAuthUserAccountResult(
            account: account!,
            rawIdToken: "rawIdToken",
            configuration: configuration,
            cacheAccessor: cacheAccessorMock,
            silentTokenProviderFactory: factory
        )

        let expectedError = RetrieveAccessTokenError(type: .generalError, message: nil, correlationId: correlationId, errorCodes: [], errorUri: nil)
        factory.silentTokenProvider.error = expectedError
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(forceRefresh: true,
                                                                scopes: ["scope"],
                                                                correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    // MARK: - sign-out tests

    func test_signOut_successfullyCallsCacheAccessor() {
        sut.signOut()
        XCTAssertTrue(cacheAccessorMock.clearCacheWasCalled)
    }

    // MARK: - error tests

    func test_errorWithInnerError() async {
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithInnerErrorMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "inner_user_info_error_description", correlationId: innerCorrelationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithoutInnerError() async {
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithoutInnerErrorMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "user_info_error_description", correlationId: withoutInnerCorrelationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithoutInnerErrorWithoutDescription() async {
        let correlationId = UUID()
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithoutInnerErrorWithoutDescriptionMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: errorWithoutInnerErrorWithoutDescriptionMock.localizedDescription, correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithoutInnerErrorWithoutCorrelationId() async {
        let correlationId = UUID()
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithoutInnerErrorWithoutCorrelationIdMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "user_info_error_description", correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithValidExternalErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = [1, 2, 3]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: errorCodes, errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithInvalidExternalErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = ["123"]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithValidInnerErrorWithErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = [1, 2, 3]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let innerError = NSError(domain: "", code: 1, userInfo: userInfo)
        let error = NSError(domain: "", code: 1, userInfo: [NSUnderlyingErrorKey: innerError])

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: [1, 2, 3], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithInvalidInnerErrorWithErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = ["123"]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let innerError = NSError(domain: "", code: 1, userInfo: userInfo)
        let error = NSError(domain: "", code: 1, userInfo: [NSUnderlyingErrorKey: innerError])

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func test_errorWithMFARequiredErrorCode_ErrorMessageShouldContainsCorrectMessage() async {
        let correlationId = UUID()
        let errorCodes = [50076]
        let message = "message"
        let userInfo: [String : Any] = [
            MSALErrorDescriptionKey: message,
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)
        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: MSALNativeAuthErrorMessage.refreshTokenMFARequiredError + message, correlationId: correlationId, errorCodes: errorCodes, errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }
    
    func test_errorWithResetPasswordRequiredErrorCode_ErrorMessageShouldContainsCorrectMessage() async {
        let correlationId = UUID()
        let errorCodes = [50142]
        let message = "message"
        let userInfo: [String : Any] = [
            MSALErrorDescriptionKey: message,
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)
        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: MSALNativeAuthErrorMessage.passwordResetRequired + message, correlationId: correlationId, errorCodes: errorCodes, errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        sut.getAccessToken(correlationId: correlationId,
                           delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    // MARK: - error tests using parameters

    func testUsingParameters_errorWithInnerError() async {
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithInnerErrorMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "inner_user_info_error_description", correlationId: innerCorrelationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters()
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithoutInnerError() async {
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithoutInnerErrorMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "user_info_error_description", correlationId: withoutInnerCorrelationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters()
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithoutInnerErrorWithoutDescription() async {
        let correlationId = UUID()
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithoutInnerErrorWithoutDescriptionMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: errorWithoutInnerErrorWithoutDescriptionMock.localizedDescription, correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithoutInnerErrorWithoutCorrelationId() async {
        let correlationId = UUID()
        silentTokenProviderFactoryMock.silentTokenProvider.error = errorWithoutInnerErrorWithoutCorrelationIdMock
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "user_info_error_description", correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithValidExternalErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = [1, 2, 3]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: errorCodes, errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithInvalidExternalErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = ["123"]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithValidInnerErrorWithErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = [1, 2, 3]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let innerError = NSError(domain: "", code: 1, userInfo: userInfo)
        let error = NSError(domain: "", code: 1, userInfo: [NSUnderlyingErrorKey: innerError])

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: [1, 2, 3], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithInvalidInnerErrorWithErrorCodes_ParseShouldWorks() async {
        let correlationId = UUID()
        let errorCodes = ["123"]
        let userInfo: [String : Any] = [
            MSALSTSErrorCodesKey: errorCodes
        ]
        let innerError = NSError(domain: "", code: 1, userInfo: userInfo)
        let error = NSError(domain: "", code: 1, userInfo: [NSUnderlyingErrorKey: innerError])

        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: "The operation couldn’t be completed. ( error 1.)", correlationId: correlationId, errorCodes: [], errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithMFARequiredErrorCode_ErrorMessageShouldContainsCorrectMessage() async {
        let correlationId = UUID()
        let errorCodes = [50076]
        let message = "message"
        let userInfo: [String : Any] = [
            MSALErrorDescriptionKey: message,
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)
        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: MSALNativeAuthErrorMessage.refreshTokenMFARequiredError + message, correlationId: correlationId, errorCodes: errorCodes, errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }

    func testUsingParameters_errorWithResetPasswordRequiredErrorCode_ErrorMessageShouldContainsCorrectMessage() async {
        let correlationId = UUID()
        let errorCodes = [50142]
        let message = "message"
        let userInfo: [String : Any] = [
            MSALErrorDescriptionKey: message,
            MSALSTSErrorCodesKey: errorCodes
        ]
        let error = NSError(domain: "", code: 1, userInfo: userInfo)
        silentTokenProviderFactoryMock.silentTokenProvider.error = error
        let delegateExp = expectation(description: "delegateDispatcher delegate exp")
        let expectedError = RetrieveAccessTokenError(type: .generalError, message: MSALNativeAuthErrorMessage.passwordResetRequired + message, correlationId: correlationId, errorCodes: errorCodes, errorUri: nil)
        let delegate = CredentialsDelegateSpy(expectation: delegateExp, expectedError: expectedError)
        let parameters = MSALNativeAuthGetAccessTokenParameters(correlationId: correlationId)
        sut.getAccessToken(parameters: parameters, delegate: delegate)

        await fulfillment(of: [delegateExp])
    }
}
