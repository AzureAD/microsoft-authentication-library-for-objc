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

final class MSALNativeAuthResponseSerializerTests: XCTestCase {

    func testSerialize_correctResponse_shouldReturnSuccess() {
        let serializer = MSALNativeAuthResponseSerializer<ResponseStub>()
        let responseString = """
        {
          "token_type": "Bearer",
          "scope": "scope",
          "expires_in": 4141,
          "extended_expires_in": 4141,
          "access_token": "access",
          "refresh_token": "refresh",
          "id_token": "id"
        }
        """
        var response: ResponseStub? = nil
        XCTAssertNoThrow(response = try serializer.responseObject(for: nil, data:responseString.data(using: .utf8) , context: nil) as? ResponseStub)
        XCTAssertEqual(response?.idToken, "id")
        XCTAssertEqual(response?.tokenType, "Bearer")
        XCTAssertEqual(response?.scope, "scope")
        XCTAssertEqual(response?.expiresIn, 4141)
        XCTAssertEqual(response?.extendedExpiresIn, 4141)
        XCTAssertEqual(response?.refreshToken, "refresh")
        XCTAssertEqual(response?.accessToken, "access")
    }

    func testSerialize_wrongResponse_shouldFail() throws {
        let serializer = MSALNativeAuthResponseSerializer<ResponseStub>()
        let wrongResponseString = """
        {
          "tokenType": "Bearer",
          "spe": "scope",
          "expiresIn": 4141,
          "ext_expires_in": 4141,
          "access_token": "access",
          "refresh_token": "refresh",
          "id_token": "id"
        }
        """
        XCTAssertThrowsError(try serializer.responseObject(for: nil, data: wrongResponseString.data(using: .utf8) , context: nil))
    }

    func testSerialize_headersCorrelationId() throws {
        let originalHeaders = [
            "client-request-id": "9958D9BC-D9D1-43E4-B5CA-5A7B0C3F28B0",
            "header2": "value2"
        ]
        let responseString = """
        {
          "token_type": "Bearer",
          "scope": "scope",
          "expires_in": 4141,
          "extended_expires_in": 4141,
          "access_token": "access",
          "refresh_token": "refresh",
          "id_token": "id"
        }
        """

        let httpResponse = HTTPURLResponse(url: URL(string: "https://contoso.com")!, statusCode: 200, httpVersion: nil, headerFields: originalHeaders)

        let serializer = MSALNativeAuthResponseSerializer<ResponseStub>()

        let result = try serializer.responseObject(for: httpResponse, data: responseString.data(using: .utf8), context: nil)

        let resultCorrelationId = (result as? MSALNativeAuthResponseCorrelatable)?.correlationId

        XCTAssertEqual(resultCorrelationId?.uuidString, "9958D9BC-D9D1-43E4-B5CA-5A7B0C3F28B0")
    }
}

private struct ResponseStub: Decodable, MSALNativeAuthResponseCorrelatable {
    let tokenType: String
    let scope: String
    let expiresIn: Int
    let extendedExpiresIn: Int
    let accessToken: String
    let refreshToken: String
    let idToken: String
    var correlationId: UUID?
}
