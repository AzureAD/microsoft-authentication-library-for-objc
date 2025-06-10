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

final class MSALNativeAuthSignInInitiateRequestParametersTest: XCTestCase {
    let baseUrl = URL(string: DEFAULT_TEST_AUTHORITY)!
    var config: MSALNativeAuthInternalConfiguration! = nil

    private let context = MSALNativeAuthRequestContextMock(
        correlationId: .init(uuidString: DEFAULT_TEST_UID)!
    )
    
    func testMakeEndpointUrl_whenRightUrlStringIsUsed_noExceptionThrown() {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password], capabilities: nil, redirectUri: nil))
        let parameters = MSALNativeAuthSignInInitiateRequestParameters(context: MSALNativeAuthRequestContextMock(),
                                                                       username: "username")
        var resultUrl: URL? = nil
        XCTAssertNoThrow(resultUrl = try parameters.makeEndpointUrl(config: config))
        XCTAssertEqual(resultUrl?.absoluteString, "https://login.microsoftonline.com/common/oauth2/v2.0/initiate")
    }

    func test_passwordChallengeType_shouldCreateCorrectBodyRequest() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.password], capabilities: nil, redirectUri: nil))
        let params = MSALNativeAuthSignInInitiateRequestParameters(
            context: context,
            username: DEFAULT_TEST_ID_TOKEN_USERNAME
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": config.clientId,
            "username": params.username,
            "challenge_type": "password redirect",
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }

    func test_oobChallenge_shouldCreateCorrectBodyRequest() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [.OOB], capabilities: nil, redirectUri: nil))
        let params = MSALNativeAuthSignInInitiateRequestParameters(
            context: context,
            username: DEFAULT_TEST_ID_TOKEN_USERNAME
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": config.clientId,
            "username": params.username,
            "challenge_type": "oob redirect"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }
    
    func test_capabilities_shouldCreateCorrectBodyRequest() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [], capabilities: [.mfaRequired, .registrationRequired], redirectUri: nil))
        let params = MSALNativeAuthSignInInitiateRequestParameters(
            context: context,
            username: DEFAULT_TEST_ID_TOKEN_USERNAME
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": config.clientId,
            "username": params.username,
            "capabilities": "mfa_required registration_required",
            "challenge_type": "redirect"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }
    
    func test_duplicateCapabilities_shouldBeAddedOnlyOnce() throws {
        XCTAssertNoThrow(config = try .init(clientId: DEFAULT_TEST_CLIENT_ID, authority: MSALCIAMAuthority(url: baseUrl), challengeTypes: [], capabilities: [.registrationRequired, .registrationRequired, .mfaRequired, .mfaRequired], redirectUri: nil))

        let params = MSALNativeAuthSignInInitiateRequestParameters(
            context: context,
            username: DEFAULT_TEST_ID_TOKEN_USERNAME
        )

        let body = params.makeRequestBody(config: config)

        let expectedBodyParams = [
            "client_id": config.clientId,
            "username": params.username,
            "capabilities": "mfa_required registration_required",
            "challenge_type": "redirect"
        ]

        XCTAssertEqual(body, expectedBodyParams)
    }
}
