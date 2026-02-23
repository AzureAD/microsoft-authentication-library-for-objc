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

final class MSALNativeAuthHTTPConfigTests: XCTestCase
{
    override func tearDown()
    {
        super.tearDown()
        MSALNativeAuthHTTPConfig.customHeaders = [:]
    }

    func test_customHeaders_acceptsNonRestrictedHeaders()
    {
        MSALNativeAuthHTTPConfig.customHeaders = [
            "customer_header_1": "value_1",
            "customer_header_2": "value_2"
        ]
        XCTAssertEqual(MSALNativeAuthHTTPConfig.customHeaders["customer_header_1"], "value_1")
        XCTAssertEqual(MSALNativeAuthHTTPConfig.customHeaders["customer_header_2"], "value_2")
    }

    func test_customHeaders_filtersOutRestrictedHeaders()
    {
        MSALNativeAuthHTTPConfig.customHeaders = [
            "customer_header_1": "value_1",
            "x-client-DM": "restricted_value"
        ]
        XCTAssertEqual(MSALNativeAuthHTTPConfig.customHeaders["customer_header_1"], "value_1")
        XCTAssertNil(MSALNativeAuthHTTPConfig.customHeaders["x-client-DM"])
    }

    func test_customHeaders_filterIsCaseInsensitive()
    {
        MSALNativeAuthHTTPConfig.customHeaders = [
            "content-type": "text/plain",
            "X-CLIENT-DM": "value",
            "ACCEPT": "application/json"
        ]
        XCTAssertNil(MSALNativeAuthHTTPConfig.customHeaders["content-type"])
        XCTAssertNil(MSALNativeAuthHTTPConfig.customHeaders["X-CLIENT-DM"])
        XCTAssertNil(MSALNativeAuthHTTPConfig.customHeaders["ACCEPT"])
    }

    func test_customHeaders_onlyRestrictedHeadersAreFiltered()
    {
        MSALNativeAuthHTTPConfig.customHeaders = [
            "customer_header_1": "value_1",
            "Content-Type": "text/plain",
            "x-client-current-telemetry": "telemetry_value",
            "customer_header_2": "value_2"
        ]
        XCTAssertEqual(MSALNativeAuthHTTPConfig.customHeaders.count, 2)
        XCTAssertEqual(MSALNativeAuthHTTPConfig.customHeaders["customer_header_1"], "value_1")
        XCTAssertEqual(MSALNativeAuthHTTPConfig.customHeaders["customer_header_2"], "value_2")
    }

    func test_restrictedHeaders_containsExpectedHeaders()
    {
        let expected: Set<String> = [
            "Content-Type",
            "Accept",
            "return-client-request-id",
            "x-ms-PkeyAuth+",
            "client-request-id",
            "x-client-CPU",
            "x-client-SKU",
            "x-app-name",
            "x-app-ver",
            "x-client-OS",
            "x-client-Ver",
            "x-client-DM",
            "x-client-current-telemetry",
            "x-client-last-telemetry"
        ]
        XCTAssertEqual(MSALNativeAuthHTTPConfig.restrictedHeaders, expected)
    }
}
