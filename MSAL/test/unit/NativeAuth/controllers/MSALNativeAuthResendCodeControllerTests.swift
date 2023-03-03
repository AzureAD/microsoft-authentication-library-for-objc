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

final class MSALNativeAuthResendCodeControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthResendCodeController!
    private var requestProviderMock: MSALNativeAuthRequestProviderMock!
    private var responseHandlerMock: MSALNativeAuthResponseHandlerMock!
    private var contextMock: MSALNativeAuthRequestContextMock!

    private var publicParametersStub: MSALNativeAuthResendCodeParameters {
        .init(credentialToken:"Test Credential Token")
    }

    private var requestParametersStub: MSALNativeAuthResendCodeRequestParameters {
        .init(
            authority: MSALNativeAuthNetworkStubs.authority,
            clientId: DEFAULT_TEST_CLIENT_ID,
            endpoint: .resendCode,
            context: contextMock,
            credentialToken: "Test Credential Token"
        )
    }

    private let resendCodeResponse = MSALNativeAuthResendCodeRequestResponse(credentialToken: "Test Credential Token")

    private let resendCodeResponseDict: [String: Any] = [
        "flowToken": "Test Credential Token"
    ]

    private let emptyResendCodeResponseDict: [String: Any] = [
        "flowToken": ""
    ]

    override func setUpWithError() throws {
        requestProviderMock = .init()
        responseHandlerMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"

        sut = .init(
            configuration: MSALNativeAuthConfigStubs.configuration,
            requestProvider: requestProviderMock,
            responseHandler: responseHandlerMock,
            context: contextMock
        )

        try super.setUpWithError()
    }

    func test_whenCreateRequestFails_shouldReturnError() throws {
        let expectation = expectation(description: "ResendCodeController create request error")

        requestProviderMock.mockResendCodeRequestFunc(throwingError: ErrorMock.error)

        sut.resendCode(parameters: publicParametersStub) { response, error in
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

        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        request.urlRequest = urlRequest
        request.parameters = parameters

        let expectation = expectation(description: "ResendCodeController perform request error")

        requestProviderMock.mockResendCodeRequestFunc(result: request)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? ErrorMock), .error)
            self.checkTelemetryEventsForFailedResult(networkEventHappensBefore: true)
            
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenRequestDecodeFails_shouldReturnError() throws {
        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: [])

        let expectation = expectation(description: "ResendCodeController perform request error")

        requestProviderMock.mockResendCodeRequestFunc(result: request)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .invalidResponse)
            self.checkTelemetryEventsForFailedResult(networkEventHappensBefore: true)
            
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenRequestVerificationDoesNotPass_shouldReturnError() throws {
        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: emptyResendCodeResponseDict)

        request.responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResendCodeRequestResponse>()
        
        let expectation = expectation(description: "ResendCodeController perform request error")

        requestProviderMock.mockResendCodeRequestFunc(result: request)
        responseHandlerMock.mockHandleResendCodeFunc(throwingError: ErrorMock.error)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertNil(response)
            XCTAssertEqual((error as? MSALNativeAuthError), .validationError)
            self.checkTelemetryEventsForFailedResult(networkEventHappensBefore: true)
            
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_whenPerformRequestSucceeds_shouldReturnResponse() throws {
        let request = try MSALNativeAuthResendCodeRequest(params: requestParametersStub)

        HttpModuleMockConfigurator.configure(request: request, responseJson: resendCodeResponseDict)

        request.responseSerializer = MSALNativeAuthResponseSerializer<MSALNativeAuthResendCodeRequestResponse>()

        let expectation = expectation(description: "ResendCodeController perform request success")

        requestProviderMock.mockResendCodeRequestFunc(result: request)
        responseHandlerMock.mockHandleResendCodeFunc(result: true)

        sut.resendCode(parameters: publicParametersStub) { response, error in
            XCTAssertEqual(response, "Test Credential Token")
            XCTAssertNil(error)
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

        let expectedApiId = String(MSALNativeAuthTelemetryApiId.telemetryApiIdResendCode.rawValue)
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

        let expectedApiId = String(MSALNativeAuthTelemetryApiId.telemetryApiIdResendCode.rawValue)
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
