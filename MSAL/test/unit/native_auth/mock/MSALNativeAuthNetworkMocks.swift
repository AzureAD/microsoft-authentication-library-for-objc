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

struct MSALNativeAuthNetworkStubs {

    static let tenantName = "test_tenant"

    static var authority: MSALCIAMAuthority {
        try! .init(
            url: .init(string: DEFAULT_TEST_AUTHORITY)!
        )
    }

    static var msidAuthority: MSIDCIAMAuthority {
        try! .init(
            url: .init(string: DEFAULT_TEST_AUTHORITY)!,
            validateFormat: false,
            rawTenant: tenantName,
            context: nil
        )
    }
}

class MSALNativeAuthRequestContextMock: MSIDRequestContext {

    let mockCorrelationId: UUID
    var mockTelemetryRequestId = ""
    var mockLogComponent = ""
    var mockAppRequestMetadata: [AnyHashable: Any] = [:]

    init(correlationId: UUID = .init(uuidString: DEFAULT_TEST_UID)!) {
        self.mockCorrelationId = correlationId
    }

    func correlationId() -> UUID {
        return mockCorrelationId
    }

    func logComponent() -> String {
        return mockLogComponent
    }

    func telemetryRequestId() -> String {
        return mockTelemetryRequestId
    }

    func appRequestMetadata() -> [AnyHashable: Any] {
        return mockAppRequestMetadata
    }
}

class MSALNativeAuthSignInResponseValidatorMock: MSALNativeAuthSignInResponseValidating {

    var expectedRequestContext: MSALNativeAuthRequestContext?
    var expectedConfiguration: MSIDConfiguration?
    var expectedTokenResponse: MSIDAADTokenResponse?
    var expectedChallengeResponse: MSALNativeAuthSignInChallengeResponse?
    var expectedInitiateResponse: MSALNativeAuthSignInInitiateResponse?
    var expectedResponseError: Error?
    var tokenValidatedResponse: MSALNativeAuthSignInTokenValidatedResponse = .error(.generalError)
    var initiateValidatedResponse: MSALNativeAuthSignInInitiateValidatedResponse = .error(.userNotFound)
    var challengeValidatedResponse: MSALNativeAuthSignInChallengeValidatedResponse = .error(.expiredToken)
    
    func validate(context: MSAL.MSALNativeAuthRequestContext, msidConfiguration: MSIDConfiguration, result: Result<MSIDAADTokenResponse, Error>) -> MSAL.MSALNativeAuthSignInTokenValidatedResponse {
        checkConfAndContext(context, config: msidConfiguration)
        if case .success(let successTokenResponse) = result, let expectedTokenResponse = expectedTokenResponse {
            XCTAssertEqual(successTokenResponse.accessToken, expectedTokenResponse.accessToken)
            XCTAssertEqual(successTokenResponse.refreshToken, expectedTokenResponse.refreshToken)
            XCTAssertEqual(successTokenResponse.idToken, expectedTokenResponse.idToken)
            XCTAssertEqual(successTokenResponse.scope, expectedTokenResponse.scope)
        }
        if case .failure(let tokenResponseError) = result, let expectedTokenResponseError = expectedResponseError {
            XCTAssertTrue(type(of: tokenResponseError) == type(of: expectedResponseError))
            XCTAssertEqual(tokenResponseError.localizedDescription, expectedTokenResponseError.localizedDescription)
        }
        return tokenValidatedResponse
    }
    
    func validate(context: MSAL.MSALNativeAuthRequestContext, result: Result<MSAL.MSALNativeAuthSignInChallengeResponse, Error>) -> MSAL.MSALNativeAuthSignInChallengeValidatedResponse {
        checkConfAndContext(context)
        if case .success(let successChallengeResponse) = result, let expectedChallengeResponse = expectedChallengeResponse {
            XCTAssertEqual(successChallengeResponse.challengeType, expectedChallengeResponse.challengeType)
            XCTAssertEqual(successChallengeResponse.credentialToken, expectedChallengeResponse.credentialToken)
            XCTAssertEqual(successChallengeResponse.challengeTargetLabel, expectedChallengeResponse.challengeTargetLabel)
            XCTAssertEqual(successChallengeResponse.challengeChannel, expectedChallengeResponse.challengeChannel)
            XCTAssertEqual(successChallengeResponse.codeLength, expectedChallengeResponse.codeLength)
        }
        if case .failure(let challengeResponseError) = result, let expectedChallengeResponseError = expectedResponseError {
            XCTAssertTrue(type(of: challengeResponseError) == type(of: expectedChallengeResponseError))
            XCTAssertEqual(challengeResponseError.localizedDescription, expectedChallengeResponseError.localizedDescription)
        }
        return challengeValidatedResponse
    }
    
    func validate(context: MSAL.MSALNativeAuthRequestContext, result: Result<MSAL.MSALNativeAuthSignInInitiateResponse, Error>) -> MSAL.MSALNativeAuthSignInInitiateValidatedResponse {
        checkConfAndContext(context)
        if case .success(let successInitiateResponse) = result, let expectedInitiateResponse = expectedInitiateResponse {
            XCTAssertEqual(successInitiateResponse.challengeType, expectedInitiateResponse.challengeType)
            XCTAssertEqual(successInitiateResponse.credentialToken, expectedInitiateResponse.credentialToken)
        }
        if case .failure(let initiateResponseError) = result, let expectedInitiateResponseError = expectedResponseError {
            XCTAssertTrue(type(of: initiateResponseError) == type(of: expectedInitiateResponseError))
            XCTAssertEqual(initiateResponseError.localizedDescription, expectedInitiateResponseError.localizedDescription)
        }
        return initiateValidatedResponse
    }
    
