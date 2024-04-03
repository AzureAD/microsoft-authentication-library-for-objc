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

class MSALNativeAuthResponseErrorHandlerTests: XCTestCase {
    // MARK: - Variables

    private var sut: MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignInInitiateResponseError>!
    private let error = NSError(domain:"Test Error Domain", code:400, userInfo:nil)
    private let context = MSALNativeAuthRequestContextMock(correlationId: .init(uuidString: DEFAULT_TEST_UID)!)

    override func setUpWithError() throws {
        sut = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignInInitiateResponseError>()
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
            externalSSOContext: nil,
            context: nil
        ) { result, error in
            guard let error = error as? NSError else {
                XCTFail("Error type not expected, actual error type: \(type(of: error))")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(self.error.domain, error.domain)
            XCTAssertEqual(self.error.code, error.code)
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
        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest(response: httpResponse, responseJson: [])
        httpRequest.retryCounter = 5

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: nil,
            httpRequest: httpRequest,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: context
        ) { result, error in
            XCTAssertEqual(httpRequest.retryCounter, 4)
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

        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest(response: httpResponse, responseJson: [])
        httpRequest.retryCounter = 0

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: nil,
            httpRequest: httpRequest,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? NSError else {
                XCTFail("Error type not expected, actual error type: \(type(of: error))")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error.code, MSIDErrorCode.serverUnhandledResponse.rawValue)
            XCTAssertEqual(error.userInfo[MSIDHTTPResponseCodeKey] as! String, "500")
            XCTAssertEqual(error.userInfo[MSIDServerUnavailableStatusKey] as! Int, 1)
            XCTAssertEqual(error.userInfo[MSIDErrorDescriptionKey] as! String, "internal server error")
            XCTAssertEqual((error.userInfo[MSIDHTTPHeadersKey] as! [String: String]).count, 0)
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
        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest(response: httpResponse, responseJson: [])

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
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let result = result as? NSDictionary else {
                XCTFail("Result type not expected, actual type: \(type(of: result))")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(result["Test"] as! String, "Response")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldCompleteWithAPIError_whenStatusCode400() throws {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest()
        
        var dictionary = [String: Any]()
        dictionary["error"] = "invalid_request"
        dictionary["error_description"] = "Request parameter validation failed"
        dictionary["error_uri"] = HttpModuleMockConfigurator.baseUrl.absoluteString
        dictionary["inner_errors"] = [["error": "invalid_username", "error_description":"Username was invalid"]]

        let data = try JSONSerialization.data(withJSONObject: dictionary)

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? MSALNativeAuthSignInInitiateResponseError else {
                XCTFail("Error type not expected, actual error type: \(type(of: error))")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error.error, MSALNativeAuthSignInInitiateOauth2ErrorCode.invalidRequest)
            XCTAssertEqual(error.errorDescription, "Request parameter validation failed")
            XCTAssertEqual(error.errorURI, HttpModuleMockConfigurator.baseUrl.absoluteString)
            XCTAssertEqual(error.innerErrors![0].error, "invalid_username")
            XCTAssertEqual(error.innerErrors![0].errorDescription, "Username was invalid")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
    
    func test_shouldCompleteWithAPIErrorUsingCorrectResponseSerializer_whenStatusCode400AndAttributesRequired() throws {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest()
        
        var dictionary = [String: Any]()
        dictionary["error"] = "attributes_required"
        dictionary["error_description"] = "AADSTS55102: Attributes Required."
        dictionary["error_uri"] = HttpModuleMockConfigurator.baseUrl.absoluteString
        dictionary["continuation_token"] = "abcdef"

        let data = try JSONSerialization.data(withJSONObject: dictionary)

        let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignUpStartResponseError>()
        errorHandler.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: MSIDHttpResponseSerializer(), // Some transient response serializer
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? MSALNativeAuthSignUpStartResponseError else {
                XCTFail("Error type not expected, actual error type: \(type(of: error))")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error.error, MSALNativeAuthSignUpStartOauth2ErrorCode.attributesRequired)
            XCTAssertEqual(error.errorDescription, "AADSTS55102: Attributes Required.")
            XCTAssertEqual(error.errorURI, HttpModuleMockConfigurator.baseUrl.absoluteString)
            XCTAssertEqual(error.continuationToken, "abcdef")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldDecodeErrorWithCorrectResponseSerializer_whenStatusCode400AndInvalidCode() throws {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest()

        var dictionary = [String: Any]()
        dictionary["error"] = "invalid code"
        dictionary["suberror"] = "invalid suberror code"
        dictionary["error_description"] = "API Description"
        dictionary["error_uri"] = HttpModuleMockConfigurator.baseUrl.absoluteString
        dictionary["continuation_token"] = "abcdef"

        let data = try JSONSerialization.data(withJSONObject: dictionary)

        let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignUpStartResponseError>()
        errorHandler.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: MSIDHttpResponseSerializer(), // Some transient response serializer
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? MSALNativeAuthSignUpStartResponseError else {
                XCTFail("Error type not expected, actual error type: \(type(of: error))")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error.error, .unknown)
            XCTAssertEqual(error.subError, .unknown)
            XCTAssertEqual(error.errorDescription, "API Description")
            XCTAssertEqual(error.errorURI, HttpModuleMockConfigurator.baseUrl.absoluteString)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldFailDecoding_whenErrorResponseIsMalformed() throws {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest()

        // `error` field is missing
        var dictionary = [String: Any]()
        dictionary["suberror"] = "suberror_code"
        dictionary["error_description"] = "API Description"
        dictionary["error_uri"] = HttpModuleMockConfigurator.baseUrl.absoluteString
        dictionary["continuation_token"] = "abcdef"

        let data = try JSONSerialization.data(withJSONObject: dictionary)

        let errorHandler = MSALNativeAuthResponseErrorHandler<MSALNativeAuthSignUpStartResponseError>()
        errorHandler.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: MSIDHttpResponseSerializer(), // Some transient response serializer
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? MSALNativeAuthInternalError else {
                XCTFail("Error is expected to be returned")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error, .responseSerializationError(headerCorrelationId: nil))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldFailWithDecodeError_whenStatusCode400AndJSONMissing() throws {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )
        
        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest()

        let dictionary = [String: Any]()
        let data = try JSONSerialization.data(withJSONObject: dictionary)

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? MSALNativeAuthInternalError else {
                XCTFail("Error is expected to be returned")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error, .responseSerializationError(headerCorrelationId: nil))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func test_shouldFailWithDecodeError_whenStatusCode400AndJSONInvalid() throws {
        let expectation = expectation(description: "Handle Error Retry Success")

        let httpResponse = HTTPURLResponse(
            url: HttpModuleMockConfigurator.baseUrl,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )

        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest()
        
        var dictionary = [String: Any]()
        dictionary["error_key_incorrect"] = "invalid_request"
        let data = try JSONSerialization.data(withJSONObject: dictionary)

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: data,
            httpRequest: httpRequest,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? MSALNativeAuthInternalError else {
                XCTFail("Error is expected to be returned")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error, .responseSerializationError(headerCorrelationId: nil))
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
        
        let httpRequest = MSALNativeAuthHTTPRequestMock.prepareMockRequest()

        sut.handleError(
            error,
            httpResponse: httpResponse,
            data: nil,
            httpRequest: httpRequest,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: context
        ) { result, error in
            guard let error = error as? NSError else {
                XCTFail("Error type not expected, actual error type: \(type(of: error))")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(error.code, MSIDErrorCode.serverUnhandledResponse.rawValue)
            XCTAssertEqual(error.userInfo[MSIDHTTPResponseCodeKey] as! String, "600")
            XCTAssertEqual(error.userInfo[MSIDErrorDescriptionKey] as! String, "")
            XCTAssertEqual((error.userInfo[MSIDHTTPHeadersKey] as! [String: String]).count, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
