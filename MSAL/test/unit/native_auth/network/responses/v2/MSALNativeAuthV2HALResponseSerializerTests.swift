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

final class MSALNativeAuthV2HALResponseSerializerTests: XCTestCase {

    private let sut = MSALNativeAuthV2HALResponseSerializer()

    // MARK: - Top-level scalar fields

    func test_responseObject_parsesTopLevelScalarFields() throws {
        let json: [String: Any] = [
            "state": "interactionRequired",
            "action": "challenge",
            "continuation_token": "ct-123",
            "codeLength": 8,
            "hint": "u***@contoso.com",
            "id": "method-1",
            "type": "email",
            "code": "auth-code",
            "challengeContext": ["authenticationFactor": "oob"]
        ]

        let response = try parse(json, statusCode: 200)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.state, "interactionRequired")
        XCTAssertEqual(response.action, "challenge")
        XCTAssertEqual(response.continuationToken, "ct-123")
        XCTAssertEqual(response.codeLength, 8)
        XCTAssertEqual(response.hint, "u***@contoso.com")
        XCTAssertEqual(response.methodId, "method-1")
        XCTAssertEqual(response.methodType, "email")
        XCTAssertEqual(response.code, "auth-code")
        XCTAssertEqual(response.authenticationFactor, "oob")
    }

    func test_responseObject_prefersCamelCaseContinuationToken() throws {
        let response = try parse(["continuationToken": "camel", "continuation_token": "snake"], statusCode: 200)
        XCTAssertEqual(response.continuationToken, "camel")
    }

    // MARK: - Links

    func test_responseObject_parsesTopLevelLinks() throws {
        let json: [String: Any] = [
            "_links": [
                "verify": ["href": "https://contoso.com/verify", "name": "verify"],
                "resend": ["href": "https://contoso.com/challenge"]
            ]
        ]

        let response = try parse(json, statusCode: 200)

        XCTAssertEqual(response.href(forRelation: "verify"), "https://contoso.com/verify")
        XCTAssertEqual(response.href(forRelation: "resend"), "https://contoso.com/challenge")
    }

    func test_responseObject_parsesAuthorizeChallengeFlowLinksFromTopLevelJSON() throws {
        let response = try parse(["sign_in": "https://contoso.com/signin"], statusCode: 401)
        XCTAssertEqual(response.href(forRelation: "sign_in"), "https://contoso.com/signin")
    }

    // MARK: - Embedded methods

    func test_responseObject_parsesEmbeddedMethods() throws {
        let json: [String: Any] = [
            "_embedded": [
                "methods": [
                    [
                        "id": "1",
                        "type": "email",
                        "hint": "u***@contoso.com",
                        "_links": ["challenge": ["href": "https://contoso.com/challenge"]]
                    ]
                ]
            ]
        ]

        let response = try parse(json, statusCode: 200)

        XCTAssertEqual(response.methods.count, 1)
        let method = try XCTUnwrap(response.methods.first)
        XCTAssertEqual(method.id, "1")
        XCTAssertEqual(method.type, "email")
        XCTAssertEqual(method.hint, "u***@contoso.com")
        XCTAssertEqual(method.link(for: .challenge), "https://contoso.com/challenge")
    }

    // MARK: - Attributes

    func test_responseObject_parsesAttributes() throws {
        let json: [String: Any] = [
            "attributes": [
                ["attributeId": "email", "type": "string", "required": true, "validationRegex": ".+@.+"],
                ["id": "displayName", "type": "string"]
            ]
        ]

        let response = try parse(json, statusCode: 200)

        XCTAssertEqual(response.attributes.count, 2)
        XCTAssertEqual(response.attributes[0], .init(id: "email", type: "string", required: true, regex: ".+@.+"))
        XCTAssertEqual(response.attributes[1], .init(id: "displayName", type: "string", required: false, regex: nil))
    }

    // MARK: - Server error

    func test_responseObject_parsesServerError() throws {
        let json: [String: Any] = [
            "error": [
                "code": "invalid_grant",
                "message": "bad code",
                "innerError": ["code": "invalid_oob_value"]
            ]
        ]

        let response = try parse(json, statusCode: 400)

        let error = try XCTUnwrap(response.error)
        XCTAssertEqual(error.code, "invalid_grant")
        XCTAssertEqual(error.message, "bad code")
        XCTAssertEqual(error.innerErrorCode, "invalid_oob_value")
    }

    func test_responseObject_serverErrorCorrelationIdParsedFromBody() throws {
        let correlationId = UUID()
        let json: [String: Any] = ["error": ["code": "x", "correlation_id": correlationId.uuidString]]

        let response = try parse(json, statusCode: 400)

        XCTAssertEqual(response.error?.correlationId, correlationId)
    }

    // MARK: - Empty / malformed bodies

    func test_responseObject_emptyData_returnsEmptyResponseWithStatusCode() throws {
        let httpResponse = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)
        let result = try sut.responseObject(for: httpResponse, data: Data(), context: nil)
        let response = try XCTUnwrap(result as? MSALNativeAuthHALResponse)

        XCTAssertEqual(response.statusCode, 204)
        XCTAssertNil(response.state)
        XCTAssertNil(response.action)
        XCTAssertNil(response.error)
        XCTAssertTrue(response.links.isEmpty)
        XCTAssertTrue(response.methods.isEmpty)
    }

    func test_responseObject_nilHTTPResponse_defaultsStatusCodeToZero() throws {
        let result = try sut.responseObject(for: nil, data: Data(), context: nil)
        let response = try XCTUnwrap(result as? MSALNativeAuthHALResponse)
        XCTAssertEqual(response.statusCode, 0)
    }

    func test_responseObject_nonJSONBody_throws() {
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        XCTAssertThrowsError(try sut.responseObject(for: httpResponse, data: Data("not json".utf8), context: nil))
    }

    // MARK: - Helpers

    private let url = URL(string: "https://contoso.com/api/v0.1/auth")!

    private func parse(_ json: [String: Any], statusCode: Int) throws -> MSALNativeAuthHALResponse {
        let data = try JSONSerialization.data(withJSONObject: json)
        let httpResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        let result = try sut.responseObject(for: httpResponse, data: data, context: nil)
        return try XCTUnwrap(result as? MSALNativeAuthHALResponse)
    }
}
