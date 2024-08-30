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

class MSALNativeAuthRequestContextMock: MSALNativeAuthRequestContext {

    let mockCorrelationId: UUID
    var mockTelemetryRequestId = ""
    var mockLogComponent = ""
    var mockAppRequestMetadata: [AnyHashable: Any] = [:]

    init(correlationId: UUID = .init(uuidString: DEFAULT_TEST_UID)!) {
        self.mockCorrelationId = correlationId
    }

    override func correlationId() -> UUID {
        return mockCorrelationId
    }

    override func logComponent() -> String {
        return mockLogComponent
    }

    override func telemetryRequestId() -> String {
        return mockTelemetryRequestId
    }

    override func appRequestMetadata() -> [AnyHashable: Any] {
        return mockAppRequestMetadata
    }
}

class MSALNativeAuthSignInResponseValidatorMock: MSALNativeAuthSignInResponseValidating {

    var expectedRequestContext: MSALNativeAuthRequestContext?
    var expectedConfiguration: MSIDConfiguration?
    var expectedChallengeResponse: MSALNativeAuthSignInChallengeResponse?
    var expectedInitiateResponse: MSALNativeAuthSignInInitiateResponse?
    var expectedIntrospectResponse: MSALNativeAuthSignInIntrospectResponse?
    var expectedResponseError: Error?
    var initiateValidatedResponse: MSALNativeAuthSignInInitiateValidatedResponse = .error(.userNotFound(.init(
        error: .userNotFound))
    )
    var challengeValidatedResponse: MSALNativeAuthSignInChallengeValidatedResponse = .error(.expiredToken(.init(
        error: .expiredToken)
    ))
    var introspectValidatedResponse: MSALNativeAuthSignInIntrospectValidatedResponse = .error(.expiredToken(.init(
        error: .expiredToken)
    ))

    
    func validateChallenge(context: MSIDRequestContext, result: Result<MSAL.MSALNativeAuthSignInChallengeResponse, Error>) -> MSAL.MSALNativeAuthSignInChallengeValidatedResponse {
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
    
    func validateInitiate(context: MSIDRequestContext, result: Result<MSAL.MSALNativeAuthSignInInitiateResponse, Error>) -> MSAL.MSALNativeAuthSignInInitiateValidatedResponse {
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
    
    func validateIntrospect(context: any MSIDRequestContext, result: Result<MSAL.MSALNativeAuthSignInIntrospectResponse, any Error>) -> MSAL.MSALNativeAuthSignInIntrospectValidatedResponse {
        checkConfAndContext(context)
        if case .success(let successIntrospectResponse) = result, let expectedIntrospectResponse = expectedIntrospectResponse {
            XCTAssertEqual(successIntrospectResponse.challengeType, expectedIntrospectResponse.challengeType)
            XCTAssertEqual(successIntrospectResponse.continuationToken, expectedIntrospectResponse.continuationToken)
        }
        if case .failure(let introspectResponseError) = result, let expectedIntrospectResponseError = expectedResponseError {
            XCTAssertTrue(type(of: introspectResponseError) == type(of: expectedIntrospectResponseError))
            XCTAssertEqual(introspectResponseError.localizedDescription, expectedIntrospectResponseError.localizedDescription)
        }
        return introspectValidatedResponse
    }
    
    private func checkConfAndContext(_ context: MSIDRequestContext, config: MSIDConfiguration? = nil) {
        if let expectedRequestContext {
            XCTAssertEqual(expectedRequestContext.correlationId(), context.correlationId())
            XCTAssertEqual(expectedRequestContext.telemetryRequestId(), context.telemetryRequestId())
        }
        if let expectedConfiguration {
            XCTAssertEqual(expectedConfiguration, config)
        }
    }
}

class MSALNativeAuthTokenResponseValidatorMock: MSALNativeAuthTokenResponseValidating {

    var expectedRequestContext: MSALNativeAuthRequestContext?
    var expectedConfiguration: MSIDConfiguration?
    var expectedTokenResponse: MSIDCIAMTokenResponse?
    var expectedResponseError: Error?
    var tokenValidatedResponse: MSALNativeAuthTokenValidatedResponse = .error(.generalError(.init()))

    func validate(context: MSIDRequestContext, msidConfiguration: MSIDConfiguration, result: Result<MSIDCIAMTokenResponse, Error>) -> MSAL.MSALNativeAuthTokenValidatedResponse {
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

    private func checkConfAndContext(_ context: MSIDRequestContext, config: MSIDConfiguration? = nil) {
        if let expectedRequestContext {
            XCTAssertEqual(expectedRequestContext.correlationId(), context.correlationId())
            XCTAssertEqual(expectedRequestContext.telemetryRequestId(), context.telemetryRequestId())
        }
        if let expectedConfiguration {
            XCTAssertEqual(expectedConfiguration, config)
        }
    }
}

class MSALNativeAuthSignInRequestProviderMock: MSALNativeAuthSignInRequestProviding {
    
    var throwingInitError: Error?
    var throwingChallengeError: Error?
    var throwingIntrospectError: Error?
    private var requestInitiate: MSIDHttpRequest?
    private var requestChallenge: MSIDHttpRequest?
    private var requestIntrospect: MSIDHttpRequest?
    
    var expectedContext: MSIDRequestContext?
    var expectedUsername: String?
    var expectedMFAAuthMethodId: String?
    var expectedContinuationToken: String?
    
    func mockInitiateRequestFunc(_ request: MSIDHttpRequest?, throwError: Error? = nil) {
        self.requestInitiate = request
        self.throwingInitError = throwError
    }
    
    func inititate(parameters: MSAL.MSALNativeAuthSignInInitiateRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedUsername {
            XCTAssertEqual(expectedUsername, parameters.username)
        }
        if let requestInitiate {
            return requestInitiate
        } else if throwingInitError != nil {
            throw throwingInitError!
        } else {
            fatalError("Make sure to use mockInitiateRequestFunc()")
        }
    }
    
    func mockChallengeRequestFunc(_ request: MSIDHttpRequest?, throwError: Error? = nil) {
        self.requestChallenge = request
        self.throwingChallengeError = throwError
    }
    
    func challenge(parameters: MSAL.MSALNativeAuthSignInChallengeRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        XCTAssertEqual(parameters.mfaAuthMethodId, expectedMFAAuthMethodId)
        if let expectedContinuationToken {
            XCTAssertEqual(expectedContinuationToken, parameters.continuationToken)
        }
        if let requestChallenge {
            return requestChallenge
        } else if throwingChallengeError != nil {
            throw throwingChallengeError!
        } else {
            fatalError("Make sure to use mockChallengeRequestFunc()")
        }
    }

    func mockIntrospectRequestFunc(_ request: MSIDHttpRequest?, throwError: Error? = nil) {
        self.requestIntrospect = request
        self.throwingIntrospectError = throwError
    }

    func introspect(parameters: MSAL.MSALNativeAuthSignInIntrospectRequestParameters, context: any MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedContinuationToken {
            XCTAssertEqual(expectedContinuationToken, parameters.continuationToken)
        }
        if let requestIntrospect {
            return requestIntrospect
        } else if throwingIntrospectError != nil {
            throw throwingIntrospectError!
        } else {
            fatalError("Make sure to use mockIntrospectRequestFunc()")
        }
    }
    
    fileprivate func checkContext(_ context: MSIDRequestContext) {
        if let expectedContext {
            XCTAssertEqual(expectedContext.correlationId(), context.correlationId())
        }
    }
}

class MSALNativeAuthTokenRequestProviderMock: MSALNativeAuthTokenRequestProviding {    
        
    var requestToken: MSIDHttpRequest?
    var requestRefreshToken: MSIDHttpRequest?
    var throwingTokenError: Error?
    var throwingRefreshTokenError: Error?
    var expectedUsername: String?
    var expectedCredentialToken: String?
    var expectedContext: MSIDRequestContext?
    var expectedTokenParams: MSALNativeAuthTokenRequestParameters?

    func mockRequestTokenFunc(_ request: MSIDHttpRequest?, throwError: Error? = nil) {
        self.requestToken = request
        self.throwingTokenError = throwError
    }
    
    func signInWithPassword(parameters: MSAL.MSALNativeAuthTokenRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedTokenParams {
            XCTAssertEqual(expectedTokenParams.username, parameters.username)
            XCTAssertEqual(expectedTokenParams.continuationToken, parameters.continuationToken)
            XCTAssertEqual(expectedTokenParams.continuationToken, parameters.continuationToken)
            XCTAssertEqual(expectedTokenParams.grantType, parameters.grantType)
            XCTAssertEqual(expectedTokenParams.scope, parameters.scope)
            XCTAssertEqual(expectedTokenParams.password, parameters.password)
            XCTAssertEqual(expectedTokenParams.oobCode, parameters.oobCode)
            XCTAssertEqual(expectedTokenParams.context.correlationId(), parameters.context.correlationId())
        }
        if let requestToken {
            return requestToken
        } else if throwingTokenError != nil {
            throw throwingTokenError!
        } else {
            fatalError("Make sure to use mockRequestTokenFunc()")
        }
    }
    
    func mockRequestRefreshTokenFunc(_ request: MSIDHttpRequest?, throwError: Error? = nil) {
        self.requestRefreshToken = request
        self.throwingRefreshTokenError = throwError
    }
    
    func refreshToken(parameters: MSAL.MSALNativeAuthTokenRequestParameters, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        checkContext(context)
        if let expectedTokenParams {
            XCTAssertEqual(expectedTokenParams.username, parameters.username)
            XCTAssertEqual(expectedTokenParams.continuationToken, parameters.continuationToken)
            XCTAssertEqual(expectedTokenParams.continuationToken, parameters.continuationToken)
            XCTAssertEqual(expectedTokenParams.grantType, parameters.grantType)
            XCTAssertEqual(expectedTokenParams.scope, parameters.scope)
            XCTAssertEqual(expectedTokenParams.password, parameters.password)
            XCTAssertEqual(expectedTokenParams.oobCode, parameters.oobCode)
            XCTAssertEqual(expectedTokenParams.context.correlationId(), parameters.context.correlationId())
        }
        if let requestRefreshToken {
            return requestRefreshToken
        } else if throwingRefreshTokenError != nil {
            throw throwingRefreshTokenError!
        } else {
            fatalError("Make sure to use mockRequestRefreshTokenFunc()")
        }
    }

    fileprivate func checkContext(_ context: MSIDRequestContext) {
        if let expectedContext {
            XCTAssertEqual(expectedContext.correlationId(), context.correlationId())
        }
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
