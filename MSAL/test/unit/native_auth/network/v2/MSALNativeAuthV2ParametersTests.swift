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

final class MSALNativeAuthV2ParametersTests: XCTestCase {

    private var context: MSALNativeAuthRequestContext!
    private let resolver = MSALNativeAuthV2HrefURLResolver(
        authorityURL: URL(string: "https://login.microsoftonline.com/common")!,
        dataCenter: nil
    )

    override func setUp() {
        super.setUp()
        context = MSALNativeAuthRequestContextMock()
    }

    // MARK: - EntryParameters

    func test_entryParameters_body_url_andMetadata() throws {
        let href = "/tenant/api/v0.1/auth/methods/signUp"
        let sut = MSALNativeAuthV2EntryParameters(
            context: context,
            target: .href(href),
            apiId: .telemetryApiIdV2SignUpStart,
            operationType: MSALNativeAuthV2OperationType.signUpStart.rawValue,
            username: "user@contoso.com",
            continuationToken: "CT"
        )

        XCTAssertEqual(sut.apiId, .telemetryApiIdV2SignUpStart)
        XCTAssertEqual(sut.operationType, MSALNativeAuthV2OperationType.signUpStart.rawValue)
        XCTAssertEqual(sut.encoding, .json)
        XCTAssertEqual(sut.httpMethod, "POST")
        XCTAssertFalse(sut.expectsRawJSONResponse)
        XCTAssertEqual(sut.body as? [String: String], ["username": "user@contoso.com", "continuationToken": "CT"])
        XCTAssertEqual(try sut.url(resolver: resolver), try resolver.url(forHref: href))
    }

    func test_entryParameters_whenTargetIsEndpoint_resolvesEndpointUrl() throws {
        let sut = MSALNativeAuthV2EntryParameters(
            context: context,
            target: .endpoint(.authorizeChallenge),
            apiId: .telemetryApiIdV2SignInWithCodeStart,
            operationType: MSALNativeAuthV2OperationType.signInStart.rawValue,
            username: "user@contoso.com",
            continuationToken: "CT"
        )

        XCTAssertEqual(try sut.url(resolver: resolver), try resolver.url(for: .authorizeChallenge))
    }

    // MARK: - HrefParameters

    func test_hrefParameters_postWithOtp_body_url_andMetadata() throws {
        let href = "/tenant/api/v0.1/auth/methods/email/3f7/verify"
        let sut = MSALNativeAuthV2HrefParameters(
            context: context,
            href: href,
            httpMethod: "POST",
            apiId: .telemetryApiIdV2SignInSubmitCode,
            operationType: MSALNativeAuthV2OperationType.verify.rawValue,
            requestBody: MSALNativeAuthV2RequestBody(continuationToken: "CT", otp: "1234")
        )

        XCTAssertEqual(sut.apiId, .telemetryApiIdV2SignInSubmitCode)
        XCTAssertEqual(sut.operationType, MSALNativeAuthV2OperationType.verify.rawValue)
        XCTAssertEqual(sut.encoding, .json)
        XCTAssertEqual(sut.httpMethod, "POST")
        XCTAssertFalse(sut.expectsRawJSONResponse)
        XCTAssertEqual(sut.body as? [String: String], ["continuationToken": "CT", "otp": "1234"])
        XCTAssertEqual(try sut.url(resolver: resolver), try resolver.url(forHref: href))
    }

    func test_hrefParameters_putPassesHttpMethodThrough() throws {
        let sut = MSALNativeAuthV2HrefParameters(
            context: context,
            href: "/tenant/api/v0.1/auth/methods/password/update",
            httpMethod: "PUT",
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            operationType: MSALNativeAuthV2OperationType.updatePassword.rawValue,
            requestBody: MSALNativeAuthV2RequestBody(continuationToken: "CT", newPassword: "newPass")
        )

        XCTAssertEqual(sut.httpMethod, "PUT")
        XCTAssertEqual(sut.body as? [String: String], ["continuationToken": "CT", "newPassword": "newPass"])
    }

