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

final class MSALNativeAuthUrlRequestSerializerTests: MSALNativeAuthTestCase {

    private var sut: MSALNativeAuthUrlRequestSerializer!
    private var request: URLRequest!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let url = URL(string: DEFAULT_TEST_RESOURCE)!
        request = URLRequest(url: url)

        sut = MSALNativeAuthUrlRequestSerializer(context: MSALNativeAuthRequestContext(), encoding: .json)
    }

    func test_serialize_successfully() throws {
        let parameters = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "grant_type": "passwordless_otp",
            "email": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "12345",
            "scope": DEFAULT_TEST_SCOPE
        ]

        let headers = [
            "custom-header": "value"
        ]

        let result = sut.serialize(with: request, parameters: parameters, headers: headers)

        let bodyParametersResult = try JSONDecoder().decode([String: String].self, from: result.httpBody!)

        XCTAssertEqual(bodyParametersResult.count, 5)
        XCTAssertEqual(bodyParametersResult["client_id"], DEFAULT_TEST_CLIENT_ID)
        XCTAssertEqual(bodyParametersResult["grant_type"], "passwordless_otp")
        XCTAssertEqual(bodyParametersResult["email"], DEFAULT_TEST_ID_TOKEN_USERNAME)
        XCTAssertEqual(bodyParametersResult["password"], "12345")
        XCTAssertEqual(bodyParametersResult["scope"], DEFAULT_TEST_SCOPE)

        let httpHeadersResult = result.allHTTPHeaderFields!

        XCTAssertEqual(httpHeadersResult.count, 2)
        XCTAssertEqual(httpHeadersResult["Content-Type"], "application/json")
        XCTAssertEqual(httpHeadersResult["custom-header"], "value")
    }

    func test_serialize_with_dict_in_body() throws {
        let customAttributes: [String: Codable] = [
            "name": "John",
            "surname": "Smith",
            "age": "37"
        ]

        let parameters = [
            "customAttributes": customAttributes
        ]

        let result = sut.serialize(with: request, parameters: parameters, headers: [:])

        let bodyParametersResult = try JSONDecoder().decode([String: [String: String]].self, from: result.httpBody!)

        XCTAssertEqual(bodyParametersResult.count, 1)
        let resultCustomAttributes = bodyParametersResult["customAttributes"]!

        XCTAssertEqual(resultCustomAttributes["name"], "John")
        XCTAssertEqual(resultCustomAttributes["surname"], "Smith")
        XCTAssertEqual(resultCustomAttributes["age"], "37")

        let httpHeadersResult = result.allHTTPHeaderFields!

        XCTAssertEqual(httpHeadersResult.count, 1)
        XCTAssertEqual(httpHeadersResult["Content-Type"], "application/json")
    }

    func test_when_passingEmptyBodyParams_it_still_succeeds() throws {
        let expectation = expectation(description: "Body request serialization error")
        expectation.isInverted = true

        Self.logger.expectation = expectation

        let result = sut.serialize(with: request, parameters: [:], headers: [:])

        wait(for: [expectation], timeout: 1)

        let bodyParametersResult = try JSONDecoder().decode([String: [String: String]].self, from: result.httpBody!)
        XCTAssertEqual(bodyParametersResult.count, 0)
    }

    func test_when_error_happens_in_headerSerialization_it_logs_it() throws {
        let expectation = expectation(description: "Header serialization error")

        Self.logger.expectation = expectation

        _ = sut.serialize(with: request, parameters: [:], headers: ["header": 1])

        wait(for: [expectation], timeout: 1)

        let resultingLog = Self.logger.messages[0] as! String
        XCTAssertTrue(resultingLog.contains("Header serialization failed"))
    }

    func test_when_error_happens_in_bodySerialization_it_logs_it() throws {
        let expectation = expectation(description: "Body request serialization error")

        Self.logger.expectation = expectation

        let impossibleToEncode = [
            "param": UIView()
        ]

        _ = sut.serialize(with: request, parameters: impossibleToEncode, headers: [:])

        wait(for: [expectation], timeout: 1)

        let resultingLog = Self.logger.messages[0] as! String
        XCTAssertTrue(resultingLog.contains("HTTP body request serialization failed"))
    }

    func test_serializeUrlForm_successfully() {
        let parameters = [
            "clientId": DEFAULT_TEST_CLIENT_ID,
            "grantType": "oob",
            "email": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "12345",
            "scope": DEFAULT_TEST_SCOPE
        ]

        let headers = [
            "custom-header": "value"
        ]

        sut = MSALNativeAuthUrlRequestSerializer(context: MSALNativeAuthRequestContext(), encoding: .wwwFormUrlEncoded)

        let result = sut.serialize(with: request, parameters: parameters, headers: headers)
        let bodyResultFormUrlEncoded = String(data: result.httpBody!, encoding: .utf8)

        let expectedScope = "scope=https%3A%2F%2Fgraph.microsoft.com%2Fmail.read"
        let expectedClientId = "clientId=\(DEFAULT_TEST_CLIENT_ID)"
        let expectedGrantType = "grantType=oob"
        let expectedEmail = "email=user%40contoso.com"
        let expectedPassword = "password=12345"

        let expectedBodyResult = "\(expectedScope)&\(expectedClientId)&\(expectedGrantType)&\(expectedEmail)&\(expectedPassword)"

        XCTAssertEqual(bodyResultFormUrlEncoded?.sorted(), expectedBodyResult.sorted())

        let httpHeadersResult = result.allHTTPHeaderFields!

        XCTAssertEqual(httpHeadersResult.count, 2)
        XCTAssertEqual(httpHeadersResult["Content-Type"], "application/x-www-form-urlencoded")
        XCTAssertEqual(httpHeadersResult["custom-header"], "value")
    }

    func test_when_passingEmptyBodyParamsUsingUrlForm_it_still_succeeds() throws {
        let expectation = expectation(description: "Body request serialization error")
        expectation.isInverted = true

        Self.logger.expectation = expectation

        sut = MSALNativeAuthUrlRequestSerializer(context: MSALNativeAuthRequestContext(), encoding: .wwwFormUrlEncoded)

        let result = sut.serialize(with: request, parameters: [:], headers: [:])

        wait(for: [expectation], timeout: 1)

        let bodyResultFormUrlEncoded = String(data: result.httpBody!, encoding: .utf8)!
        XCTAssertTrue(bodyResultFormUrlEncoded.isEmpty)
    }
}
