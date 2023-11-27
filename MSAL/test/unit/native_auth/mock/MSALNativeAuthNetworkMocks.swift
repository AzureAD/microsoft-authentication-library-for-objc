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

struct MSALNativeAuthNetworkStubs {

    static let tenantSubdomain = "test_tenant"

    static var authority: MSALCIAMAuthority {
        try! .init(
            url: .init(string: DEFAULT_TEST_AUTHORITY)!
        )
    }

    static var msidAuthority: MSIDCIAMAuthority {
        try! .init(
            url: .init(string: DEFAULT_TEST_AUTHORITY)!,
            validateFormat: false,
            rawTenant: tenantSubdomain,
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
    var expectedChallengeResponse: MSALNativeAuthSignInChallengeResponse?
    var expectedInitiateResponse: MSALNativeAuthSignInInitiateResponse?
    var expectedResponseError: Error?
    var initiateValidatedResponse: MSALNativeAuthSignInInitiateValidatedResponse = .error(.userNotFound(message: nil))
    var challengeValidatedResponse: MSALNativeAuthSignInChallengeValidatedResponse = .error(.expiredToken(message: nil))

    
    func validate(context: MSAL.MSALNativeAuthRequestContext, result: Result<MSAL.MSALNativeAuthSignInChallengeResponse, Error>) -> MSAL.MSALNativeAuthSignInChallengeValidatedResponse {
        checkConfAndContext(context)
        if case .success(let successChallengeResponse) = result, let expectedChallengeResponse = expectedChallengeResponse {
            XCTAssertEqual(successChallengeResponse.challengeType, expectedChallengeResponse.challengeType)
            XCTAssertEqual(successChallengeResponse.continuationToken, expectedChallengeResponse.continuationToken)
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
            XCTAssertEqual(successInitiateResponse.continuationToken, expectedInitiateResponse.continuationToken)
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

class MSALNativeAuthTokenResponseValidatorMock: MSALNativeAuthTokenResponseValidating {

    var expectedRequestContext: MSALNativeAuthRequestContext?
    var expectedConfiguration: MSIDConfiguration?
    var expectedTokenResponse: MSIDCIAMTokenResponse?
    var expectedResponseError: Error?
    var tokenValidatedResponse: MSALNativeAuthTokenValidatedResponse = .error(.generalError)

    func validate(context: MSAL.MSALNativeAuthRequestContext, msidConfiguration: MSIDConfiguration, result: Result<MSIDCIAMTokenResponse, Error>) -> MSAL.MSALNativeAuthTokenValidatedResponse {
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

    func validateAccount(with tokenResult: MSIDTokenResult, context: MSIDRequestContext, accountIdentifier: MSIDAccountIdentifier) throws -> Bool {
        true
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
            XCTAssertEqual(expectedCredentialToken, parameters.continuationToken)
        }
        return try returnMockedResult(throwingChallengeError)
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

class MSALNativeAuthTokenRequestProviderMock: MSALNativeAuthTokenRequestProviding {

    var throwingInitError: Error?
    var throwingChallengeError: Error?
    var throwingTokenError: Error?
    var result: MSIDHttpRequest?
    var expectedUsername: String?
    var expectedCredentialToken: String?
    var expectedContext: MSIDRequestContext?
    var expectedTokenParams: MSALNativeAuthTokenRequestParameters?

    func signInWithPassword(parameters: MSAL.MSALNativeAuthTokenRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedTokenParams = expectedTokenParams {
            XCTAssertEqual(expectedTokenParams.username, parameters.username)
            XCTAssertEqual(expectedTokenParams.continuationToken, parameters.continuationToken)
            XCTAssertEqual(expectedTokenParams.signInSLT, parameters.signInSLT)
            XCTAssertEqual(expectedTokenParams.grantType, parameters.grantType)
            XCTAssertEqual(expectedTokenParams.scope, parameters.scope)
            XCTAssertEqual(expectedTokenParams.password, parameters.password)
            XCTAssertEqual(expectedTokenParams.oobCode, parameters.oobCode)
            XCTAssertEqual(expectedTokenParams.context.correlationId(), parameters.context.correlationId())
        }
        return try returnMockedResult(throwingTokenError)
    }
    
    func refreshToken(parameters: MSAL.MSALNativeAuthTokenRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedTokenParams = expectedTokenParams {
            XCTAssertEqual(expectedTokenParams.username, parameters.username)
            XCTAssertEqual(expectedTokenParams.continuationToken, parameters.continuationToken)
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
