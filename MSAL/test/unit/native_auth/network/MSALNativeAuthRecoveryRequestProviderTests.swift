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

final class MSALNativeAuthRecoveryRequestProviderTests: XCTestCase {
    private let context = MSALNativeAuthRequestContext(correlationId: UUID())
    private let telemetry = MSALNativeAuthTelemetryProvider()
    private let token = "test-continuation-token"
    private let username = "test@example.com"

    func test_signInRequests_preserveIdentityContinuationAndSelectedMethod() throws {
        let provider = MSALNativeAuthSignInRequestProvider(requestConfigurator: configurator())
        let initiate = try provider.inititate(parameters: .init(context: context, username: username), context: context)
        try assertRequest(
            initiate,
            endpoint: .signInInitiate,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "username": username, "challenge_type": "password redirect"],
            telemetry: telemetry.telemetryForSignIn(type: .signInInitiate).telemetryString()
        )

        let methods: [String?] = [nil, "selected-method"]
        for method in methods {
            let challenge = try provider.challenge(
                parameters: .init(context: context, mfaAuthMethodId: method, continuationToken: token),
                context: context
            )
            var body = ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token, "challenge_type": "password redirect"]
            body["id"] = method
            try assertRequest(
                challenge, endpoint: .signInChallenge, body: body,
                telemetry: telemetry.telemetryForSignIn(type: .signInChallenge).telemetryString()
            )
        }

        let introspect = try provider.introspect(parameters: .init(context: context, continuationToken: token), context: context)
        try assertRequest(
            introspect, endpoint: .signInIntrospect,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token],
            telemetry: telemetry.telemetryForSignIn(type: .signInIntrospect).telemetryString()
        )
    }

    func test_registrationRequests_preserveMethodContactAndVerificationCode() throws {
        let provider = MSALNativeAuthJITRequestProvider(requestConfigurator: configurator())
        let introspect = try provider.introspect(parameters: .init(context: context, continuationToken: token), context: context)
        try assertRequest(
            introspect, endpoint: .jitIntrospect,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token],
            telemetry: telemetry.telemetryForRegister(type: .jitIntrospect).telemetryString()
        )

        let method = MSALAuthMethod(id: "email-method", challengeType: "oob", channelTargetType: .init(value: "email"), loginHint: nil)
        let challenge = try provider.challenge(
            parameters: .init(context: context, continuationToken: token, authMethod: method, verificationContact: username),
            context: context
        )
        try assertRequest(
            challenge, endpoint: .jitChallenge,
            body: [
                "client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token,
                "challenge_type": "oob", "challenge_target": username, "challenge_channel": "email"
            ],
            telemetry: telemetry.telemetryForRegister(type: .jitChallenge).telemetryString()
        )

        let continuation = try provider.continue(
            parameters: .init(context: context, grantType: .oobCode, continuationToken: token, oobCode: "123456"),
            context: context
        )
        try assertRequest(
            continuation, endpoint: .jitContinue,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token, "grant_type": "oob", "oob": "123456"],
            telemetry: telemetry.telemetryForRegister(type: .jitContinue).telemetryString()
        )
    }

    func test_passwordRecoveryRequests_preserveEveryStepWithoutLeakingPriorCredentials() throws {
        let provider = MSALNativeAuthResetPasswordRequestProvider(requestConfigurator: configurator())
        let start = try provider.start(parameters: .init(username: username, context: context))
        try assertRequest(
            start, endpoint: .resetPasswordStart,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "username": username, "challenge_type": "password redirect"],
            telemetry: telemetry.telemetryForResetPassword(type: .resetPasswordStart).telemetryString()
        )
        let challenge = try provider.challenge(token: token, context: context)
        try assertRequest(
            challenge, endpoint: .resetPasswordChallenge,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token, "challenge_type": "password redirect"],
            telemetry: telemetry.telemetryForResetPassword(type: .resetPasswordChallenge).telemetryString()
        )
        let continuation = try provider.continue(
            parameters: .init(context: context, continuationToken: token, grantType: .oobCode, oobCode: "654321")
        )
        try assertRequest(
            continuation, endpoint: .resetPasswordContinue,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token, "grant_type": "oob", "oob": "654321"],
            telemetry: telemetry.telemetryForResetPassword(type: .resetPasswordContinue).telemetryString()
        )
        let submit = try provider.submit(parameters: .init(context: context, continuationToken: token, newPassword: "test-new-password"))
        try assertRequest(
            submit, endpoint: .resetPasswordSubmit,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token, "new_password": "test-new-password"],
            telemetry: telemetry.telemetryForResetPassword(type: .resetPasswordSubmit).telemetryString()
        )
        let poll = try provider.pollCompletion(parameters: .init(context: context, continuationToken: token))
        try assertRequest(
            poll, endpoint: .resetpasswordPollCompletion,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "continuation_token": token],
            telemetry: telemetry.telemetryForResetPassword(type: .resetPasswordPollCompletion).telemetryString()
        )
    }

    func test_tokenRequests_keepPasswordAndRefreshCredentialsInTheirOwnGrant() throws {
        let provider = MSALNativeAuthTokenRequestProvider(requestConfigurator: configurator())
        let password = try provider.signInWithPassword(
            parameters: .init(
                context: context, username: username, continuationToken: token, grantType: .password,
                scope: "openid scope", password: "test-password", oobCode: nil, includeChallengeType: true,
                refreshToken: nil, claimsRequestJson: "{\"access_token\":{}}"
            ),
            context: context
        )
        try assertRequest(
            password, endpoint: .token,
            body: [
                "client_id": DEFAULT_TEST_CLIENT_ID, "username": username, "continuation_token": token,
                "grant_type": "password", "scope": "openid scope", "password": "test-password",
                "client_info": "true", "challenge_type": "password redirect", "claims": "{\"access_token\":{}}"
            ],
            telemetry: telemetry.telemetryForToken(type: .signInWithPassword).telemetryString()
        )
        let refresh = try provider.refreshToken(
            parameters: .init(
                context: context, username: nil, continuationToken: nil, grantType: .refreshToken,
                scope: "scope", password: nil, oobCode: nil, includeChallengeType: false,
                refreshToken: "test-refresh-token", claimsRequestJson: nil
            ),
            context: context
        )
        try assertRequest(
            refresh, endpoint: .token,
            body: ["client_id": DEFAULT_TEST_CLIENT_ID, "grant_type": "refresh_token", "scope": "scope",
                   "client_info": "true", "refresh_token": "test-refresh-token"],
            telemetry: telemetry.telemetryForToken(type: .refreshToken).telemetryString()
        )
    }

    func test_requestConstruction_propagatesConfigurationFailure() {
        let failing = FailingConfigurator(config: MSALNativeAuthConfigStubs.configuration)
        let signIn = MSALNativeAuthSignInRequestProvider(requestConfigurator: failing)
        let registration = MSALNativeAuthJITRequestProvider(requestConfigurator: failing)
        let recovery = MSALNativeAuthResetPasswordRequestProvider(requestConfigurator: failing)
        let requests: [() throws -> MSIDHttpRequest] = [
            { try signIn.inititate(parameters: .init(context: self.context, username: self.username), context: self.context) },
            { try signIn.introspect(parameters: .init(context: self.context, continuationToken: self.token), context: self.context) },
            { try registration.introspect(parameters: .init(context: self.context, continuationToken: self.token), context: self.context) },
            { try recovery.start(parameters: .init(username: self.username, context: self.context)) },
            { try recovery.challenge(token: self.token, context: self.context) },
            { try recovery.pollCompletion(parameters: .init(context: self.context, continuationToken: self.token)) }
        ]
        for request in requests {
            XCTAssertThrowsError(try request()) { error in
                XCTAssertEqual(error as? ConfigurationFailure, .expected)
            }
        }
    }

    private func configurator() -> MSALNativeAuthRequestConfigurator {
        MSALNativeAuthRequestConfigurator(config: MSALNativeAuthConfigStubs.configuration)
    }

    private func assertRequest(
        _ request: MSIDHttpRequest,
        endpoint: MSALNativeAuthEndpoint,
        body: [String: String],
        telemetry expectedTelemetry: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let urlRequest = try XCTUnwrap(request.urlRequest, file: file, line: line)
        XCTAssertEqual(request.parameters, body, file: file, line: line)
        XCTAssertEqual(urlRequest.httpMethod, "POST", file: file, line: line)
        let authority = MSALNativeAuthConfigStubs.configuration.authority.url.absoluteString
        XCTAssertEqual(urlRequest.url?.absoluteString, authority + endpoint.rawValue, file: file, line: line)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Accept"), "application/json", file: file, line: line)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "return-client-request-id"), "true", file: file, line: line)
        let requestContext = try XCTUnwrap(request.context, file: file, line: line)
        XCTAssertEqual(requestContext.correlationId(), context.correlationId(), file: file, line: line)
        let serverTelemetry = try XCTUnwrap(request.serverTelemetry as? MSALNativeAuthServerTelemetry, file: file, line: line)
        XCTAssertEqual(serverTelemetry.context.correlationId(), context.correlationId(), file: file, line: line)
        XCTAssertEqual(serverTelemetry.currentRequestTelemetry.telemetryString(), expectedTelemetry, file: file, line: line)
    }

    private enum ConfigurationFailure: Error {
        case expected
    }

    private final class FailingConfigurator: MSALNativeAuthRequestConfigurator {
        override func configure(
            configuratorType: MSALNativeAuthRequestConfiguratorType,
            request: MSIDHttpRequest,
            telemetryProvider: MSALNativeAuthTelemetryProviding
        ) throws {
            throw ConfigurationFailure.expected
        }
    }
}
