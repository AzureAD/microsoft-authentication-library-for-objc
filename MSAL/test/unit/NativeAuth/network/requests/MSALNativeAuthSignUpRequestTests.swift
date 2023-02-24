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

final class MSALNativeAuthSignUpRequestTests: XCTestCase {

    private let context = MSALNativeAuthRequestContextMock(
        correlationId: .init(uuidString: DEFAULT_TEST_UID)!
    )

    private var params: MSALNativeAuthSignUpRequestParameters {
        .init(
            authority: MSALNativeAuthNetworkStubs.authority,
            clientId: DEFAULT_TEST_CLIENT_ID,
            endpoint: .signUp,
            context: context,
            email: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "strong-password",
            attributes: "<attribute1: value1>",
            scope: "<scope-1>",
            grantType: .password
        )
    }

    func test_signUpRequest_gets_created_successfully() throws {

        let telemetry = MSIDAADTokenRequestServerTelemetry()
        telemetry.currentRequestTelemetry = .init(
            appId: 1234,
            tokenCacheRefreshType: .proactiveTokenRefresh,
            platformFields: ["ios"]
        )!

        let sut = try MSALNativeAuthSignUpRequest(params: params)

        XCTAssertEqual(sut.context!.correlationId(), context.correlationId())
        XCTAssertEqual(sut.telemetryApiId, .telemetryApiIdSignUp)
        checkBodyParams(sut.parameters)
    }

    func test_configure_signUpRequest() throws {
        let telemetry = MSIDAADTokenRequestServerTelemetry()
        telemetry.currentRequestTelemetry = .init(
            appId: 1234,
            tokenCacheRefreshType: .proactiveTokenRefresh,
            platformFields: ["ios"]
        )!

        let sut = try MSALNativeAuthSignUpRequest(params: params)

        sut.configure(
            requestSerializer: MSALNativeAuthUrlRequestSerializer(context: context),
            serverTelemetry: telemetry
        )

        checkTelemetry(sut.serverTelemetry, telemetry)
        checkUrlRequest(sut.urlRequest)
    }

    private func checkTelemetry(_ result: MSIDHttpRequestServerTelemetryHandling?, _ expected: MSIDAADTokenRequestServerTelemetry) {

        guard let resultTelemetry = (result as? MSIDAADTokenRequestServerTelemetry)?.currentRequestTelemetry else {
            return XCTFail()
        }

        let expectedTelemetry = expected.currentRequestTelemetry

        XCTAssertEqual(resultTelemetry.apiId, expectedTelemetry.apiId)
        XCTAssertEqual(resultTelemetry.tokenCacheRefreshType, expectedTelemetry.tokenCacheRefreshType)
        XCTAssertEqual(resultTelemetry.platformFields, expectedTelemetry.platformFields)
    }

    private func checkBodyParams(_ result: [String: String]?) {
        let expectedBodyParams = [
            "clientId": DEFAULT_TEST_CLIENT_ID,
            "grantType": "password",
            "email": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "strong-password",
            "scope": "<scope-1>",
            "customAttributes": "<attribute1: value1>"
        ]

        XCTAssertEqual(result, expectedBodyParams)
    }

    private func checkUrlRequest(_ result: URLRequest?) {
        XCTAssertEqual(result?.httpMethod, MSALParameterStringForHttpMethod(.POST))

        let expectedUrl = URL(string: MSALNativeAuthNetworkStubs.authority.url.absoluteString + MSALNativeAuthEndpoint.signUp.rawValue)!
        XCTAssertEqual(result?.url, expectedUrl)
    }
}
