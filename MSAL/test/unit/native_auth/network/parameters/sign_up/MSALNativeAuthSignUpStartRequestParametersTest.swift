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

import Foundation

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthSignUpStartRequestParametersTest: XCTestCase {
    let baseUrl = URL(string: DEFAULT_TEST_AUTHORITY)!
    var config: MSALNativeAuthInternalConfiguration! = nil

    private let context = MSALNativeAuthRequestContextMock(
        correlationId: .init(uuidString: DEFAULT_TEST_UID)!
    )

    func testMakeEndpointUrl_whenRightUrlStringIsUsed_noExceptionThrown() {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password], capabilities: nil, redirectUri: nil))
        let parameters = MSALNativeAuthSignUpStartRequestParameters(
            username: "username",
            password: nil,
            attributes: nil,
            context: MSALNativeAuthRequestContextMock()
        )
        var resultUrl: URL? = nil
        XCTAssertNoThrow(resultUrl = try parameters.makeEndpointUrl(config: config))
        XCTAssertEqual(resultUrl?.absoluteString, "https://login.microsoftonline.com/common/signup/v1.0/start")
    }

    func test_allChallengeTypes_shouldCreateCorrectBodyRequest() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password, .OOB], capabilities: nil, redirectUri: nil))
        let params = MSALNativeAuthSignUpStartRequestParameters(
            username: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "strong-password",
            attributes: "<attribute1: value1>",
            context: context
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "strong-password",
            "attributes": "<attribute1: value1>",
            "challenge_type": "oob password redirect"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }
    
    func test_capabilities_shouldCreateCorrectBodyRequest() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [], capabilities: [.mfaRequired], redirectUri: nil))
        let params = MSALNativeAuthSignUpStartRequestParameters(
            username: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "password",
            attributes: nil,
            context: context
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "password",
            "challenge_type": "redirect",
            "capabilities": "mfa_required"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }
    
    func test_duplicateCapabilities_shouldBeAddedOnlyOnce() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [], capabilities: [.registrationRequired, .registrationRequired, .mfaRequired, .mfaRequired], redirectUri: nil))
        let params = MSALNativeAuthSignUpStartRequestParameters(
            username: DEFAULT_TEST_ID_TOKEN_USERNAME,
            password: "password",
            attributes: nil,
            context: context
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "password": "password",
            "challenge_type": "redirect",
            "capabilities": "mfa_required registration_required"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }
}
