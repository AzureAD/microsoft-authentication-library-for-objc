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

final class MSALNativeAuthTokenRequestParametersTest: XCTestCase {
    let baseUrl = URL(string: DEFAULT_TEST_AUTHORITY)!
    var config: MSALNativeAuthInternalConfiguration! = nil
    private let context = MSALNativeAuthRequestContextMock(
        correlationId: .init(uuidString: DEFAULT_TEST_UID)!
    )

    func testMakeEndpointUrl_whenRightUrlStringIsUsed_noExceptionThrown() {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password], capabilities: nil, redirectUri: nil))
        let parameters = MSALNativeAuthTokenRequestParameters(context: MSALNativeAuthRequestContextMock(),
                                                                    username: "username",
                                                                    continuationToken: "Test Credential Token",
                                                                    grantType: .password,
                                                                    scope: "scope",
                                                                    password: "password",
                                                                    oobCode: "Test OTP Code",
                                                                    includeChallengeType: true,
                                                                    refreshToken: nil,
                                                                    claimsRequestJson: nil)
        var resultUrl: URL? = nil
        XCTAssertNoThrow(resultUrl = try parameters.makeEndpointUrl(config: config))
        XCTAssertEqual(resultUrl?.absoluteString, "https://login.microsoftonline.com/common/oauth2/v2.0/token")
    }

    func test_passwordParameters_shouldCreateCorrectBodyRequest() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password], capabilities: nil, redirectUri: nil))
        let params = MSALNativeAuthTokenRequestParameters(
            context: context,
            username: DEFAULT_TEST_ID_TOKEN_USERNAME,
            continuationToken: "Test continuation Token",
            grantType: .password,
            scope: "<scope-1>",
            password: "password",
            oobCode: "oob",
            includeChallengeType: true,
            refreshToken: nil,
            claimsRequestJson: nil
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": DEFAULT_TEST_CLIENT_ID,
            "username": DEFAULT_TEST_ID_TOKEN_USERNAME,
            "continuation_token": "Test continuation Token",
            "grant_type": "password",
            "challenge_type": "password redirect",
            "scope": "<scope-1>",
            "password": "password",
            "oob": "oob",
            "client_info" : "true"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }

    func test_nilParameters_shouldCreateCorrectParameters() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password], capabilities: nil, redirectUri: nil))
        let params = MSALNativeAuthTokenRequestParameters(
            context: context,
            username: nil,
            continuationToken: nil,
            grantType: .password,
            scope: nil,
            password: nil,
            oobCode: nil,
            includeChallengeType: false,
            refreshToken: nil,
            claimsRequestJson: nil
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": config.clientId,
            "grant_type": "password",
            "client_info" : "true"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }
}