    func test_hrefParameters_withAttributes_body() throws {
        let sut = MSALNativeAuthV2HrefParameters(
            context: context,
            href: "/tenant/api/v0.1/auth/methods/attributes",
            httpMethod: "POST",
            apiId: .telemetryApiIdV2SignUpSubmitAttributes,
            operationType: MSALNativeAuthV2OperationType.submitAttributes.rawValue,
            requestBody: MSALNativeAuthV2RequestBody(continuationToken: "CT", attributes: ["city": "Redmond"])
        )

        XCTAssertEqual(sut.body["continuationToken"] as? String, "CT")
        XCTAssertEqual(sut.body["attributes"] as? [String: String], ["city": "Redmond"])
    }

    // MARK: - AuthorizeChallengeStartParameters

    func test_authorizeChallengeStartParameters_body_url_andMetadata() throws {
        let sut = MSALNativeAuthV2AuthorizeChallengeStartParameters(
            context: context,
            clientId: "client-id",
            apiId: .telemetryApiIdV2SignInWithCodeStart
        )

        XCTAssertEqual(sut.apiId, .telemetryApiIdV2SignInWithCodeStart)
        XCTAssertEqual(sut.operationType, MSALNativeAuthV2OperationType.authorizeChallengeStart.rawValue)
        XCTAssertEqual(sut.encoding, .wwwFormUrlEncoded)
        XCTAssertEqual(sut.httpMethod, "POST")
        XCTAssertFalse(sut.expectsRawJSONResponse)
        XCTAssertEqual(sut.body as? [String: String], ["client_id": "client-id"])
        XCTAssertEqual(try sut.url(resolver: resolver), try resolver.url(for: .authorizeChallenge))
    }

    // MARK: - AuthorizeChallengeContinueParameters

    func test_authorizeChallengeContinueParameters_body_url_andMetadata() throws {
        let sut = MSALNativeAuthV2AuthorizeChallengeContinueParameters(
            context: context,
            continuationToken: "CT",
            apiId: .telemetryApiIdV2SignInSubmitCode
        )

        XCTAssertEqual(sut.apiId, .telemetryApiIdV2SignInSubmitCode)
        XCTAssertEqual(sut.operationType, MSALNativeAuthV2OperationType.authorizeChallengeContinue.rawValue)
        XCTAssertEqual(sut.encoding, .wwwFormUrlEncoded)
        XCTAssertEqual(sut.body as? [String: String], ["continuation_token": "CT"])
        XCTAssertEqual(try sut.url(resolver: resolver), try resolver.url(for: .authorizeChallenge))
    }

    // MARK: - TokenParameters

    func test_tokenParameters_withScopes_body_url_andMetadata() throws {
        let sut = MSALNativeAuthV2TokenParameters(
            context: context,
            clientId: "client-id",
            code: "auth-code",
            scopes: ["scope1", "scope2"],
            apiId: .telemetryApiIdV2SignInSubmitCode
        )

        XCTAssertEqual(sut.apiId, .telemetryApiIdV2SignInSubmitCode)
        XCTAssertEqual(sut.operationType, MSALNativeAuthV2OperationType.token.rawValue)
        XCTAssertEqual(sut.encoding, .wwwFormUrlEncoded)
        XCTAssertTrue(sut.expectsRawJSONResponse)
        XCTAssertEqual(sut.body as? [String: String], [
            "grant_type": "authorization_code",
            "code": "auth-code",
            "client_id": "client-id",
            "client_info": "true",
            "scope": "scope1 scope2"
        ])
        XCTAssertEqual(try sut.url(resolver: resolver), try resolver.url(for: .token))
    }

    func test_tokenParameters_withoutScopes_omitsScope() throws {
        let sut = MSALNativeAuthV2TokenParameters(
            context: context,
            clientId: "client-id",
            code: "auth-code",
            scopes: [],
            apiId: .telemetryApiIdV2SignInSubmitCode
        )

        XCTAssertEqual(sut.body as? [String: String], [
            "grant_type": "authorization_code",
            "code": "auth-code",
            "client_id": "client-id",
            "client_info": "true"
        ])
    }
}
