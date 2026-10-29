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
        sut = MSALNativeAuthV2RequestProvider(
            config: MSALNativeAuthConfigStubs.configuration,
            serverTelemetryProvider: MSALNativeAuthServerTelemetryProviderFake()
        )
        resolver = MSALNativeAuthV2HrefURLResolver(config: MSALNativeAuthConfigStubs.configuration)
        context = MSALNativeAuthRequestContextMock()
    }

    // MARK: - Helpers

    private func apiId(of request: MSIDHttpRequest) -> MSALNativeAuthTelemetryApiId? {
        return (request.serverTelemetry as? MSALNativeAuthServerTelemetryFake)?.currentRequestTelemetry.apiId
    }

    func test_requests_createSeparateInjectedTelemetryWithRequestMetadata() throws {
        let enrollRequest = try XCTUnwrap(sut.enroll(
            href: href,
            verificationContact: "+15555550100",
            channelType: .sms,
            continuationToken: "ct-enroll",
            apiId: .telemetryApiIdV2JITChallenge,
            context: context
        ) as? MSIDHttpRequest)
        let activateRequest = try XCTUnwrap(sut.activate(
            href: href,
            otp: "123456",
            continuationToken: "ct-activate",
            apiId: .telemetryApiIdV2JITChallenge,
            context: context
        ) as? MSIDHttpRequest)

        let enrollTelemetry = try XCTUnwrap(enrollRequest.serverTelemetry as? MSALNativeAuthServerTelemetryFake)
        let activateTelemetry = try XCTUnwrap(activateRequest.serverTelemetry as? MSALNativeAuthServerTelemetryFake)
        XCTAssertFalse(enrollTelemetry === activateTelemetry)
        XCTAssertTrue(enrollTelemetry.context === context)
        XCTAssertTrue(activateTelemetry.context === context)
        XCTAssertEqual(enrollTelemetry.currentRequestTelemetry.apiId, .telemetryApiIdV2JITChallenge)
        XCTAssertEqual(activateTelemetry.currentRequestTelemetry.apiId, .telemetryApiIdV2JITChallenge)
        XCTAssertEqual(enrollTelemetry.currentRequestTelemetry.operationType, MSALNativeAuthV2OperationType.registerMethod.rawValue)
        XCTAssertEqual(activateTelemetry.currentRequestTelemetry.operationType, MSALNativeAuthV2OperationType.submitCode.rawValue)
    }

    // MARK: - Entry requests

    func test_resetPasswordStart_threadsApiId() throws {
        let request = try XCTUnwrap(sut.resetPasswordStart(
            username: "user@contoso.com",
            continuationToken: "CT",
            href: href,
            apiId: .telemetryApiIdV2ResetPasswordStart,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordStart)
        XCTAssertTrue(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
    }

    // MARK: - HAL follow-up requests

    func test_enroll_postsSMSContactAndContinuationToken() throws {
        let enrollHref = "/tenant/api/v2.0/auth/methods/phone?dc=test-dc&slice=test"
        let request = try XCTUnwrap(sut.enroll(
            href: enrollHref,
            verificationContact: "+15555550100",
            channelType: .sms,
            continuationToken: "ct-enroll",
            apiId: .telemetryApiIdV2JITChallenge,
            context: context
        ) as? MSIDHttpRequest)
        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: enrollHref))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2JITChallenge)
        XCTAssertTrue(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
        let serializer = try XCTUnwrap(request.requestSerializer as? MSALNativeAuthUrlRequestSerializer)
        let serialized = serializer.serialize(with: try XCTUnwrap(request.urlRequest), parameters: [:], headers: [:])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(serialized.httpBody)) as? [String: String])
        XCTAssertEqual(json, ["phoneNumber": "+15555550100", "channel": "sms", "continuationToken": "ct-enroll"])
    }

    func test_enroll_postsEmailPayloadWithoutPhoneFields() throws {
        let enrollHref = "/tenant/api/v2.0/auth/methods/email?dc=test-dc&slice=test"
        let request = try XCTUnwrap(sut.enroll(
            href: enrollHref,
            verificationContact: "test@example.com",
            channelType: .email,
            continuationToken: "ct-email",
            apiId: .telemetryApiIdV2JITChallenge,
            context: context
        ) as? MSIDHttpRequest)
        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: enrollHref))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2JITChallenge)
        let serializer = try XCTUnwrap(request.requestSerializer as? MSALNativeAuthUrlRequestSerializer)
        let serialized = serializer.serialize(with: try XCTUnwrap(request.urlRequest), parameters: [:], headers: [:])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(serialized.httpBody)) as? [String: String])
        XCTAssertEqual(json, ["email": "test@example.com", "continuationToken": "ct-email"])
    }

    func test_activate_postsOTPToServerLinkWithoutEnrollmentContact() throws {
        let activateHref = "/tenant/api/v2.0/auth/methods/phone/method-id/activate?dc=test-dc&slice=test"
        let request = try XCTUnwrap(sut.activate(
            href: activateHref,
            otp: "123456",
            continuationToken: "ct-activate",
            apiId: .telemetryApiIdV2JITChallenge,
            context: context
        ) as? MSIDHttpRequest)
        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: activateHref))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2JITChallenge)
        XCTAssertTrue(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
        let serializer = try XCTUnwrap(request.requestSerializer as? MSALNativeAuthUrlRequestSerializer)
        let serialized = serializer.serialize(with: try XCTUnwrap(request.urlRequest), parameters: [:], headers: [:])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(serialized.httpBody)) as? [String: String])
        XCTAssertEqual(json, ["otp": "123456", "continuationToken": "ct-activate"])
    }

    func test_challenge_threadsApiId() throws {
        let request = try XCTUnwrap(sut.challenge(
            href: href,
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordResendCode,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordResendCode)
    }

    func test_verify_threadsApiId() throws {
        let request = try XCTUnwrap(sut.verify(
            href: href,
            otp: "1234",
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSubmitCode,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmitCode)
    }

    func test_updatePassword_usesPutAndThreadsApiId() throws {
        let request = try XCTUnwrap(sut.updatePassword(
            href: href,
            newPassword: "newPass",
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.httpMethod, "PUT")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
    }

    func test_poll_threadsApiId() throws {
        let request = try XCTUnwrap(sut.poll(
            href: href,
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
    }

    func test_riskVerify_postsContinuationTokenAndThreadsApiId() throws {
        let request = try XCTUnwrap(sut.riskVerify(
            href: href,
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSelectAuthMethod,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSelectAuthMethod)

        let serializer = try XCTUnwrap(request.requestSerializer as? MSALNativeAuthUrlRequestSerializer)
        let urlRequest = try XCTUnwrap(request.urlRequest)
        let serialized = serializer.serialize(with: urlRequest, parameters: [:], headers: [:])
        let body = try XCTUnwrap(serialized.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["continuationToken"] as? String, "CT")
    }

    // MARK: - Fixed-endpoint requests

    func test_authorizeChallengeStart_usesAuthorizeChallengeEndpointAndThreadsApiId() throws {
        let request = try XCTUnwrap(sut.authorizeChallengeStart(
            apiId: .telemetryApiIdV2ResetPasswordStart,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .authorizeChallenge))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordStart)
    }

    func test_authorizeChallengeContinue_usesAuthorizeChallengeEndpointAndThreadsApiId() throws {
        let request = try XCTUnwrap(sut.authorizeChallengeContinue(
            continuationToken: "CT",
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .authorizeChallenge))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
    }

    func test_token_usesTokenEndpointAndKeepsRawJSONSerializer() throws {
        let request = try XCTUnwrap(sut.token(
            code: "auth-code",
            scopes: ["scope1"],
            claimsRequestJson: nil,
            apiId: .telemetryApiIdV2ResetPasswordSubmit,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(for: .token))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2ResetPasswordSubmit)
        XCTAssertFalse(request.responseSerializer is MSALNativeAuthV2HALResponseSerializer)
    }

    // MARK: - submitAttributes

    func test_submitAttributes_withValidAttributes_serializesBodyWithContinuationToken() throws {
        let request = try XCTUnwrap(sut.submitAttributes(
            href: href,
            attributes: ["city": "Redmond"],
            continuationToken: "CT",
            apiId: .telemetryApiIdV2SignUpSubmitAttributes,
            context: context
        ) as? MSIDHttpRequest)

        XCTAssertEqual(request.urlRequest?.httpMethod, "POST")
        XCTAssertEqual(request.urlRequest?.url, try resolver.url(forHref: href))
        XCTAssertEqual(apiId(of: request), .telemetryApiIdV2SignUpSubmitAttributes)

        let serializer = try XCTUnwrap(request.requestSerializer as? MSALNativeAuthUrlRequestSerializer)
        let urlRequest = try XCTUnwrap(request.urlRequest)
        let serialized = serializer.serialize(with: urlRequest, parameters: [:], headers: [:])
        let body = try XCTUnwrap(serialized.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["continuationToken"] as? String, "CT")
        let attributes = try XCTUnwrap(json["attributes"] as? [String: Any])
        XCTAssertEqual(attributes["city"] as? String, "Redmond")
    }

    func test_submitAttributes_withNonJSONValue_throwsInvalidAttributes() {
        XCTAssertThrowsError(
            try sut.submitAttributes(
                href: href,
                attributes: ["birthdate": Date()],
                continuationToken: "CT",
                apiId: .telemetryApiIdV2SignUpSubmitAttributes,
                context: context
            )
        ) { error in
            XCTAssertEqual(error as? MSALNativeAuthInternalError, .invalidAttributes)
        }
    }
}

private struct MSALNativeAuthServerTelemetryProviderFake: MSALNativeAuthServerTelemetryProviding {
    func makeTelemetry(
        currentRequestTelemetry: MSALNativeAuthCurrentRequestTelemetry,
        context: MSIDRequestContext
    ) -> MSIDHttpRequestServerTelemetryHandling {
        return MSALNativeAuthServerTelemetryFake(currentRequestTelemetry: currentRequestTelemetry, context: context)
    }
}

private final class MSALNativeAuthServerTelemetryFake: NSObject, MSIDHttpRequestServerTelemetryHandling {
    let currentRequestTelemetry: MSALNativeAuthCurrentRequestTelemetry
    let context: MSIDRequestContext

    init(currentRequestTelemetry: MSALNativeAuthCurrentRequestTelemetry, context: MSIDRequestContext) {
        self.currentRequestTelemetry = currentRequestTelemetry
        self.context = context
    }

    func handleError(_ error: Error?, context: MSIDRequestContext) {}

    func handleError(_ error: Error?, errorString: String, context: MSIDRequestContext) {}

    func setTelemetryToRequest(_ request: MSIDHttpRequestProtocol) {}
}
