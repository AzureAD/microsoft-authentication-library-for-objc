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

final class MSALNativeAuthUnknownCaseProtocolTests: XCTestCase {

    func test_decodeKnownValue() throws {
        let json = """
        {
            "errorType": "invalid_grant",
            "errorDescription": "This is an error description",
            "errorCodes": [50076]
        }
        """

        let data = json.data(using: .utf8)!

        let apiError = try JSONDecoder().decode(ApiErrorResponse.self, from: data)

        XCTAssertNotNil(apiError)
        XCTAssertEqual(apiError.errorType, .invalidGrant)
        XCTAssertEqual(apiError.errorDescription, "This is an error description")
        XCTAssertEqual(apiError.errorCodes, [50076])
    }

    func test_decodingAnUnknownValue_produces_aNotNilApiModel() throws {
        let json = """
        {
            "errorType": "new_error_type_unknown_to_the_SDK",
            "errorDescription": "This is an error description",
            "errorCodes": [50076]
        }
        """

        let data = json.data(using: .utf8)!

        let apiError = try JSONDecoder().decode(ApiErrorResponse.self, from: data)

        XCTAssertNotNil(apiError)
        XCTAssertEqual(apiError.errorType, .unknown)
        XCTAssertEqual(apiError.errorDescription, "This is an error description")
        XCTAssertEqual(apiError.errorCodes, [50076])
    }
}

private struct ApiErrorResponse: Decodable {
    let errorType: ApiErrorTypeEnum
    let errorDescription: String
    let errorCodes: [Int]
}

private enum ApiErrorTypeEnum: String, Decodable, Equatable, MSALNativeAuthUnknownCaseProtocol {
    case invalidGrant = "invalid_grant"
    case unauthorizedClient = "unauthorized_client"
    case unknown
}
