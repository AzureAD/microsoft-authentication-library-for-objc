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

final class MSALNativeAuthCacheAccessorTest: XCTestCase {
    private let tokenCache: MSIDDefaultTokenCacheAccessor = {
            let dataSource = MSIDTestCacheDataSource()
            return MSIDDefaultTokenCacheAccessor(dataSource: dataSource, otherCacheAccessors: [])
        }()

    private let accountMetadataCache: MSIDAccountMetadataCacheAccessor = MSIDAccountMetadataCacheAccessor(dataSource: MSIDTestCacheDataSource())

    private lazy var cacheAccessor = MSALNativeAuthCacheAccessor(tokenCache: tokenCache, accountMetadataCache: accountMetadataCache)

    private lazy var parameters = getParameters()
    private lazy var contextStub = ContextStub()
    
    override func setUp() {
        clearCache()
    }
    
    override func tearDown() {
        clearCache()
    }
    
    // MARK: happy cases
    
    func testTokensStore_whenAllInfoPresent_shouldSaveTokensCorrectly() {
        let tokenResponse = getTokenResponse()
        let parameters = getParameters()
        XCTAssertNoThrow(try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil))
        var rawIdToken: String? = nil
        
        XCTAssertNoThrow(rawIdToken = try cacheAccessor.getIdToken(account: parameters.account, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(rawIdToken, tokenResponse.idToken)
    }
    
    func testUpdateTokensAndAccount_whenAllInfoPresent_shouldUpdateDataCorrectly() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil))
        var rawIdToken: String? = nil
        
        XCTAssertNoThrow(rawIdToken = try cacheAccessor.getIdToken(account: parameters.account, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(rawIdToken, tokenResponse.idToken)
        
        let newAccessToken = "newAccessToken"
        let newRefreshToken = "newRefreshToken"
        let newIdToken = getUpdatedIdToken()
        XCTAssertNotEqual(newIdToken, tokenResponse.idToken)
        tokenResponse.accessToken = newAccessToken
        tokenResponse.refreshToken = newRefreshToken
        tokenResponse.idToken = newIdToken
        XCTAssertNotNil(try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil))

        XCTAssertNoThrow(rawIdToken = try cacheAccessor.getIdToken(account: parameters.account, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(rawIdToken, newIdToken)
    }

    func testGetAllAccounts_whenAllInfoPresent_shouldRetrieveDataCorrectly() {
        let tokenResponse = getTokenResponse()
        var rawIdToken: String? = nil
        var account: MSALAccount? = nil

        XCTAssertNoThrow(try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil))
        XCTAssertNoThrow(account = try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration).first)
        XCTAssertEqual(account?.username, parameters.accountIdentifier.displayableId)
        XCTAssertEqual(account?.identifier, parameters.accountIdentifier.homeAccountId)
        XCTAssertEqual(account?.environment, "contoso.com")
        XCTAssertNil(account?.accountClaims)
        XCTAssertNoThrow(rawIdToken = try cacheAccessor.getIdToken(account: account!, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(rawIdToken, tokenResponse.idToken)
    }

    func testGetAllAccounts_whenAllInfoPresent_shouldRetrieveDataOnlyOnSameAuthority() {
        let tokenResponse = getTokenResponse()
        var rawIdToken: String? = nil
        var account: MSALAccount? = nil

        XCTAssertNoThrow(try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil))
        XCTAssertNoThrow(account = try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration).first)
        XCTAssertEqual(account?.username, parameters.accountIdentifier.displayableId)
        XCTAssertEqual(account?.identifier, parameters.accountIdentifier.homeAccountId)
        XCTAssertEqual(account?.environment, "contoso.com")
        XCTAssertNil(account?.accountClaims)
        parameters.msidConfiguration = getMSIDConfiguration(host: "https://contoso.com/tfp/tenantName")
        XCTAssertNoThrow(rawIdToken = try cacheAccessor.getIdToken(account: account!, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(rawIdToken, tokenResponse.idToken)
    }

    func testDataRetrieval_whenAccountIsOverwritten_shouldRetrieveLastAccount() {
        let tokenResponse = getTokenResponse()
        XCTAssertNoThrow(try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil))
        var rawIdToken: String? = nil
        var account: MSALAccount? = nil

        let newDisplayableId = "newDisplayableId"
        let newAccessToken = "newAccessToken"
        let newRefreshToken = "newRefreshToken"
        let newIdToken = getUpdatedIdToken()
        tokenResponse.accessToken = newAccessToken
        tokenResponse.refreshToken = newRefreshToken
        tokenResponse.idToken = newIdToken
        XCTAssertNoThrow(try cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil))
        XCTAssertNoThrow(account = try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration).first)
        XCTAssertEqual(account?.username, newDisplayableId)
        XCTAssertEqual(account?.identifier, parameters.accountIdentifier.homeAccountId)
        XCTAssertEqual(account?.environment, "contoso.com")
        XCTAssertNil(account?.accountClaims)
        XCTAssertNoThrow(rawIdToken = try cacheAccessor.getIdToken(account: account!, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertEqual(rawIdToken, newIdToken)
    }
    
    func testTokensDeletion_whenAllInfoPresent_shouldRemoveTokensCorrectly() {
        var rawIdToken: String? = nil
        XCTAssertThrowsError(rawIdToken = try cacheAccessor.getIdToken(account: parameters.account, configuration: parameters.msidConfiguration, context: contextStub))
        XCTAssertNil(rawIdToken)
        
        let tokenResponse = getTokenResponse()
        let _ = try? cacheAccessor.validateAndSaveTokensAndAccount(tokenResponse: tokenResponse, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil)
        
        rawIdToken = try? cacheAccessor.getIdToken(account: parameters.account, configuration: parameters.msidConfiguration, context: contextStub)
        XCTAssertNotNil(rawIdToken)
        
        XCTAssertNoThrow(try cacheAccessor.removeTokens(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub))
        
        rawIdToken = try? cacheAccessor.getIdToken(account: parameters.account, configuration: parameters.msidConfiguration, context: contextStub)
        XCTAssertNil(rawIdToken)
    }
    
    // MARK: unhappy cases

    func testDirectSave_validatorErrorIsNotSwallowed() {
        let response = getTokenResponse()
        response.error = "invalid_grant"

        XCTAssertThrowsError(
            try cacheAccessor.validateAndSaveTokensAndAccount(
                tokenResponse: response, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil)
        ) { error in
            XCTAssertEqual((error as NSError).domain, MSIDOAuthErrorDomain)
            XCTAssertEqual((error as NSError).userInfo[MSIDOAuthErrorKey] as? String, "invalid_grant")
        }
    }
    
    func testDataRetrieval_whenNoDataIsStored_shouldThrowsAnError() {
        XCTAssertThrowsError(try cacheAccessor.getIdToken(account: parameters.account, configuration: parameters.msidConfiguration, context: contextStub))
    }

    func testDataRetrieval_whenNoAccountStored_ShouldReturnNoAccount() {
        var account: MSALAccount? = nil
        XCTAssertNoThrow(account = try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration).first)
        XCTAssertNil(account)
    }
    
    func testContentDeletion_whenNoDataIsStored_shouldNotThrowsAnError() {
        XCTAssertNoThrow(try cacheAccessor.removeTokens(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub))
        XCTAssertNoThrow(try cacheAccessor.clearCache(accountIdentifier: parameters.accountIdentifier, authority: parameters.msidConfiguration.authority, clientId: parameters.msidConfiguration.clientId, context: contextStub))
    }
    
    func testRemoveTokens_whenInvalidInputIsUsed_shouldNotThrowsAnError() {
        var authority: MSIDAuthority? = nil
        XCTAssertNoThrow(authority = try MSIDCIAMAuthority(url: URL(string: "https://www.microsoft.com")!, validateFormat: false, context: nil))
        XCTAssertNoThrow(try cacheAccessor.removeTokens(accountIdentifier: MSIDAccountIdentifier(), authority: authority!, clientId: "" , context: contextStub))
    }
    
    func testCache_requestedTarget_requiresMatchingReceiptBeforeEvictionOrWrite() throws {
        let cases: [(Any?, Bool)] = [
            ("+mc", true), ("-MC", true), (nil, false), ("", false),
            ("+all", false), ("+mc,+other", false), ("mc", false), (NSNull(), false)
        ]
        for (receipt, accepted) in cases {
            let response = getTokenResponse()
            response.idToken = try MSALNativeAuthTokenResponseFixtures.idToken(receipt: receipt)
            let spy = makeCacheSpy()
            let operation = {
                try spy.cache(response, context: self.contextStub, msidConfiguration: self.parameters.msidConfiguration,
                              claimsRequestJson: MSALNativeAuthTokenResponseFixtures.targetClaims) { _, _ in true }
            }
            if accepted {
                XCTAssertNoThrow(try operation())
                XCTAssertEqual(spy.clearCallCount, 1)
                XCTAssertEqual(spy.saveCallCount, 1)
                XCTAssertEqual(spy.claimsRequestJsonReceived, MSALNativeAuthTokenResponseFixtures.targetClaims)
            } else {
                XCTAssertThrowsError(try operation()) { error in
                    XCTAssertEqual((error as NSError).code, MSIDErrorCode.ageAssuranceTargetMismatch.rawValue)
                    XCTAssertEqual((error as NSError).userInfo[MSIDOAuthErrorKey] as? String, "age_assurance_target_mismatch")
                }
                XCTAssertEqual(spy.clearCallCount, 0)
                XCTAssertEqual(spy.saveCallCount, 0)
            }
        }
    }

    func testCache_noRequestedTargets_preservesAbsentEmptyAndSignedAllContract() throws {
        let cases: [(String?, Bool)] = [
            (nil, true),
            (try MSALNativeAuthTokenResponseFixtures.idToken(receipt: nil), true),
            (try MSALNativeAuthTokenResponseFixtures.idToken(receipt: ""), true),
            (try MSALNativeAuthTokenResponseFixtures.idToken(receipt: "+all"), true),
            (try MSALNativeAuthTokenResponseFixtures.idToken(receipt: "-ALL"), true),
            (try MSALNativeAuthTokenResponseFixtures.idToken(receipt: "+mc"), false),
            (try MSALNativeAuthTokenResponseFixtures.idToken(receipt: "+all,-mc"), false),
            (try MSALNativeAuthTokenResponseFixtures.idToken(receipt: NSNull()), false),
            ("not-a-jwt", false)
        ]
        for (idToken, accepted) in cases {
            let response = getTokenResponse()
            response.idToken = idToken
            let spy = makeCacheSpy()
            let operation = {
                try spy.cache(response, context: self.contextStub, msidConfiguration: self.parameters.msidConfiguration,
                              claimsRequestJson: nil) { _, _ in true }
            }
            if accepted {
                XCTAssertNoThrow(try operation())
                XCTAssertEqual(spy.saveCallCount, 1)
            } else {
                XCTAssertThrowsError(try operation())
                XCTAssertEqual(spy.clearCallCount, 0)
                XCTAssertEqual(spy.saveCallCount, 0)
            }
        }
    }

    func testCache_nonStringIdTokens_areNotTreatedAsAbsent() throws {
        let rawTokens: [Any] = [NSNull(), 123, ["value": "token"]]
        for rawToken in rawTokens {
            var json = MSALNativeAuthV2RequestProviderMock.successfulTokenResponseJson
            json["id_token"] = rawToken
            let response = try MSALNativeAuthCIAMTokenResponse(jsonDictionary: json)
            let spy = makeCacheSpy()
            XCTAssertThrowsError(
                try spy.cache(response, context: contextStub, msidConfiguration: parameters.msidConfiguration,
                              claimsRequestJson: nil) { _, _ in true }
            )
            XCTAssertEqual(spy.clearCallCount, 0)
            XCTAssertEqual(spy.saveCallCount, 0)
        }
    }

    func testCache_multipleTargets_ignoreOrderCaseAndSignWithoutAcceptingExtras() throws {
        let claims = "{\"id_token\":{\"xms_agvs\":{\"additionalProperties\":[\"target-mc\",\"target-oa\"]}}}"
        for (receipt, accepted) in [("-OA,+MC", true), ("+mc", false), ("+mc,-oa,+extra", false)] {
            let response = getTokenResponse()
            response.idToken = try MSALNativeAuthTokenResponseFixtures.idToken(receipt: receipt)
            let spy = makeCacheSpy()
            let operation = {
                try spy.cache(response, context: self.contextStub, msidConfiguration: self.parameters.msidConfiguration,
                              claimsRequestJson: claims) { _, _ in true }
            }
            if accepted {
                XCTAssertNoThrow(try operation())
            } else {
                XCTAssertThrowsError(try operation())
                XCTAssertEqual(spy.clearCallCount, 0)
                XCTAssertEqual(spy.saveCallCount, 0)
            }
        }
    }

    func testCache_rejectedResponse_keepsExistingAccountAndAllTokenSecrets() throws {
        let original = getTokenResponse()
        _ = try cacheAccessor.validateAndSaveTokensAndAccount(
            tokenResponse: original, configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil)
        let originalTokens = try cachedTokenSecrets()
        XCTAssertEqual(originalTokens.count, 3)
        let receipts: [String?] = [nil, "+all"]
        for receipt in receipts {
            let rejected = getTokenResponse()
            rejected.idToken = try MSALNativeAuthTokenResponseFixtures.idToken(receipt: receipt)
            rejected.accessToken = "rejected-access-token"
            rejected.refreshToken = "rejected-refresh-token"
            XCTAssertThrowsError(
                try cacheAccessor.cache(rejected, context: contextStub, msidConfiguration: parameters.msidConfiguration,
                                        claimsRequestJson: MSALNativeAuthTokenResponseFixtures.targetClaims) { _, _ in true }
            ) { error in
                XCTAssertEqual((error as NSError).code, MSIDErrorCode.ageAssuranceTargetMismatch.rawValue)
            }
            XCTAssertEqual(try cachedTokenSecrets(), originalTokens)
            let accounts = try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration)
            XCTAssertEqual(accounts.count, 1)
            XCTAssertEqual(accounts.first?.identifier, parameters.account.identifier)
        }
    }

    func testCache_missingHomeAccountId_keepsExistingAccountAndAllTokenSecrets() throws {
        _ = try cacheAccessor.validateAndSaveTokensAndAccount(
            tokenResponse: getTokenResponse(), configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil)
        let originalTokens = try cachedTokenSecrets()
        XCTAssertEqual(originalTokens.count, 3)

        let rejected = getTokenResponse()
        rejected.idToken = nil
        rejected.accessToken = "rejected-access-token"
        rejected.refreshToken = "rejected-refresh-token"
        let clientInfo = Data(#"{"utid":"00000000-0000-1234-5678-90abcdefffff"}"#.utf8).base64EncodedString()
        rejected.clientInfo = try MSIDClientInfo(rawClientInfo: clientInfo)

        XCTAssertThrowsError(
            try cacheAccessor.cache(rejected, context: contextStub, msidConfiguration: parameters.msidConfiguration,
                                    claimsRequestJson: nil) { _, _ in true }
        ) { error in
            let expectedError = MSALNativeAuthInternalError.invalidResponse as NSError
            XCTAssertEqual((error as NSError).domain, expectedError.domain)
            XCTAssertEqual((error as NSError).code, expectedError.code)
        }
        XCTAssertEqual(try cachedTokenSecrets(), originalTokens)
        let accounts = try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration)
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.identifier, parameters.account.identifier)
    }

    func testCache_matchingResponse_stillReplacesExistingTokens() throws {
        _ = try cacheAccessor.validateAndSaveTokensAndAccount(
            tokenResponse: getTokenResponse(), configuration: parameters.msidConfiguration, context: contextStub, claimsRequestJson: nil)
        let response = getTokenResponse()
        response.idToken = try MSALNativeAuthTokenResponseFixtures.idToken(receipt: "+mc")
        response.accessToken = "replacement-access-token"
        response.refreshToken = "replacement-refresh-token"
        _ = try cacheAccessor.cache(
            response, context: contextStub, msidConfiguration: parameters.msidConfiguration,
            claimsRequestJson: MSALNativeAuthTokenResponseFixtures.targetClaims) { _, _ in true }
        XCTAssertEqual(try cachedTokenSecrets(), [response.idToken!, response.accessToken!, response.refreshToken!].sorted())
        XCTAssertEqual(try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration).count, 1)
    }

    func testDirectSave_mismatchErrorIsNotSwallowed() throws {
        XCTAssertThrowsError(
            try cacheAccessor.validateAndSaveTokensAndAccount(
                tokenResponse: getTokenResponse(), configuration: parameters.msidConfiguration, context: contextStub,
                claimsRequestJson: MSALNativeAuthTokenResponseFixtures.targetClaims)
        ) { error in
            XCTAssertEqual((error as NSError).code, MSIDErrorCode.ageAssuranceTargetMismatch.rawValue)
        }
    }

    func testCache_accountValidationFailure_doesNotEvictOrWrite() {
        let spy = makeCacheSpy()
        XCTAssertThrowsError(
            try spy.cache(getTokenResponse(), context: contextStub, msidConfiguration: parameters.msidConfiguration,
                          claimsRequestJson: nil) { _, _ in false }
        )
        XCTAssertEqual(spy.clearCallCount, 0)
        XCTAssertEqual(spy.saveCallCount, 0)
    }

    func testCache_serverError_isNotReclassifiedAsReceiptMismatchOrAllowedToEvict() {
        let response = getTokenResponse()
        response.error = "invalid_grant"
        let spy = makeCacheSpy()
        XCTAssertThrowsError(
            try spy.cache(response, context: contextStub, msidConfiguration: parameters.msidConfiguration,
                          claimsRequestJson: MSALNativeAuthTokenResponseFixtures.targetClaims) { _, _ in true }
        ) { error in
            XCTAssertEqual((error as NSError).userInfo[MSIDOAuthErrorKey] as? String, "invalid_grant")
            XCTAssertNotEqual((error as NSError).code, MSIDErrorCode.ageAssuranceTargetMismatch.rawValue)
        }
        XCTAssertEqual(spy.clearCallCount, 0)
        XCTAssertEqual(spy.saveCallCount, 0)
    }

    func testCache_missingTokens_failsFullValidationBeforeEviction() {
        let response = getTokenResponse()
        response.idToken = nil
        response.accessToken = nil
        let spy = makeCacheSpy()
        XCTAssertThrowsError(
            try spy.cache(response, context: contextStub, msidConfiguration: parameters.msidConfiguration,
                          claimsRequestJson: nil) { _, _ in true }
        )
        XCTAssertEqual(spy.clearCallCount, 0)
        XCTAssertEqual(spy.saveCallCount, 0)
    }

    private func makeCacheSpy() -> MSALNativeAuthCacheAccessorMock {
        let spy = MSALNativeAuthCacheAccessorMock(tokenCache: tokenCache, accountMetadataCache: accountMetadataCache)
        spy.mockUserAccounts = [parameters.account]
        spy.expectedMSIDTokenResult = MSIDTokenResult()
        return spy
    }

    private func cachedTokenSecrets() throws -> [String] {
        let tokens = try XCTUnwrap(try tokenCache.allTokens(with: contextStub))
        return tokens.compactMap { token in
            if let accessToken = token as? MSIDAccessToken { return accessToken.accessToken }
            if let refreshToken = token as? MSIDRefreshToken { return refreshToken.refreshToken }
            if let idToken = token as? MSIDIdToken { return idToken.rawIdToken }
            return nil
        }.sorted()
    }

    // MARK: private methods
    
    private func getParameters() -> ParametersStub {
        ParametersStub(
            account: getAccount(),
            accountIdentifier: getAccountIdentifier(),
            msidConfiguration: getMSIDConfiguration(host: "https://contoso.com/tfp/tenantName")
        )
    }
    
    private func getAccountIdentifier() -> MSIDAccountIdentifier {
        return MSIDAccountIdentifier(displayableId: "1234567890", homeAccountId: "fedcba98-7654-3210-0000-000000000000.00000000-0000-1234-5678-90abcdefffff")
    }

    private func getAccount() -> MSALAccount {
        let homeAccountId = MSALAccountId(accountIdentifier: "fedcba98-7654-3210-0000-000000000000.00000000-0000-1234-5678-90abcdefffff", objectId: "", tenantId: "https://contoso.com/tfp/tenantName")
        let account = MSALAccount(username: "1234567890", homeAccountId: homeAccountId, environment: "contoso.com", tenantProfiles: [])
        account?.lookupAccountIdentifier = getAccountIdentifier()
        return account!
    }
    
    private func getTokenResponse() -> MSALNativeAuthCIAMTokenResponse {
        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "AccessToken"
        tokenResponse.refreshToken = "refreshToken"
        tokenResponse.idToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        tokenResponse.scope = "user.read"
        let clientInfo = try? MSIDClientInfo(rawClientInfo: "eyAidWlkIiA6ImZlZGNiYTk4LTc2NTQtMzIxMC0wMDAwLTAwMDAwMDAwMDAwMCIsICJ1dGlkIiA6IjAwMDAwMDAwLTAwMDAtMTIzNC01Njc4LTkwYWJjZGVmZmZmZiJ9")
        tokenResponse.clientInfo = clientInfo
        return tokenResponse
    }
    
    private func getUpdatedIdToken() -> String {
        return "eyJhbGciOiJIUzI1NiJ9.eyJ2ZXIiOiIyLjAiLCJpc3MiOiJodHRwczovL2xvZ2luLm1pY3Jvc29mdG9ubGluZS5jb20vdGVzdC92Mi4wIiwic3ViIjoiQUFBQUFBQUFBQUFBQUFBQUFBQUFBUFdLdXZBcTQ3ZWZsc0o3TXdnaW1rVSIsImF1ZCI6IjA5ODRhN2I2LWJjMTMtNDE0MS04YjBkLThmNzY3ZTEzNmJiNyIsImV4cCI6MTY4MTQ2MzAyMywiaWF0IjoxNjgxMzc2MzIzLCJuYmYiOjE2ODEzNzYzMjMsIm5hbWUiOiJOZXcgVXNlciIsInByZWZlcnJlZF91c2VybmFtZSI6Im5ld0Rpc3BsYXlhYmxlSWQiLCJvaWQiOiJuZXdPaWQiLCJ0aWQiOiJuZXdUaWQiLCJhaW8iOiJEVGhGY3dSdFgwT0tqNXBTSEdOZUdVR1NVNGhaNFJoNU83TmhnUjYzMnpldEM5WmgzM3dWRypXeUJqIVFPM0twU0dXRVRla25sMDA1WE8qQWg0bXhRamVuR2VRZXIqakx3Nypkcmh1cDdTc0NJRThraUlsempYMDZuaWNWNFFFTGZxR3BoYkRuemI0RWtOZEZXTHBOTmhJJCJ9.A9K5OQgR3dUaexxosQg6FOMOteC9R96fI0sZtF-KwjU"
    }

    private func getMSIDConfiguration(host: String) -> MSIDConfiguration {
        let configuration = MSIDConfiguration(authority: try? MSIDCIAMAuthority(url: URL(string: host)!, validateFormat: false, context: nil), redirectUri: "", clientId: "clientId", target: "user.read") ?? MSIDConfiguration()
        let authSchema = MSIDAuthenticationScheme()
        configuration.authScheme = authSchema
        return configuration
    }

    private func clearCache() {
        var accounts: [MSALAccount]!
            XCTAssertNoThrow(accounts = try cacheAccessor.getAllAccounts(configuration: parameters.msidConfiguration))
            for account in accounts {
                guard let homeAccountId = account.homeAccountId else {
                    XCTFail("Expected homeAccountId to be non-nil for account: \(String(describing: account.username))")
                    continue
                }
                
                let identifier = MSIDAccountIdentifier(displayableId: account.username, homeAccountId: homeAccountId.identifier)!
                XCTAssertNoThrow(try cacheAccessor.clearCache(accountIdentifier: identifier,
                                                              authority: parameters.msidConfiguration.authority,
                                                              clientId: parameters.msidConfiguration.clientId,
                                                              context: contextStub))
            }
    }
}

private struct ParametersStub {
    var account: MSALAccount
    var accountIdentifier: MSIDAccountIdentifier
    var msidConfiguration: MSIDConfiguration
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
