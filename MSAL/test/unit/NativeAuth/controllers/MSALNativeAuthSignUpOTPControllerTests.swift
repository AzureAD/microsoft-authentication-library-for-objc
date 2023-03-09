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

final class MSALNativeAuthSignUpOTPControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthSignUpOTPController!
    private var requestProviderMock: MSALNativeAuthRequestProviderMock!
    private var cacheAccessorMock: MSALNativeAuthCacheAccessorMock!
    private var responseHandlerMock: MSALNativeAuthResponseHandlerMock!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var factoryMock: MSALNativeAuthResultFactoryMock!

    private var publicParametersStub: MSALNativeAuthSignUpOTPParameters {
        .init(email: DEFAULT_TEST_ID_TOKEN_USERNAME)
    }

    private var requestParametersStub: MSALNativeAuthSignUpRequestParameters {
        .init(
            authority: MSALNativeAuthNetworkStubs.authority,
            clientId: DEFAULT_TEST_CLIENT_ID,
            endpoint: .signUp,
            context: contextMock,
            email: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: nil,
            attributes: "<attributes1: value1>",
            scope: "<scope-1>",
            grantType: .otp
        )
    }

    private let tokenResponseDict: [String: Any] = [
        "token_type": "Bearer",
        "scope": "openid profile email",
        "expires_in": 4141,
        "ext_expires_in": 4141,
        "access_token": "accessToken",
        "refresh_token": "refreshToken",
        "id_token": "idToken"
    ]

    private var nativeAuthResponse: MSALNativeAuthResponse {
        .init(
            stage: .completed,
            credentialToken: nil,
            authentication: .init(
                accessToken: "<access_token>",
                idToken: "<id_token>",
                scopes: ["<scope_1>, <scope_2>"],
                expiresOn: Date(),
                tenantId: "myTenant"
            )
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        requestProviderMock = .init()
        cacheAccessorMock = .init()
        responseHandlerMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"
        factoryMock = .init()

        sut = .init(
            configuration: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            cacheAccessor: cacheAccessorMock,
            responseHandler: responseHandlerMock,
            context: contextMock,
            factory: factoryMock
        )
    }

    func test_whenCreateRequestFails_shouldReturnError() throws {
        let expectation = expectation(description: "SignUpOTPController create request error")

        requestProviderMock.mockSignUpRequestFunc(throwingError: ErrorMock.error)

        sut.signUp(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .invalidRequest)
            self.checkTelemetryEventsForFailedResult(networkEventHappensBefore: false)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenPerformRequestFails_shouldReturnError() throws {
        let baseUrl = URL(string: "https://www.contoso.com")!

        let parameters = ["p1": "v1"]

        let httpResponse = HTTPURLResponse(
            url: baseUrl,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        var urlRequest = URLRequest(url: baseUrl)
        urlRequest.httpMethod = "POST"

        let testUrlResponse = MSIDTestURLResponse.request(baseUrl, reponse: httpResponse)

        testUrlResponse?.setError(ErrorMock.error)

        testUrlResponse?.setUrlFormEncodedBody(parameters)
        testUrlResponse?.setResponseJSON([])
        MSIDTestURLSession.add(testUrlResponse)

        let request = try MSALNativeAuthSignUpRequest(params: requestParametersStub)

        request.urlRequest = urlRequest
        request.parameters = parameters

        let expectation = expectation(description: "SignUpOTPController perform request error")

        requestProviderMock.mockSignUpRequestFunc(result: request)

        sut.signUp(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? ErrorMock), .error)
            self.checkTelemetryEventsForFailedResult(networkEventHappensBefore: true)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenRequestDecodeFails_shouldReturnError() throws {
        let request = try MSALNativeAuthSignUpRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [])

        let expectation = expectation(description: "SignUpOTPController perform request error")

        requestProviderMock.mockSignUpRequestFunc(result: request)

        sut.signUp(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .invalidResponse)
            self.checkTelemetryEventsForFailedResult(networkEventHappensBefore: true)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenRequestVerificationDoesNotPass_shouldReturnError() throws {
        let request = try MSALNativeAuthSignUpRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignUpOTPController perform request error")

        requestProviderMock.mockSignUpRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        responseHandlerMock.mockHandleTokenFunc(throwingError: ErrorMock.error)

        sut.signUp(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .validationError)
            self.checkTelemetryEventsForFailedResult(networkEventHappensBefore: true)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenPerformRequestSucceeds_shouldCacheResponse() throws {
        let request = try MSALNativeAuthSignUpRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignUpOTPController perform request and cache response")

        requestProviderMock.mockSignUpRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)
        responseHandlerMock.mockHandleTokenFunc(result: .init())

        sut.signUp(parameters: publicParametersStub) { [unowned self] response, error in
            XCTAssertNotNil(response)
            XCTAssertNil(error)
            XCTAssertTrue(self.cacheAccessorMock.saveTokenWasCalled)
            self.checkTelemetryEventsForSuccessfulResult()

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenPerformRequestSucceeds_shouldReturnResponse() throws {
        let request = try MSALNativeAuthSignUpRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: tokenResponseDict)

        let expectation = expectation(description: "SignUpOTPController perform request success")

        requestProviderMock.mockSignUpRequestFunc(result: request)
        factoryMock.mockMakeMsidConfigurationFunc(MSALNativeAuthConfigStubs.msidConfiguration)
        factoryMock.mockMakeNativeAuthResponse(nativeAuthResponse)
        responseHandlerMock.mockHandleTokenFunc(result: .init())

        sut.signUp(parameters: publicParametersStub) { response, error in
            XCTAssertNil(error)

            XCTAssertEqual(response?.authentication?.accessToken, "<access_token>")
            XCTAssertEqual(response?.authentication?.idToken, "<id_token>")
            XCTAssertEqual(response?.authentication?.scopes, ["<scope_1>, <scope_2>"])
            XCTAssertEqual(response?.authentication?.tenantId, "myTenant")
            self.checkTelemetryEventsForSuccessfulResult()

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    private func checkTelemetryEventsForSuccessfulResult() {
        // There are two events: one from MSIDHttpRequest and other started by the controller
        // We want to check the second

        XCTAssertEqual(receivedEvents.count, 2)

        guard let telemetryEventDict = receivedEvents[1].propertyMap else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(MSALNativeAuthTelemetryApiId.telemetryApiIdSignUp.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event")
        XCTAssertEqual(telemetryEventDict["correlation_id"] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["request_id"] as? String, "telemetry_request_id")
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, "yes")
        XCTAssertEqual(telemetryEventDict["status"] as? String, "succeeded")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
    }

    private func checkTelemetryEventsForFailedResult(networkEventHappensBefore: Bool) {
        // There are two events: one from MSIDHttpRequest and other started by the controller
        // We want to test the event started by the controller

        let indexEvent = networkEventHappensBefore ? 1 : 0

        guard let telemetryEventDict = receivedEvents[indexEvent].propertyMap else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(MSALNativeAuthTelemetryApiId.telemetryApiIdSignUp.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event")
        XCTAssertEqual(telemetryEventDict["correlation_id"] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["request_id"] as? String, "telemetry_request_id")
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, "no")
        XCTAssertEqual(telemetryEventDict["status"] as? String, "failed")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
    }
}
