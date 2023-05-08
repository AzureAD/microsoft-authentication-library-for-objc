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

final class MSALNativeAuthSignUpRequestProviderTests: XCTestCase {

    private var sut: MSALNativeAuthSignUpRequestProvider!
    private var telemetryProvider: MSALNativeAuthTelemetryProvider!
    private var context: MSIDRequestContext!

    override func setUpWithError() throws {
        telemetryProvider = MSALNativeAuthTelemetryProvider()
        context = MSALNativeAuthRequestContext(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)

        sut = .init(config: MSALNativeAuthConfigStubs.configuration,
                    requestConfigurator: MSALNativeAuthRequestConfigurator(),
                    telemetryProvider: telemetryProvider)
    }

    func test_signUpStartRequest_is_created_successfully() throws {
        let parameters = MSALNativeAuthSignUpParameters(
            email: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "1234",
            attributes: ["city": "dublin"]
        )

        let request = try sut.start(parameters: parameters, context: context)

        checkBodyParams(request.parameters, for: .signUpStart)
        checkUrlRequest(request.urlRequest!, for: .signUpStart)

        let expectedTelemetryResult = telemetryProvider.telemetryForSignUp(type: .signUpStart).telemetryString()
        checkServerTelemetry(request.serverTelemetry, expectedTelemetryResult: expectedTelemetryResult)
    }

    func test_signUpChallengeRequest_is_created_successfully() throws {
        let request = try sut.challenge(token: "sign-up-token", context: context)

        checkBodyParams(request.parameters, for: .signUpChallenge)
        checkUrlRequest(request.urlRequest!, for: .signUpChallenge)

        let expectedTelemetryResult = telemetryProvider.telemetryForSignUp(type: .signUpChallenge).telemetryString()
        checkServerTelemetry(request.serverTelemetry, expectedTelemetryResult: expectedTelemetryResult)
    }

    func test_signUpContinueRequest_is_created_successfully() throws {
        let parameters = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            signUpToken: "sign-up-token",
            password: "1234",
            oobCode: nil,
            attributes: nil,
            context: context
        )

        let request = try sut.continue(parameters: parameters, context: context)

        checkBodyParams(request.parameters, for: .signUpContinue)
        checkUrlRequest(request.urlRequest!, for: .signUpContinue)

        let expectedTelemetryResult = telemetryProvider.telemetryForSignUp(type: .signUpContinue).telemetryString()
        checkServerTelemetry(request.serverTelemetry, expectedTelemetryResult: expectedTelemetryResult)
    }

    private func checkBodyParams(_ bodyParams: [String: String]?, for endpoint: MSALNativeAuthEndpoint) {
        typealias Key = MSALNativeAuthRequestParametersKey

        var expectedBodyParams: [String: String]!

        switch endpoint {
        case .signUpStart:
            expectedBodyParams = [
                Key.clientId.rawValue: DEFAULT_TEST_CLIENT_ID,
                Key.username.rawValue: DEFAULT_TEST_ID_TOKEN_USERNAME,
                Key.challengeType.rawValue: "redirect",
                Key.attributes.rawValue: "%7B%22city%22%3A%22dublin%22%7D",
                Key.password.rawValue: "1234"
            ]
        case .signUpChallenge:
            expectedBodyParams = [
                Key.clientId.rawValue: DEFAULT_TEST_CLIENT_ID,
                Key.signUpToken.rawValue: "sign-up-token",
                Key.challengeType.rawValue: "redirect"
            ]
        case .signUpContinue:
            expectedBodyParams = [
                Key.clientId.rawValue: DEFAULT_TEST_CLIENT_ID,
                Key.grantType.rawValue: "password",
                Key.signUpToken.rawValue: "sign-up-token",
                Key.password.rawValue: "1234"
            ]
        default:
            XCTFail("Case not tested")
        }

        XCTAssertEqual(bodyParams, expectedBodyParams)
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
