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
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthBaseControllerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthBaseController!
    private var contextMock: MSALNativeAuthRequestContextMock!
    private var clientId: String!

    override func setUp() {
        super.setUp()

        contextMock = MSALNativeAuthRequestContextMock()
        contextMock.mockTelemetryRequestId = "mock_id"
        clientId = DEFAULT_TEST_CLIENT_ID
        dispatcher = MSALNativeAuthTelemetryTestDispatcher()

        sut = MSALNativeAuthBaseController(
            clientId: clientId
        )
    }

    override func tearDown() {
        super.tearDown()
        MSIDTelemetry.sharedInstance().remove(dispatcher)
    }

    func test_makeTelemetryApiEvent() {

        let event = sut.makeLocalTelemetryApiEvent(name: "anEvent", telemetryApiId: .telemetryApiIdSignUp, context: contextMock)!
        let properties = event.getProperties()!

        XCTAssertEqual(properties[MSID_TELEMETRY_KEY_EVENT_NAME] as? String, "anEvent")

        let expectedTelemetryApiId = String(MSALNativeAuthTelemetryApiId.telemetryApiIdSignUp.rawValue)
        XCTAssertEqual(properties[MSID_TELEMETRY_KEY_API_ID] as? String, expectedTelemetryApiId)
        XCTAssertEqual(properties[MSID_TELEMETRY_KEY_CORRELATION_ID] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(properties[MSID_TELEMETRY_KEY_CLIENT_ID] as? String, clientId)
    }

    func test_stopTelemetryEvent_with_no_error() {
        let event = sut.makeLocalTelemetryApiEvent(name: "anEvent", telemetryApiId: .telemetryApiIdSignInWithPasswordStart, context: contextMock)
        let expectation = expectation(description: "Telemetry event test no error")

        dispatcher.setTestCallback { event in
            let dict = event.getProperties()!

            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_EVENT_NAME] as? String, "anEvent")
            XCTAssertNil(dict[MSID_TELEMETRY_KEY_API_ERROR_CODE])
            XCTAssertNil(dict[MSID_TELEMETRY_KEY_PROTOCOL_CODE])
            XCTAssertNil(dict[MSID_TELEMETRY_KEY_ERROR_DOMAIN])
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_IS_SUCCESSFUL] as? String, "yes")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_RESULT_STATUS] as? String, "succeeded")
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_START_TIME])
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_END_TIME])

            expectation.fulfill()
        }

        MSIDTelemetry.sharedInstance().add(dispatcher)

        sut.startTelemetryEvent(event, context: contextMock)
        sut.stopTelemetryEvent(event, context: contextMock)

        wait(for: [expectation], timeout: 1)
    }

    func test_stopTelemetryEvent_withNegativeErrorCode() {
        let event = sut.makeLocalTelemetryApiEvent(name: "anEvent", telemetryApiId: .telemetryApiIdSignInWithPasswordStart, context: contextMock)
        let error = NSError(domain: "com.microsoft", code: -1)

        let expectation = expectation(description: "Telemetry event test negative error code")

        dispatcher.setTestCallback { event in
            let dict = event.getProperties()!

            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_EVENT_NAME] as? String, "anEvent")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_API_ERROR_CODE] as? String, "-1")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_ERROR_DOMAIN] as? String, "com.microsoft")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_IS_SUCCESSFUL] as? String, "no")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_RESULT_STATUS] as? String, "failed")
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_START_TIME])
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_END_TIME])

            expectation.fulfill()
        }

        MSIDTelemetry.sharedInstance().add(dispatcher)

        sut.startTelemetryEvent(event, context: contextMock)
        sut.stopTelemetryEvent(event, context: contextMock, error: error)

        wait(for: [expectation], timeout: 1)
    }

    func test_stopTelemetryEvent_withPositiveErrorCode() {
        let event = sut.makeLocalTelemetryApiEvent(name: "anEvent", telemetryApiId: .telemetryApiIdSignInWithPasswordStart, context: contextMock)
        let error = NSError(domain: "com.microsoft", code: 12)

        let expectation = expectation(description: "Telemetry event test positive error code")

        dispatcher.setTestCallback { event in
            let dict = event.getProperties()!

            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_EVENT_NAME] as? String, "anEvent")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_API_ERROR_CODE] as? String, "12")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_ERROR_DOMAIN] as? String, "com.microsoft")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_IS_SUCCESSFUL] as? String, "no")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_RESULT_STATUS] as? String, "failed")
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_START_TIME])
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_END_TIME])

            expectation.fulfill()
        }

        MSIDTelemetry.sharedInstance().add(dispatcher)

        sut.startTelemetryEvent(event, context: contextMock)
        sut.stopTelemetryEvent(event, context: contextMock, error: error)

        wait(for: [expectation], timeout: 1)
    }

    func test_stopTelemetryEvent_with_OAuthErrorKey() {
        let event = sut.makeLocalTelemetryApiEvent(name: "anEvent", telemetryApiId: .telemetryApiIdSignInWithPasswordStart, context: contextMock)
        let error = NSError(domain: "com.microsoft", code: 12, userInfo: ["MSIDOAuthErrorKey": "oauthErrorCode_mock"])

        let expectation = expectation(description: "Telemetry event test OAuthErrorKey")

        dispatcher.setTestCallback { event in
            let dict = event.getProperties()!

            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_EVENT_NAME] as? String, "anEvent")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_API_ERROR_CODE] as? String, "12")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_PROTOCOL_CODE] as? String, "oauthErrorCode_mock")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_ERROR_DOMAIN] as? String, "com.microsoft")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_IS_SUCCESSFUL] as? String, "no")
            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_RESULT_STATUS] as? String, "failed")
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_START_TIME])
            XCTAssertNotNil(dict[MSID_TELEMETRY_KEY_END_TIME])

            expectation.fulfill()
        }

        MSIDTelemetry.sharedInstance().add(dispatcher)

        sut.startTelemetryEvent(event, context: contextMock)
        sut.stopTelemetryEvent(event, context: contextMock, error: error)

        wait(for: [expectation], timeout: 1)
    }

    func test_completeWithTelemetry_withInvalidParameters_shouldComplete() {
        let event = sut.makeLocalTelemetryApiEvent(name: "anEvent", telemetryApiId: .telemetryApiIdSignInWithPasswordStart, context: contextMock)

        let exp1 = expectation(description: "Telemetry event")
        let exp2 = expectation(description: "Completion event")

        dispatcher.setTestCallback { event in
            let dict = event.getProperties()!

            XCTAssertEqual(dict[MSID_TELEMETRY_KEY_EVENT_NAME] as? String, "anEvent")
            exp1.fulfill()
        }

        MSIDTelemetry.sharedInstance().add(dispatcher)

        sut.startTelemetryEvent(event, context: contextMock)

        let responseNil: String? = nil

        sut.complete(event, response: responseNil, error: nil, context: contextMock) { _, _ in
            exp2.fulfill()
        }

        wait(for: [exp1, exp2], timeout: 1)
    }

    func test_performRequest_withError() async {
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
        testUrlResponse?.setResponseJSON([""])
        MSIDTestURLSession.add(testUrlResponse)

        let request = MSIDHttpRequest()

        request.urlRequest = urlRequest
        request.parameters = parameters

        let result: Result<String, Error> = await sut.performRequest(request, context: contextMock)

        switch result {
        case .failure(let error):
            XCTAssertEqual(error as? ErrorMock, ErrorMock.error)
        case .success:
            XCTFail("Unexpected response")
        }
    }

    func test_performRequest_withSuccess() async {
        let request = MSALNativeAuthHTTPRequestMock.prepareMockRequest(responseJson: ["response"])

        let result: Result<[String], Error> = await sut.performRequest(request, context: contextMock)

        switch result {
        case .failure:
            XCTFail("Unexpected response")
        case .success(let response):
            XCTAssertEqual(response.first, "response")
        }
    }

    func test_performRequest_withUnexpectedError() async {
        let request = MSALNativeAuthHTTPRequestMock.prepareMockRequest(responseJson: [nil])

        let result: Result<[String], Error> = await sut.performRequest(request, context: contextMock)

        switch result {
        case .failure(let error):
            XCTAssertEqual(error as? MSALNativeAuthInternalError, .invalidResponse)
        case .success:
            XCTFail("Unexpected response")
        }
    }

    // MARK: - Integration tests

    func test_performRequest_500_error_updatesContextCorrelationId() async {
        await performTestContext(statusCode: 500)
    }

    func test_performRequest_400_error_updatesContextCorrelationId() async {
        await performTestContext(statusCode: 400)
    }

    private func performTestContext(statusCode: Int) async {
        let localCorrelationId = UUID()

        let headerCorrelationIdString = "82398bb3-0a88-475a-bfd6-c28d5eef42d4"
        let headerCorrelationId = UUID(uuidString: headerCorrelationIdString)!

        let context = MSALNativeAuthRequestContext(correlationId: localCorrelationId)

        let baseUrl = URL(string: "https://www.contoso.com")!

        let parameters = ["p1": "v1"]

        let httpResponse = HTTPURLResponse(
            url: baseUrl,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: [
                "client-request-id": headerCorrelationIdString
            ]
        )

        var urlRequest = URLRequest(url: baseUrl)
        urlRequest.httpMethod = "POST"

        let testUrlResponse = MSIDTestURLResponse.request(baseUrl, reponse: httpResponse)

        testUrlResponse?.setUrlFormEncodedBody(parameters)
        MSIDTestURLSession.add(testUrlResponse)

        let request = MSIDHttpRequest()

        request.errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignUpChallengeResponseError>()
        request.urlRequest = urlRequest
        request.parameters = parameters
        request.retryCounter = 0

        let result: Result<String, Error> = await sut.performRequest(request, context: context)

        switch result {
        case .failure:
            XCTAssertEqual(context.correlationId(), headerCorrelationId)
        case .success:
            XCTFail("Unexpected response")
        }
    }
}

extension String: MSALNativeAuthResponseCorrelatable {
    public var correlationId: UUID? {
        get { nil }
        set {}
    }
}

extension Array<String>: MSALNativeAuthResponseCorrelatable {
    public var correlationId: UUID? {
        get { nil }
        set {}
    }
}
