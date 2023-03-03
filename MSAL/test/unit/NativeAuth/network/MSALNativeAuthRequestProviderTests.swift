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

final class MSALNativeAuthRequestProviderTests: XCTestCase {

    private var sut: MSALNativeAuthRequestProvider!
    let telemetryProvider = MSALNativeAuthTelemetryProvider()

    override func setUpWithError() throws {
        sut = MSALNativeAuthRequestProvider(
            clientId: DEFAULT_TEST_CLIENT_ID,
            authority: MSALNativeAuthNetworkStubs.authority
        )
    }

    func test_signUpRequest_is_created_successfully() throws {
        let parameters = MSALNativeAuthSignUpParameters(
            email: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "strong-password",
            attributes: ["attribute1": "value1"],
            scopes: ["<scope-1>"]
        )

        let request = try sut.signUpRequest(
            parameters: parameters,
            context: MSALNativeAuthRequestContextMock(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        )

        checkSignUpBodyParams(request.parameters)
        checkUrlRequest(request.urlRequest,
                        for: .signUp)

        let expectedTelemetryResult = telemetryProvider
            .telemetryForSignUp(type: .signUpWithPassword)
            .telemetryString()
        checkServerTelemetry(request.serverTelemetry,
                             expectedTelemetryResult: expectedTelemetryResult)
    }

    func test_signInRequest_is_created_successfully() throws {
        let parameters = MSALNativeAuthSignInParameters(
            email: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "strong-password",
            scopes: ["<scope-1>"]
        )

        let request = try sut.signInRequest(
            parameters: parameters,
            context: MSALNativeAuthRequestContextMock(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        )

        checkSignInBodyParams(request.parameters)
        checkUrlRequest(request.urlRequest,
                        for: .signIn)

        let expectedTelemetryResult = telemetryProvider
            .telemetryForSignIn(type: .signInWithPassword)
            .telemetryString()
        checkServerTelemetry(request.serverTelemetry,
                             expectedTelemetryResult: expectedTelemetryResult)
    }

    func test_createSignInOTPRequest_shouldBeCreatedSuccessfully() throws {
        let parameters = MSALNativeAuthSignInOTPParameters(
            email: DEFAULT_TEST_ID_TOKEN_USERNAME,
            scopes: ["<scope-1>"]
        )

        let request = try sut.signInOTPRequest(
            parameters: parameters,
            context: MSALNativeAuthRequestContextMock(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        )

        checkSignInOTPBodyParams(request.parameters)
        checkUrlRequest(request.urlRequest, for: .signIn)

        let expectedTelemetryResult = MSALNativeAuthTelemetryProvider()
            .telemetryForSignIn(type: .signInWithOTP)
            .telemetryString()
        checkServerTelemetry(request.serverTelemetry, expectedTelemetryResult: expectedTelemetryResult)
    }

    func test_resendCodeRequest_is_created_successfully() throws {
        let parameters = MSALNativeAuthResendCodeParameters(
            credentialToken: "Test Credential Token"
        )

        let request = try sut.resendCodeRequest(
            parameters: parameters,
            context: MSALNativeAuthRequestContextMock(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        )

        checkResendCodeBodyParams(request.parameters)
        checkUrlRequest(request.urlRequest,
                        for: .resendCode)

        let expectedTelemetryResult = telemetryProvider
            .telemetryForResendCode(type: .resendCode)
            .telemetryString()
        checkServerTelemetry(request.serverTelemetry,
                             expectedTelemetryResult: expectedTelemetryResult)
    }

    func test_verifyCodeRequest_is_created_successfully() throws {
        let parameters = MSALNativeAuthVerifyCodeParameters(
            credentialToken: "Test Credential Token",
            otp: "Test OTP"
        )

        let request = try sut.verifyCodeRequest(
            parameters: parameters,
            context: MSALNativeAuthRequestContextMock(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)
        )

        checkVerifyCodeBodyParams(request.parameters)
        checkUrlRequest(request.urlRequest,
                        for: .verifyCode)

        let expectedTelemetryResult = telemetryProvider
            .telemetryForVerifyCode(type: .verifyCode)
            .telemetryString()
        checkServerTelemetry(request.serverTelemetry,
                             expectedTelemetryResult: expectedTelemetryResult)
    }

    private func checkSignInBodyParams(_ result: [String: String]?) {
        let expectedBodyParams = [
            "clientId": DEFAULT_TEST_CLIENT_ID,
            "grantType": "password",
            "email": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "strong-password",
            "scope": "<scope-1>"
        ]

        XCTAssertEqual(result, expectedBodyParams)
    }

    private func checkSignInOTPBodyParams(_ result: [String: String]?) {
        let expectedBodyParams = [
            "clientId": DEFAULT_TEST_CLIENT_ID,
            "grantType": "passwordless_otp",
            "email": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "scope": "<scope-1>"
        ]

        XCTAssertEqual(result, expectedBodyParams)
    }

    private func checkSignUpBodyParams(_ result: [String: String]?) {
        let expectedBodyParams = [
            "clientId": DEFAULT_TEST_CLIENT_ID,
            "grantType": "password",
            "email": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "strong-password",
            "scope": "<scope-1>",
            "customAttributes":  "{\"attribute1\":\"value1\"}"
        ]

        XCTAssertEqual(result, expectedBodyParams)
    }

    private func checkResendCodeBodyParams(_ result: [String: String]?) {
        let expectedBodyParams = [
            "flowToken": "Test Credential Token"
        ]

        XCTAssertEqual(result, expectedBodyParams)
    }

    private func checkVerifyCodeBodyParams(_ result: [String: String]?) {
        let expectedBodyParams = [
            "clientId": DEFAULT_TEST_CLIENT_ID,
            "flowToken": "Test Credential Token",
            "otp": "Test OTP"
        ]
        XCTAssertEqual(result, expectedBodyParams)
    }

    private func checkUrlRequest(_ result: URLRequest?, for endpoint: MSALNativeAuthEndpoint) {
        XCTAssertEqual(result?.httpMethod, MSALParameterStringForHttpMethod(.POST))

        let expectedUrl = URL(string: MSALNativeAuthNetworkStubs.authority.url.absoluteString + endpoint.rawValue)!
        XCTAssertEqual(result?.url, expectedUrl)

        XCTAssertEqual(result?.allHTTPHeaderFields?["return-client-request-id"], "true")
        XCTAssertEqual(result?.allHTTPHeaderFields?["Accept"], "application/json")
    }

    private func checkServerTelemetry(_ result: MSIDHttpRequestServerTelemetryHandling?, expectedTelemetryResult: String) {
        guard let serverTelemetry = result as? MSALNativeAuthServerTelemetry else {
            return XCTFail("Server telemetry should be of kind MSALNativeAuthServerTelemetry")
        }

        XCTAssertEqual(serverTelemetry.context.correlationId().uuidString, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(serverTelemetry.currentRequestTelemetry.telemetryString(), expectedTelemetryResult)
    }
}
