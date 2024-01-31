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

final class MSALNativeAuthCustomErrorSerializerTests: XCTestCase {

    func test_errorDeserializer_usesCorrelationIdFromHeaders() {
        let headers = [
            "client-request-id": "9958D9BC-D9D1-43E4-B5CA-5A7B0C3F28B0",
            "header2": "value2"
        ]
        let responseString = """
        {
          "error": "invalid_grant",
          "error_description": "New password is weak",
          "suberror": "password_too_weak",
          "correlation_id": "081f5395-539f-498d-8175-1d71e52601de"
        }
        """

        let sut = MSALNativeAuthCustomErrorSerializer<MSALNativeAuthSignUpStartResponseError>()
        
        let httpResponse = HTTPURLResponse(url: URL(string: "https://contoso.com")!, statusCode: 400, httpVersion: nil, headerFields: headers)

        do {
            _ = try sut.responseObject(for: httpResponse, data: responseString.data(using: .utf8), context: nil)
        } catch {
            let result = (error as? MSALNativeAuthSignUpStartResponseError)?.correlationId
            XCTAssertEqual(result?.uuidString, "9958D9BC-D9D1-43E4-B5CA-5A7B0C3F28B0")
        }
    }
}
