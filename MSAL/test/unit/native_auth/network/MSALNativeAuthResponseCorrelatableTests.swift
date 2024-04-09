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

final class MSALNativeAuthResponseCorrelatableTests: XCTestCase {

    private var sut: ResponseCorrelatableClass!

    override func setUp() async throws {
        try await super.setUp()
        sut = ResponseCorrelatableClass()
    }

    func test_serializeExpectedCorrelationId() {
        let originalHeaders = [
            "client-request-id": "9958D9BC-D9D1-43E4-B5CA-5A7B0C3F28B0",
            "header2": "value2",
        ]

        let httpResponse = HTTPURLResponse(url: URL(string: "http://contoso.com")!, statusCode: 200, httpVersion: nil, headerFields: originalHeaders)

        let correlationIdString = ResponseCorrelatableClass.retrieveCorrelationIdFromHeaders(from: httpResponse)

        XCTAssertEqual(correlationIdString, UUID(uuidString: "9958D9BC-D9D1-43E4-B5CA-5A7B0C3F28B0"))
    }
}

private class ResponseCorrelatableClass: MSALNativeAuthResponseCorrelatable {
    var correlationId: UUID?
}
