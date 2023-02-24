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

    override func setUpWithError() throws {
        sut = MSALNativeAuthRequestProvider(
            clientId: DEFAULT_TEST_CLIENT_ID,
            authority: MSALNativeAuthNetworkStubs.authority
        )
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
        checkUrlRequest(request.urlRequest, for: .signIn)

        let expectedTelemetryResult = MSALNativeAuthTelemetryProvider()
            .telemetryForSignIn(type: .signInWithPassword)
            .telemetryString()
        checkServerTelemetry(request.serverTelemetry, expectedTelemetryResult: expectedTelemetryResult)
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
        checkUrlRequest(request.urlRequest, for: .signUp)

        let expectedTelemetryResult = MSALNativeAuthTelemetryProvider()
            .telemetryForSignUp(type: .signUpWithPassword)
            .telemetryString()
        checkServerTelemetry(request.serverTelemetry, expectedTelemetryResult: expectedTelemetryResult)
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
