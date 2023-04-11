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

class MSALNativeAuthResponseErrorHandlerTests: XCTestCase {
    // MARK: - Variables

    private var sut: MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignInInitiateResponseError>!
    private let error = NSError(domain:"Test Error Domain", code:400, userInfo:nil)
    private var httpRequest: MSIDHttpRequest!
    private let context = MSALNativeAuthRequestContextMock(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)

    override func setUpWithError() throws {
        sut = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignInInitiateResponseError>()
        httpRequest = MSIDHttpRequest()
        try super.setUpWithError()
    }

    func test_completeWithError_whenBodyMissing() {
        let expectation = expectation(description: "Handle Error Body Missing")
        sut.handleError(
            error,
            httpResponse: nil,
            data: nil,
            httpRequest: nil,
            responseSerializer: nil,
            context: nil
        ) { result, error in
            XCTAssertEqual(self.error.domain, (error! as NSError).domain)
            XCTAssertEqual(self.error.code, (error! as NSError).code)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldRetry_whenRetryCountGreaterThanZeroAndRetryStatusCode() {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        HttpModuleMockConfigurator.configure(request: httpRequest, response: httpResponse, responseJson: [])
        httpRequest.retryCounter = 5

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: nil,
            httpRequest: httpRequest,
            responseSerializer: nil,
            context: context
        ) { result, error in
            XCTAssertEqual(self.httpRequest.retryCounter, 4)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldNotRetry_whenRetryCountZeroAndRetryStatusCode() {
        let expectation = expectation(description: "Handle Error No Retries Left")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        HttpModuleMockConfigurator.configure(request: httpRequest, response: httpResponse, responseJson: [])
        httpRequest.retryCounter = 0

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: nil,
            httpRequest: httpRequest,
            responseSerializer: nil,
            context: context
        ) { result, error in
            XCTAssertEqual((error! as NSError).code, MSIDErrorCode.serverUnhandledResponse.rawValue)
            XCTAssertEqual((error! as NSError).userInfo[MSIDHTTPResponseCodeKey] as! String, "500")
            XCTAssertEqual((error! as NSError).userInfo[MSIDServerUnavailableStatusKey] as! Int, 1)
            XCTAssertEqual((error! as NSError).userInfo[MSIDErrorDescriptionKey] as! String, "internal server error")
            XCTAssertEqual(((error! as NSError).userInfo[MSIDHTTPHeadersKey] as! [String: String]).count, 0)
            MSIDTestURLSession.clearResponses()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldCompleteAndResend_whenResponseContainsPkeyHeader() {
        let expectation = expectation(description: "Handle Error Response Pkey Header")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: [kMSIDWwwAuthenticateHeader: "PKeyAuth Context=TestContext,Version=1.0"]
        )

        HttpModuleMockConfigurator.configure(request: httpRequest, response: httpResponse, responseJson: [])

        let secondHttpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Authorization": "PKeyAuth  Context=\"TestContext\", Version=\"1.0\"",
                           "Content-Type": "application/x-www-form-urlencoded"]
        )
        let testUrlResponse = MSIDTestURLResponse.request(HttpModuleMockConfigurator.baseUrl, reponse: secondHttpResponse)
        testUrlResponse?.setRequestHeaders(secondHttpResponse?.allHeaderFields)
        testUrlResponse?.setResponseJSON(["Test":"Response"])
        MSIDTestURLSession.add(testUrlResponse)

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: nil,
            httpRequest: httpRequest,
            responseSerializer: nil,
            context: context
        ) { result, error in
            XCTAssertEqual((result as! NSDictionary)["Test"] as! String, "Response")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldCompleteWithAPIError_whenStatusCode400() {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        var dictionary = [String: Any]()
        dictionary["error"] = "invalid_request"
        dictionary["error_description"] = "Request parameter validation failed"
        dictionary["error_uri"] = HttpModuleMockConfigurator.baseUrl.absoluteString
        dictionary["inner_errors"] = [["error": "invalid_username", "error_description":"Username was invalid"]]

        let data = try! JSONSerialization.data(withJSONObject: dictionary)

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: nil,
            context: context
        ) { result, error in
            XCTAssertEqual((error as! MSALNativeAuthSignInInitiateResponseError).error, MSALNativeAuthSignInInitiateOauth2ErrorCode.invalidRequest)
            XCTAssertEqual((error as! MSALNativeAuthSignInInitiateResponseError).errorDescription, "Request parameter validation failed")
            XCTAssertEqual((error as! MSALNativeAuthSignInInitiateResponseError).errorURI, HttpModuleMockConfigurator.baseUrl.absoluteString)
            XCTAssertEqual((error as! MSALNativeAuthSignInInitiateResponseError).innerErrors![0].error, "invalid_username")
            XCTAssertEqual((error as! MSALNativeAuthSignInInitiateResponseError).innerErrors![0].errorDescription, "Username was invalid")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldFailWithDecodeError_whenStatusCode400AndJSONMissing() {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let dictionary = [String: Any]()
        let data = try! JSONSerialization.data(withJSONObject: dictionary)

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: nil,
            context: context
        ) { result, error in
            XCTAssertEqual((error as! DecodingError).localizedDescription,"The data couldn’t be read because it is missing.")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldFailWithDecodeError_whenStatusCode400AndJSONInvalid() {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        var dictionary = [String: Any]()
        dictionary["error_key_incorrect"] = "invalid_request"
        let data = try! JSONSerialization.data(withJSONObject: dictionary)

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: nil,
            context: context
        ) { result, error in
            XCTAssertEqual((error as! DecodingError).localizedDescription,"The data couldn’t be read because it is missing.")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldCompleteWithHTTPError_whenStatusCodeNotHandled() {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 600,
            httpVersion: nil,
            headerFields: nil
        )

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: nil,
            httpRequest: httpRequest,
            responseSerializer: nil,
            context: context
        ) { result, error in
            XCTAssertEqual((error! as NSError).code, MSIDErrorCode.serverUnhandledResponse.rawValue)
            XCTAssertEqual((error! as NSError).userInfo[MSIDHTTPResponseCodeKey] as! String, "600")
            XCTAssertEqual((error! as NSError).userInfo[MSIDErrorDescriptionKey] as! String, "")
            XCTAssertEqual(((error! as NSError).userInfo[MSIDHTTPHeadersKey] as! [String: String]).count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
