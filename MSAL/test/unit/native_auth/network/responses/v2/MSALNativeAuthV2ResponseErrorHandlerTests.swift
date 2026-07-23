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

final class MSALNativeAuthV2ResponseErrorHandlerTests: XCTestCase {

    private let sut = MSALNativeAuthV2ResponseErrorHandler()
    private let url = URL(string: "https://contoso.com/api/v0.1/auth")!

    func test_handleError_parsesBodyAndReturnsHALResponse() throws {
        let json: [String: Any] = ["error": ["code": "invalid_grant", "message": "bad code"]]
        let data = try JSONSerialization.data(withJSONObject: json)
        let httpResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)

        let expectation = expectation(description: "completion called")
        var receivedResponse: MSALNativeAuthHALResponse?
        var receivedError: Error?

        sut.handleError(
            nil,
            httpResponse: httpResponse,
            data: data,
            httpRequest: nil,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: nil
        ) { responseObject, error in
            receivedResponse = responseObject as? MSALNativeAuthHALResponse
            receivedError = error
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertNil(receivedError)
        XCTAssertEqual(receivedResponse?.statusCode, 400)
        XCTAssertEqual(receivedResponse?.error?.code, "invalid_grant")
    }

    func test_handleError_usesProvidedSerializer() throws {
        let json: [String: Any] = ["state": "continue"]
        let data = try JSONSerialization.data(withJSONObject: json)
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)

        let expectation = expectation(description: "completion called")
        var receivedResponse: MSALNativeAuthHALResponse?

        sut.handleError(
            nil,
            httpResponse: httpResponse,
            data: data,
            httpRequest: nil,
            responseSerializer: MSALNativeAuthV2HALResponseSerializer(),
            externalSSOContext: nil,
            context: nil
        ) { responseObject, _ in
            receivedResponse = responseObject as? MSALNativeAuthHALResponse
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedResponse?.state, "continue")
    }

    func test_handleError_nonJSONBody_returnsError() {
        let httpResponse = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)

        let expectation = expectation(description: "completion called")
        var receivedResponse: Any?
        var receivedError: Error?

        sut.handleError(
            nil,
            httpResponse: httpResponse,
            data: Data("not json".utf8),
            httpRequest: nil,
            responseSerializer: nil,
            externalSSOContext: nil,
            context: nil
        ) { responseObject, error in
            receivedResponse = responseObject
            receivedError = error
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertNil(receivedResponse)
        XCTAssertNotNil(receivedError)
    }
}
