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

final class MSALNativeUrlRequestSerializerTests: XCTestCase {

    func test_serialize() throws {
        let url = URL(string: DEFAULT_TEST_RESOURCE)!
        let request = URLRequest(url: url)

        let parameters = [
            "clientId": DEFAULT_TEST_CLIENT_ID,
            "grantType": "passwordless_otp",
            "email": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "12345",
            "scope": DEFAULT_TEST_SCOPE
        ]

        let headers = [
            "custom-header": "value"
        ]

        let sut = MSALNativeUrlRequestSerializer()
        let result = sut.serialize(with: request, parameters: parameters, headers: headers)

        let bodyParametersResult = try JSONDecoder().decode([String: String].self, from: result.httpBody!)

        XCTAssertEqual(bodyParametersResult.count, 5)
        XCTAssertEqual(bodyParametersResult["clientId"], DEFAULT_TEST_CLIENT_ID)
        XCTAssertEqual(bodyParametersResult["grantType"], "passwordless_otp")
        XCTAssertEqual(bodyParametersResult["email"], DEFAULT_TEST_ID_TOKEN_USERNAME)
        XCTAssertEqual(bodyParametersResult["password"], "12345")
        XCTAssertEqual(bodyParametersResult["scope"], DEFAULT_TEST_SCOPE)

        let httpHeadersResult = result.allHTTPHeaderFields!

        XCTAssertEqual(httpHeadersResult.count, 2)
        XCTAssertEqual(httpHeadersResult["Content-Type"], "application/json")
        XCTAssertEqual(httpHeadersResult["custom-header"], "value")
    }
}
