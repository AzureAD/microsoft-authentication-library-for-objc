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

final class MSALNativeAuthRequestConfiguratorTests: XCTestCase {

    let telemetryProvider = MSALNativeAuthTelemetryProvider()
    let baseUrl = URL(string: DEFAULT_TEST_AUTHORITY)!
    var config: MSALNativeAuthConfiguration! = nil
    
    let context = MSALNativeAuthRequestContext(
        correlationId: .init(
            UUID(uuidString: DEFAULT_TEST_UID)!
        )
    )

    func test_signInInititate_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: [.password]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInInitiate),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignInInitiateRequestParameters(config: config,
                                                                   context: context,
                                                                   username: DEFAULT_TEST_ID_TOKEN_USERNAME)
        let sut = MSALNativeAuthRequestConfigurator()
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
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: [.otp]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInChallenge),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignInChallengeRequestParameters(config: config,
                                                                    context: context,
                                                                    credentialToken: "Test Credential Token",
                                                                    challengeTarget: "phone")
        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .signIn(.challenge(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "credential_token": "Test Credential Token",
            "challenge_type": "otp",
            "challenge_target_key": "phone"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .signInChallenge)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signInToken_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: [.password]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignIn(type: .signInToken),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignInTokenRequestParameters(config: config,
                                                                context: context,
                                                                username: DEFAULT_TEST_ID_TOKEN_USERNAME,
                                                                credentialToken: "Test Credential Token",
                                                                signInSLT: "Test SignIn SLT",
                                                                grantType: .password,
                                                                scope: "<scope-1>",
                                                                password: "password",
                                                                oobCode: "oob")

        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .signIn(.token(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "credential_token": "Test Credential Token",
            "signin_slt": "Test SignIn SLT",
            "grant_type": "password",
            "challenge_type": "password",
            "scope": "<scope-1>",
            "password": "password",
            "oob": "oob"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .token)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signUpStartRequest_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpStart),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignUpStartRequestParameters(config: config,
                                                                username: DEFAULT_TEST_ID_TOKEN_USERNAME,
                                                                password: "strong-password",
                                                                attributes: "<attribute1: value1>",
                                                                context: context)

        let sut = MSALNativeAuthRequestConfigurator()
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
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpChallenge),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignUpChallengeRequestParameters(config: config,
                                                                    signUpToken: "<sign-up-token>",
                                                                    context: context)

        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .signUp(.challenge(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "signup_token": "<sign-up-token>",
            "challenge_type": "password oob redirect"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .signUpChallenge)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_signUpContinueRequest_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForSignUp(type: .signUpContinue),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthSignUpContinueRequestParameters(config: config,
                                                                   grantType: .oobCode,
                                                                   signUpToken: "<sign-up-token>",
                                                                   password: "<strong-password>",
                                                                   oobCode: "0000",
                                                                   attributes: "<attributes>",
                                                                   context: context)

        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .signUp(.continue(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "signup_token": "<sign-up-token>",
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
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordStart),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordStartRequestParameters(config: config,
                                                                       context: context,
                                                                       username: DEFAULT_TEST_ID_TOKEN_USERNAME)

        let sut = MSALNativeAuthRequestConfigurator()
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
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: [.password, .oob, .redirect]))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordChallenge),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordChallengeRequestParameters(config: config,
                                                                           context: context,
                                                                           passwordResetToken: "<password-reset-token>",
                                                                           challengeTarget: "phone")

        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .resetPassword(.challenge(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "password_reset_token": "<password-reset-token>",
            "challenge_type": "password oob redirect",
            "challenge_target_key": "phone"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetPasswordChallenge)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_resetPasswordContinue_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordContinue),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordContinueRequestParameters(config: config,
                                                                          context: context,
                                                                          passwordResetToken: "<password-reset-token>",
                                                                          grantType: .oobCode,
                                                                          oobCode: "0000")

        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .resetPassword(.continue(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "password_reset_token": "<password-reset-token>",
            "grant_type": "oob",
            "oob": "0000"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetPasswordContinue)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_resetPasswordSubmit_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordSubmit),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordSubmitRequestParameters(config: config,
                                                                        context: context,
                                                                        passwordSubmitToken: "<password-submit-token>",
                                                                        newPassword:"new-password")

        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .resetPassword(.submit(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "password_submit_token": "<password-submit-token>",
            "new_password": "new-password"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetPasswordSubmit)
        checkHeaders(request: request)
        checkTelemetry(request.serverTelemetry, telemetry)
    }

    func test_resetPasswordPollCompletion_getsConfiguredSuccessfully() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALAADAuthority(url: baseUrl, rawTenant: "test_tenant"), challengeTypes: []))
        let telemetry = MSALNativeAuthServerTelemetry(
            currentRequestTelemetry: telemetryProvider.telemetryForResetPassword(type: .resetPasswordPollCompletion),
            context: context
        )

        let request = MSIDHttpRequest()
        let params = MSALNativeAuthResetPasswordPollCompletionRequestParameters(config: config,
                                                                        context: context,
                                                                        passwordResetToken: "<password-reset-token")

        let sut = MSALNativeAuthRequestConfigurator()
        try sut.configure(configuratorType: .resetPassword(.pollCompletion(params)),
                          request: request,
                          telemetryProvider: telemetryProvider)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "password_reset_token": "<password-reset-token"
        ]

        XCTAssertEqual(request.parameters, expectedBodyParams)
        checkUrlRequest(request.urlRequest, endpoint: .resetpasswordPollCompletion)
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
