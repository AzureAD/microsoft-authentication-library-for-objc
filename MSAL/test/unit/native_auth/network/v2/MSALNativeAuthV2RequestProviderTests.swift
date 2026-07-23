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

    func test_resetPasswordStart_threadsApiId() throws {
        let request = try sut.resetPasswordStart(
            username: "user@contoso.com",
            continuationToken: "CT",
            href: href,
            apiId: .telemetryApiIdV2ResetPasswordStart,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordStart)
        XCTAssertTrue(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
    }

    // MARK: - HAL follow-up requests

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
            apiId: .telemetryApiIdV2ResetPasswordSubmitCode,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmitCode)
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
            apiId: .telemetryApiIdV2ResetPasswordStart,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .authorizeChallenge))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordStart)
    }

    func test_authorizeChallengeContinue_usesAuthorizeChallengeEndpointAndThreadsApiId() throws {
        let request = try sut.authorizeChallengeContinue(
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .authorizeChallenge))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
    }

    func test_token_usesTokenEndpointAndKeepsRawJSONSerializer() throws {
        let request = try sut.token(
            code: "auth-code",
            scopes: ["scope1"],
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        )

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .token))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
        XCTAssertFalse(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
    }
}
