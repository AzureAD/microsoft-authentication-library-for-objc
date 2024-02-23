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

final class MSALNativeAuthRequestConfiguratorTests: XCTestCase {

    let telemetryProvider = MSALNativeAuthTelemetryProvider()
    let baseUrl = URL(string: DEFAULT_TEST_AUTHORITY)!
    var config: MSALNativeAuthConfiguration! = nil
    
    let context = MSALNativeAuthRequestContext(correlationId: UUID(uuidString: DEFAULT_TEST_UID)!)

    func test_signInInititate_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInInitiate),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignInInitiateRequestParameters(context: context,
                                                                   username: DEFAULT_TEST_ID_TOKEN_USERNAME)
        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .signIn(.initiate(params)),
                      request: request,
                      telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "challenge_type": "password",
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .signInInitiate)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signInChallenge_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.otp]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInChallenge),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignInChallengeRequestParameters(context: context,
                                                                    continuationToken: "Test Credential Token")
        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .signIn(.challenge(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "continuation_token": "Test Credential Token",
            "challenge_type": "otp"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .signInChallenge)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signInToken_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForToken(type: .signInWithPassword),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthTokenRequestParameters(context: context,
                                                          username: DEFAULT_TEST_ID_TOKEN_USERNAME,
                                                          continuationToken: "Test Continuation Token",
                                                          grantType: .password,
                                                          scope: "<scope-1>",
                                                          password: "password",
                                                          oobCode: "oob",
                                                          includeChallengeType: true,
                                                          refreshToken: nil)

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .token(.signInWithPassword(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "continuation_token": "Test Continuation Token",
            "grant_type": "password",
            "challenge_type": "password",
            "scope": "<scope-1>",
            "password": "password",
            "oob": "oob",
            "client_info" : "true"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .token)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signUpStartRequest_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpStart),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignUpStartRequestParameters(username: DEFAULT_TEST_ID_TOKEN_USERNAME,
                                                                password: "strong-password",
                                                                attributes: "<attribute1: value1>",
                                                                context: context)

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .signUp(.start(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "strong-password",
            "attributes": "<attribute1: value1>",
            "challenge_type": "password oob redirect"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .signUpStart)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signUpChallengeRequest_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpChallenge),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignUpChallengeRequestParameters(continuationToken: "<continuation-token>",
                                                                    context: context)

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .signUp(.challenge(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "continuation_token": "<continuation-token>",
            "challenge_type": "password oob redirect"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .signUpChallenge)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signUpContinueRequest_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpContinue),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignUpContinueRequestParameters(grantType: .oobCode,
                                                                   continuationToken: "<continuation-token>",
                                                                   password: "<strong-password>",
                                                                   oobCode: "0000",
                                                                   attributes: "<attributes>",
                                                                   context: context)

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .signUp(.continue(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "continuation_token": "<continuation-token>",
            "password": "<strong-password>",
            "oob": "0000",
            "grant_type": "oob",
            "attributes": "<attributes>"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .signUpContinue)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }


    func test_resetPasswordStart_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordStart),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordStartRequestParameters(context: context,
                                                                       username: DEFAULT_TEST_ID_TOKEN_USERNAME)

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .resetPassword(.start(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "challenge_type": "password oob redirect"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetPasswordStart)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_resetPasswordChallenge_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordChallenge),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordChallengeRequestParameters(context: context,
                                                                           continuationToken: "<continuation-token>")

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .resetPassword(.challenge(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "continuation_token": "<continuation-token>",
            "challenge_type": "password oob redirect"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetPasswordChallenge)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_resetPasswordContinue_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordContinue),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordContinueRequestParameters(context: context,
                                                                          continuationToken: "<continuation-token>",
                                                                          grantType: .oobCode,
                                                                          oobCode: "0000")

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .resetPassword(.continue(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "continuation_token": "<continuation-token>",
            "grant_type": "oob",
            "oob": "0000"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetPasswordContinue)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_resetPasswordSubmit_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordSubmit),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordSubmitRequestParameters(context: context,
                                                                        continuationToken: "<continuation-token>",
                                                                        newPassword:"new-password")

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .resetPassword(.submit(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "continuation_token": "<continuation-token>",
            "new_password": "new-password"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetPasswordSubmit)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_resetPasswordPollCompletion_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordPollCompletion),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordPollCompletionRequestParameters(context: context,
                                                                                continuationToken: "<continuation-token")

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .resetPassword(.pollCompletion(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "continuation_token": "<continuation-token"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetpasswordPollCompletion)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_refreshToken_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForToken(type: .refreshToken),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthTokenRequestParameters(context: context,
                                                          username: nil,
                                                          continuationToken: nil,
                                                          grantType: .refreshToken,
                                                          scope: "<scope-1>",
                                                          password: nil,
                                                          oobCode: nil,
                                                          includeChallengeType: false,
                                                          refreshToken: "refreshToken")

        let sut = MSALNativeAuthRequestConfigurator(config: config)
        try sut.configure(configuratorType: .token(.refreshToken(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id" : DEFAULT_TEST_CLIENT_ID,
            "grant_type" : "refresh_token",
            "scope" : "<scope-1>",
            "refresh_token" : "refreshToken",
            "client_info" : "true"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .token)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }


    private func checkUrlRequest(_ result: URLRequest?, endpoint: MSALNativeAuthEndpoint) {
        XCTAssertEqual(result?.httpMethod, MSALParameterStringForHttpMethod(.POST))

        let expectedUrl = URL(string: MSALNativeAuthNetworkStubs.authority.url.absoluteString + endpoint.rawValue)!
        XCTAssertEqual(result?.url, expectedUrl)
    }

    private func checkHeaders(request: MSIDHttpRequest) {
        let headers = request.urlRequest?.allHTTPHeaderFields!
        XCTAssertEqual(headers!["Accept"], "application/json")
        XCTAssertEqual(headers!["return-client-request-id"], "true")
        XCTAssertEqual(headers!["x-ms-PkeyAuth+"], "1.0")
        XCTAssertNotNil("client-request-id")
        XCTAssertNotNil("x-client-CPU")
        XCTAssertNotNil("x-client-SKU")
        XCTAssertNotNil("x-app-name")
        XCTAssertNotNil("x-app-ver")
        XCTAssertNotNil("x-client-OS")
        XCTAssertNotNil("x-client-Ver")
#if TARGET_OS_IPHONE
        XCTAssertNotNil("x-client-DM")
#endif
    }

    private func checkTelemetry(_ result: MSIDHttpRequestServerTelemetryHandling?, _ expected: MSALNativeAuthServerTelemetry) {

        guard let resultTelemetry = (result as? MSALNativeAuthServerTelemetry)?.currentRequestTelemetry else {
            return XCTFail()
        }

        let expectedTelemetry = expected.currentRequestTelemetry

        XCTAssertEqual(resultTelemetry.apiId, expectedTelemetry.apiId)
        XCTAssertEqual(resultTelemetry.operationType, expectedTelemetry.operationType)
    }
}