    private func checkConfAndContext(_ context: MSAL.MSALNativeAuthRequestContext, config: MSIDConfiguration? = nil) {
        if let expectedRequestContext = expectedRequestContext {
            XCTAssertEqual(expectedRequestContext.correlationId(), context.correlationId())
            XCTAssertEqual(expectedRequestContext.telemetryRequestId(), context.telemetryRequestId())
        }
        if let expectedConfiguration = expectedConfiguration {
            XCTAssertEqual(expectedConfiguration, config)
        }
    }
}

class MSALNativeAuthSignInRequestProviderMock: MSALNativeAuthSignInRequestProviding {
    
    var throwingInitError: Error?
    var throwingChallengeError: Error?
    var throwingTokenError: Error?
    var result: MSIDHttpRequest?
    var expectedContext: MSIDRequestContext?
    var expectedUsername: String?
    var expectedCredentialToken: String?
    var expectedTokenParams: MSALNativeAuthSignInTokenRequestParameters?
    
    func inititate(parameters: MSAL.MSALNativeAuthSignInInitiateRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedUsername = expectedUsername {
            XCTAssertEqual(expectedUsername, parameters.username)
        }
        return try returnMockedResult(throwingInitError)
    }
    
    func challenge(parameters: MSAL.MSALNativeAuthSignInChallengeRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedCredentialToken = expectedCredentialToken {
            XCTAssertEqual(expectedCredentialToken, parameters.credentialToken)
        }
        return try returnMockedResult(throwingChallengeError)
    }
    
    func token(parameters: MSAL.MSALNativeAuthSignInTokenRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedTokenParams = expectedTokenParams {
            XCTAssertEqual(expectedTokenParams.username, parameters.username)
            XCTAssertEqual(expectedTokenParams.credentialToken, parameters.credentialToken)
            XCTAssertEqual(expectedTokenParams.signInSLT, parameters.signInSLT)
            XCTAssertEqual(expectedTokenParams.grantType, parameters.grantType)
            XCTAssertEqual(expectedTokenParams.scope, parameters.scope)
            XCTAssertEqual(expectedTokenParams.password, parameters.password)
            XCTAssertEqual(expectedTokenParams.oobCode, parameters.oobCode)
            XCTAssertEqual(expectedTokenParams.context.correlationId(), parameters.context.correlationId())
        }
        return try returnMockedResult(throwingTokenError)
    }
    
    fileprivate func checkContext(_ context: MSIDRequestContext) {
        if let expectedContext = expectedContext {
            XCTAssertEqual(expectedContext.correlationId(), context.correlationId())
        }
    }
    
    private func returnMockedResult(_ error: Error?) throws -> MSIDHttpRequest  {
        if let throwingError = error {
            throw throwingError
        }
        if let result = result {
            return result
        }
        XCTFail("Both parameters are nil")
        throw ErrorMock.error
    }
}

class MSALNativeAuthTokenResponseHandlerMock: MSALNativeAuthTokenResponseHandling {

    private(set) var throwingError: Error?
    private(set) var handleTokenFuncResult: MSIDTokenResult?
    var expectedAccountId: MSIDAccountIdentifier?
    var expectedContext: MSIDRequestContext?
    var expectedValidateAccount: Bool?

    func mockHandleTokenFunc(throwingError: Error? = nil, result: MSIDTokenResult? = nil) {
        self.throwingError = throwingError
        self.handleTokenFuncResult = result
    }

    func handle(
        context: MSIDRequestContext,
        accountIdentifier: MSIDAccountIdentifier,
        tokenResponse: MSIDTokenResponse,
        configuration: MSIDConfiguration,
        validateAccount: Bool
    ) throws -> MSIDTokenResult {
        if throwingError == nil && handleTokenFuncResult == nil {
            XCTFail("Both parameters are nil")
        }
        if let expectedContext = expectedContext {
            XCTAssertEqual(expectedContext.correlationId(), context.correlationId())
        }
        if let expectedAccountId = expectedAccountId {
            XCTAssertEqual(expectedAccountId.displayableId, accountIdentifier.displayableId)
            XCTAssertEqual(expectedAccountId.homeAccountId, accountIdentifier.homeAccountId)
        }
        if let expectedValidateAccount = expectedValidateAccount {
            XCTAssertEqual(expectedValidateAccount, validateAccount)
        }

        if let error = throwingError {
            throw error
        }

        if let handleFuncResult = handleTokenFuncResult {
            return handleFuncResult
        }

        // This will cause the tests to immediately stop execution. Make sure you're setting one param using `mockFunc()`
        return handleTokenFuncResult!
    }

    func mockHandleResendCodeFunc(throwingError: Error? = nil, result: Bool? = nil) {
        self.throwingError = throwingError
    }

}

class HttpModuleMockConfigurator {

    static let baseUrl = URL(string: "https://www.contoso.com")!

    static func configure(request: MSIDHttpRequest,
                          response: HTTPURLResponse? = nil,
                          responseJson: Any) {

        let parameters = ["p1": "v1"]

        var httpResponse: HTTPURLResponse!
        if response == nil {
            httpResponse = HTTPURLResponse(
                url: HttpModuleMockConfigurator.baseUrl,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        } else {
            httpResponse = response
        }

        var urlRequest = URLRequest(url: HttpModuleMockConfigurator.baseUrl)
        urlRequest.httpMethod = "POST"

        let testUrlResponse = MSIDTestURLResponse.request(HttpModuleMockConfigurator.baseUrl, reponse: httpResponse)
        testUrlResponse?.setUrlFormEncodedBody(parameters)
        testUrlResponse?.setResponseJSON(responseJson)
        MSIDTestURLSession.add(testUrlResponse)

        request.urlRequest = urlRequest
        request.parameters = parameters
    }
}
