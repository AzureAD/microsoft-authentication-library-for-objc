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

final class MSALNativeAuthCacheGatewayTest: XCTestCase {
    private let gateway = MSALNativeAuthCacheGateway()
    private lazy var parameters = getParameters()
    
    override func tearDownWithError() throws {
        try gateway.clearCache(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.clientId, context: parameters)
    }
    
    // MARK: happy cases
    
    func testTokensStore_whenAllInfoPresent_shouldSaveTokensCorrectly() {
        let tokenResponse = getTokenResponse()
        let parameters = getParameters()
        XCTAssertNoThrow(try gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters))
        var tokens: MSALNativeAuthTokens? = nil
        
        XCTAssertNoThrow(tokens = try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
        XCTAssertEqual(tokens?.accessToken?.accessToken, tokenResponse.accessToken)
        XCTAssertEqual(tokens?.refreshToken?.refreshToken, tokenResponse.refreshToken)
        XCTAssertEqual(tokens?.idToken?.rawIdToken, tokenResponse.idToken)
    }
    
    func testUpdateTokensAndAccount_whenAllInfoPresent_shouldUpdateDataCorrectly() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters))
        var tokens: MSALNativeAuthTokens? = nil
        
        XCTAssertNoThrow(tokens = try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
        XCTAssertEqual(tokens?.accessToken?.accessToken, tokenResponse.accessToken)
        XCTAssertEqual(tokens?.refreshToken?.refreshToken, tokenResponse.refreshToken)
        XCTAssertEqual(tokens?.idToken?.rawIdToken, tokenResponse.idToken)
        
        let newAccessToken = "newAccessToken"
        let newRefreshToken = "newRefreshToken"
        let newIdToken = "newIdToken"
        tokenResponse.accessToken = newAccessToken
        tokenResponse.refreshToken = newRefreshToken
        tokenResponse.idToken = newIdToken
        XCTAssertNoThrow(try gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters))
        
        XCTAssertNoThrow(tokens = try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
        XCTAssertEqual(tokens?.accessToken?.accessToken, newAccessToken)
        XCTAssertEqual(tokens?.refreshToken?.refreshToken, newRefreshToken)
        XCTAssertEqual(tokens?.idToken?.rawIdToken, newIdToken)
    }
    
    func testAccountStore_whenAllInfoPresent_shouldStoreAccountCorrectly() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters))
        
        var account: MSIDAccount? = nil
        XCTAssertNoThrow(account = try gateway.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: parameters))
        XCTAssertEqual(account?.accountIdentifier.homeAccountId, parameters.accountIdentifier.homeAccountId)
        // this information was took from the TokenResponse.IDToken (JWT format)
        XCTAssertEqual(account?.accountIdentifier.displayableId, "1234567890")
        XCTAssertEqual(account?.accountIdentifier.utid, parameters.accountIdentifier.utid)
        XCTAssertEqual(account?.accountIdentifier.uid, parameters.accountIdentifier.uid)
        XCTAssertEqual(account?.clientInfo, tokenResponse.clientInfo)
    }
    
    func testTokensDeletion_whenAllInfoPresent_shouldRemoveTokensCorrectly() {
        var tokens: MSALNativeAuthTokens? = nil
        XCTAssertThrowsError(tokens = try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
        XCTAssertNil(tokens)
        
        let tokenResponse = getTokenResponse()
        try? gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters)
        
        tokens = try? gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters)
        XCTAssertNotNil(tokens)
        
        XCTAssertNoThrow(try gateway.removeTokens(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: parameters))
        
        tokens = try? gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters)
        XCTAssertNil(tokens)
    }
    
    func testClearCache_whenAllInfoPresent_shouldRemoveTokensAndAccountCorrectly() {
        var tokens: MSALNativeAuthTokens? = nil
        var account: MSIDAccount? = nil
        XCTAssertThrowsError(tokens = try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
        XCTAssertThrowsError(account = try gateway.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: parameters))
        XCTAssertNil(tokens)
        XCTAssertNil(account)
        
        let tokenResponse = getTokenResponse()
        try? gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters)
        
        tokens = try? gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters)
        account = try? gateway.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: parameters)
        XCTAssertNotNil(tokens)
        XCTAssertNotNil(account)
        
        XCTAssertNoThrow(try gateway.clearCache(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: parameters))
        
        tokens = try? gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters)
        account = try? gateway.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: parameters)
        XCTAssertNil(tokens)
        XCTAssertNil(account)
    }
    
    // MARK: unhappy cases
    
    func testDataRetrieval_whenNoDataIsStored_shouldThrowsAnError() {
        XCTAssertThrowsError(try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
        XCTAssertThrowsError(try gateway.getAccount(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, context: parameters))
    }
    
    func testContentDeletion_whenNoDataIsStored_shouldNotThrowsAnError() {
        XCTAssertNoThrow(try gateway.removeTokens(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: parameters))
        XCTAssertNoThrow(try gateway.clearCache(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: parameters))
    }
    
    func testRemoveTokens_whenInvalidInputIsUsed_shouldNotThrowsAnError() {
        var authority: MSIDAuthority? = nil
        XCTAssertNoThrow(authority = try MSIDB2CAuthority(url: URL(string: "https://www.microsoft.com")!, validateFormat: false, context: nil))
        XCTAssertNoThrow(try gateway.removeTokens(accountIdentifier: MSIDAccountIdentifier(), authority: authority!, clientId: "" , context: parameters))
    }
    
    func testStoreTokens_whenAccessAndRefreshTokensAreMissing_shouldThrowsAnErrorOnGetTokens() {
        let tokenResponse = getTokenResponse()
        tokenResponse.accessToken = nil
        tokenResponse.refreshToken = nil
        XCTAssertNoThrow(try gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters))
        
        XCTAssertThrowsError(try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
    }
    
    func testGetTokens_whenThereIsNoAuthSchemeOrAccountIdentifier_shouldThrowsAnError() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try gateway.saveTokensAndAccount(tokenResult: tokenResponse, configuration: parameters.msidConfiguration, context: parameters))
        
        var parameters = getParameters()
        parameters.msidConfiguration.authScheme = nil
        XCTAssertThrowsError(try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
        
        parameters = getParameters()
        parameters.accountIdentifier = MSIDAccountIdentifier()
        XCTAssertThrowsError(try gateway.getTokens(accountIdentifier: parameters.accountIdentifier, configuration: parameters.msidConfiguration, context: parameters))
    }
    
    // MARK: private methods
    
    private func getParameters() -> MSALNativeAuthRequestParameters {
        let parameters = MSALNativeAuthRequestParameters()
        parameters.msidConfiguration = getMSIDConfiguration()
        parameters.accountIdentifier = getAccountIdentifier()
        parameters.clientId = "clientId"
        parameters.oidcScope = "user.read"
        return parameters
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
