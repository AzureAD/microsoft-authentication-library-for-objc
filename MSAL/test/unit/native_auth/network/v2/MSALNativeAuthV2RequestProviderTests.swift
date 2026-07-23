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

final class MSALNativeAuthV2RequestProviderTests: XCTestCase {

    private var sut: MSALNativeAuthV2RequestProvider!
    private var resolver: MSALNativeAuthV2HrefURLResolver!
    private var context: MSALNativeAuthRequestContext!

    private let href = "/tenant/api/v0.1/auth/methods/email/3f7/verify"

    override func setUp() {
        super.setUp()
        sut = MSALNativeAuthV2RequestProvider(config: MSALNativeAuthConfigStubs.configuration)
        resolver = MSALNativeAuthV2HrefURLResolver(config: MSALNativeAuthConfigStubs.configuration)
        context = MSALNativeAuthRequestContextMock()
    }

    // MARK: - Helpers

    private func apiId(of request: MSIDHttpRequest) -> MSALNativeAuthTelemetryApiId? {
        return (request.serverTelemetry as? MSALNativeAuthServerTelemetry)?.currentRequestTelemetry.apiId
    }

    // MARK: - Entry requests

    func test_signUpStart_configuresHrefRequestAndThreadsApiId() throws {
        let request = try sut.signUpStart(
            username: "user@contoso.com",
            continuationToken: "CT",
            href: href,
            apiId: .telemetryApiIdV2SignUpStart,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignUpStart)
        XCTAssertTrue(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
    }

    func test_signInStart_threadsApiId() throws {
        let request = try sut.signInStart(
            username: "user@contoso.com",
            continuationToken: "CT",
            href: href,
            apiId: .telemetryApiIdV2SignInWithCodeStart,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignInWithCodeStart)
    }

    func test_resetPasswordStart_threadsApiId() throws {
        let request = try sut.resetPasswordStart(
            username: "user@contoso.com",
            continuationToken: "CT",
            href: href,
            apiId: .telemetryApiIdV2ResetPasswordStart,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordStart)
    }

    // MARK: - HAL follow-up requests

    func test_submitPassword_threadsApiId() throws {
        let request = try sut.submitPassword(
            href: href,
            password: "pass",
            continuationToken: "CT",
            apiId: .telemetryApiIdV2SignInSubmitPassword,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignInSubmitPassword)
    }

    func test_submitCode_threadsApiId() throws {
        let request = try sut.submitCode(
            href: href,
            code: "1234",
            continuationToken: "CT",
            apiId: .telemetryApiIdV2SignInSubmitCode,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignInSubmitCode)
    }

    func test_submitAttributes_threadsApiId() throws {
        let request = try sut.submitAttributes(
            href: href,
            attributes: ["city": "Redmond"],
            continuationToken: "CT",
            apiId: .telemetryApiIdV2SignUpSubmitAttributes,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignUpSubmitAttributes)
    }

    func test_registerMethod_threadsApiId() throws {
        let request = try sut.registerMethod(
            href: href,
            target: "email",
            continuationToken: "CT",
            apiId: .telemetryApiIdV2JITChallenge,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2JITChallenge)
    }

    func test_challenge_threadsApiId() throws {
        let request = try sut.challenge(
            href: href,
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordResendCode,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordResendCode)
    }

    func test_verify_threadsApiId() throws {
        let request = try sut.verify(
            href: href,
            otp: "1234",
            continuationToken: "CT",
            apiId: .telemetryApiIdV2MFASubmitChallenge,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2MFASubmitChallenge)
    }

    func test_updatePassword_usesPutAndThreadsApiId() throws {
        let request = try sut.updatePassword(
            href: href,
            newPassword: "newPass",
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "PUT")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
    }

    func test_poll_threadsApiId() throws {
        let request = try sut.poll(
            href: href,
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
    }

    // MARK: - Fixed-endpoint requests

    func test_authorizeChallengeStart_usesAuthorizeChallengeEndpointAndThreadsApiId() throws {
        let request = try sut.authorizeChallengeStart(
            apiId: .telemetryApiIdV2SignInWithPasswordStart,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .authorizeChallenge))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignInWithPasswordStart)
    }

    func test_authorizeChallengeContinue_usesAuthorizeChallengeEndpointAndThreadsApiId() throws {
        let request = try sut.authorizeChallengeContinue(
            continuationToken: "CT",
            apiId: .telemetryApiIdV2SignInWithCodeStart,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .authorizeChallenge))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignInWithCodeStart)
    }

    func test_token_usesTokenEndpointAndKeepsRawJSONSerializer() throws {
        let request = try sut.token(
            code: "auth-code",
            scopes: ["scope1"],
            apiId: .telemetryApiIdV2SignInSubmitCode,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .token))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignInSubmitCode)
        XCTAssertFalse(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
    }
}
