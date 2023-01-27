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

final class MSALNativeAuthCacheAccessorTest: XCTestCase {
    private let cacheAccessor = MSALNativeAuthCacheAccessor()
    private lazy var parameters = getParameters()
    private lazy var contextStub = ContextStub()
    
    override func tearDownWithError() throws {
        try cacheAccessor.clearCache(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub)
    }
    
    // MARK: happy cases
    
    func testTokensStore_whenAllInfoPresent_shouldSaveTokensCorrectly() {
        let tokenResponse = getTokenResponse()
        let parameters = getParameters()
        XCTAssertNoThrow(try cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub))
        var tokens: MSALNativeAuthTokens? = nil
        
        XCTAssertNoThrow(tokens = try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(tokens?.accessToken?.accessToken, tokenResponse.accessToken)
        XCTAssertEqual(tokens?.refreshToken?.refreshToken, tokenResponse.refreshToken)
        XCTAssertEqual(tokens?.idToken?.rawIdToken, tokenResponse.idToken)
    }
    
    func testUpdateTokensAndAccount_whenAllInfoPresent_shouldUpdateDataCorrectly() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub))
        var tokens: MSALNativeAuthTokens? = nil
        
        XCTAssertNoThrow(tokens = try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(tokens?.accessToken?.accessToken, tokenResponse.accessToken)
        XCTAssertEqual(tokens?.refreshToken?.refreshToken, tokenResponse.refreshToken)
        XCTAssertEqual(tokens?.idToken?.rawIdToken, tokenResponse.idToken)
        
        let newAccessToken = "newAccessToken"
        let newRefreshToken = "newRefreshToken"
        let newIdToken = "newIdToken"
        tokenResponse.accessToken = newAccessToken
        tokenResponse.refreshToken = newRefreshToken
        tokenResponse.idToken = newIdToken
        XCTAssertNoThrow(try cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub))

        XCTAssertNoThrow(tokens = try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(tokens?.accessToken?.accessToken, newAccessToken)
        XCTAssertEqual(tokens?.refreshToken?.refreshToken, newRefreshToken)
        XCTAssertEqual(tokens?.idToken?.rawIdToken, newIdToken)
    }
    
    func testAccountStore_whenAllInfoPresent_shouldStoreAccountCorrectly() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub))

        var account: MSIDAccount? = nil
        XCTAssertNoThrow(account = try cacheAccessor.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: contextStub))
        XCTAssertEqual(account?.accountIdentifier.homeAccountId, parameters.accountIdentifier.homeAccountId)
        // this information was took from the TokenResponse.IDToken (JWT format)
        XCTAssertEqual(account?.accountIdentifier.displayableId, "1234567890")
        XCTAssertEqual(account?.accountIdentifier.utid, parameters.accountIdentifier.utid)
        XCTAssertEqual(account?.accountIdentifier.uid, parameters.accountIdentifier.uid)
        XCTAssertEqual(account?.clientInfo, tokenResponse.clientInfo)
    }
    
    func testTokensDeletion_whenAllInfoPresent_shouldRemoveTokensCorrectly() {
        var tokens: MSALNativeAuthTokens? = nil
        XCTAssertThrowsError(tokens = try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertNil(tokens)
        
        let tokenResponse = getTokenResponse()
        try? cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub)
        
        tokens = try? cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub)
        XCTAssertNotNil(tokens)
        
        XCTAssertNoThrow(try cacheAccessor.removeTokens(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub))
        
        tokens = try? cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub)
        XCTAssertNil(tokens)
    }
    
    func testClearCache_whenAllInfoPresent_shouldRemoveTokensAndAccountCorrectly() {
        var tokens: MSALNativeAuthTokens? = nil
        var account: MSIDAccount? = nil
        XCTAssertThrowsError(tokens = try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertThrowsError(account = try cacheAccessor.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: contextStub))
        XCTAssertNil(tokens)
        XCTAssertNil(account)
        
        let tokenResponse = getTokenResponse()
        try? cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub)
        
        tokens = try? cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub)
        account = try? cacheAccessor.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: contextStub)
        XCTAssertNotNil(tokens)
        XCTAssertNotNil(account)
        
        XCTAssertNoThrow(try cacheAccessor.clearCache(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub))
        
        tokens = try? cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub)
        account = try? cacheAccessor.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: contextStub)
        XCTAssertNil(tokens)
        XCTAssertNil(account)
    }
    
    // MARK: unhappy cases
    
    func testDataRetrieval_whenNoDataIsStored_shouldThrowsAnError() {
        XCTAssertThrowsError(try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertThrowsError(try cacheAccessor.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: contextStub))
    }
    
    func testContentDeletion_whenNoDataIsStored_shouldNotThrowsAnError() {
        XCTAssertNoThrow(try cacheAccessor.removeTokens(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub))
        XCTAssertNoThrow(try cacheAccessor.clearCache(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub))
    }
    
    func testRemoveTokens_whenInvalidInputIsUsed_shouldNotThrowsAnError() {
        var authority: MSIDAuthority? = nil
        XCTAssertNoThrow(authority = try MSIDB2CAuthority(url: URL(string: "https://www.microsoft.com")!, validateFormat: false, context: nil))
        XCTAssertNoThrow(try cacheAccessor.removeTokens(accountIdentifier: MSIDAccountIdentifier(), authority: authority!, clientId: "" , context: contextStub))
    }
    
    func testStoreTokens_whenAccessAndRefreshTokensAreMissing_shouldThrowsAnErrorOnGetTokens() {
        let tokenResponse = getTokenResponse()
        tokenResponse.accessToken = nil
        tokenResponse.refreshToken = nil
        XCTAssertNoThrow(try cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub))
        
        XCTAssertThrowsError(try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
    }
    
    func testGetTokens_whenThereIsNoAuthSchemeOrAccountIdentifier_shouldThrowsAnError() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try cacheAccessor.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub))
        
        var parameters = getParameters()
        parameters.msidConfiguration.authScheme = nil
        XCTAssertThrowsError(try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
        
        parameters = getParameters()
        parameters.accountIdentifier = MSIDAccountIdentifier()
        XCTAssertThrowsError(try cacheAccessor.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: contextStub))
    }
    
    // MARK: private methods
    
    private func getParameters() -> ParametersStub {
        ParametersStub(
            accountIdentifier: getAccountIdentifier(),
            msidConfiguration: getMSIDConfiguration()
        )
    }
    
    private func getAccountIdentifier() -> MSIDAccountIdentifier {
        return MSIDAccountIdentifier(displayableId: "displayableId", homeAccountId: "fedcba98-7654-3210-0000-000000000000.00000000-0000-1234-5678-90abcdefffff")
    }
    
    private func getTokenResponse() -> MSIDAADTokenResponse {
        let tokenResponse = MSIDAADTokenResponse()
        tokenResponse.accessToken = "AccessToken"
        tokenResponse.refreshToken = "refreshToken"
        tokenResponse.idToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        tokenResponse.scope = "user.read"
        let clientInfo = try? MSIDClientInfo(rawClientInfo: "eyAidWlkIiA6ImZlZGNiYTk4LTc2NTQtMzIxMC0wMDAwLTAwMDAwMDAwMDAwMCIsICJ1dGlkIiA6IjAwMDAwMDAwLTAwMDAtMTIzNC01Njc4LTkwYWJjZGVmZmZmZiJ9")
        tokenResponse.clientInfo = clientInfo
        return tokenResponse
    }
    
    private func getMSIDConfiguration() -> MSIDConfiguration {
        let configuration = MSIDConfiguration(authority: try? MSIDB2CAuthority(url: URL(string: "https://contoso.com/tfp/tenantName/policyName")!, validateFormat: false, context: nil), redirectUri: "", clientId: "clientId", target: "user.read") ?? MSIDConfiguration()
        let authSchema = MSIDAuthenticationSchemePop(schemeParameters: [
            "kid":"kidSample",
            "token_type":"Pop",
            "req_cnf":"eyJraWQiOiJYaU1hYWdoSXdCWXQwLWU2RUFydWxuaWtLbExVdVlrcXVHRk05YmE5RDF3In0"
        ])
        configuration.authScheme = authSchema
        return configuration
    }
}

private struct ParametersStub {
    var accountIdentifier: MSIDAccountIdentifier
    let msidConfiguration: MSIDConfiguration
}

private class ContextStub: MSIDRequestContext {

    var currentAppRequestMetadata = [AnyHashable : Any]()
    var internalCorrelationId = UUID()
    var telemetryId = UUID()

    init() {
        guard let metadata = Bundle.main.infoDictionary else { return }
        let appName = metadata["CFBundleDisplayName"] ?? (metadata["CFBundleName"] ?? "")
        let appVer = metadata["CFBundleShortVersionString"] ?? ""
        currentAppRequestMetadata[MSID_VERSION_KEY] = MSIDVersion.sdkVersion()
        currentAppRequestMetadata[MSID_APP_NAME_KEY] = appName
        currentAppRequestMetadata[MSID_APP_VER_KEY] = appVer
    }

    func correlationId() -> UUID! {
        internalCorrelationId
    }

    func logComponent() -> String! {
        MSIDVersion.sdkName()
    }

    func telemetryRequestId() -> String! {
        telemetryId.uuidString
    }

    func appRequestMetadata() -> [AnyHashable : Any]! {
        currentAppRequestMetadata
    }
}
