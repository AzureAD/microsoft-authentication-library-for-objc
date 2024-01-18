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
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthResponseHeadersSerializableTests: XCTestCase {

    private var sut: HeadersSerializableClass!

    override func setUp() async throws {
        try await super.setUp()
        sut = HeadersSerializableClass()
    }

    func test_serializeExpectedHeaders() {
        let originalHeaders = [
            "header1": "value1",
            "header2": "value2",
        ]

        let httpResponse = HTTPURLResponse(url: URL(string: "http://contoso.com")!, statusCode: 200, httpVersion: nil, headerFields: originalHeaders)

        let headers = sut.serializeHeaders(from: httpResponse)

        XCTAssertEqual(headers?["header1"], "value1")
        XCTAssertEqual(headers?["header2"], "value2")
    }

    func test_getCorrelationId() {
        let originalHeaders = [
            "client-request-id": "86A64A3C-27DC-426F-AFA0-38F68F583756"
        ]

        let httpResponse = HTTPURLResponse(url: URL(string: "http://contoso.com")!, statusCode: 200, httpVersion: nil, headerFields: originalHeaders)

        sut.headers = sut.serializeHeaders(from: httpResponse)
        let correlationId = sut.getHeaderCorrelationId()

        XCTAssertEqual(correlationId, UUID(uuidString: "86A64A3C-27DC-426F-AFA0-38F68F583756"))
    }
}

private class HeadersSerializableClass: MSALNativeAuthResponseHeadersSerializable {
    var headers: [String : String]?
}
