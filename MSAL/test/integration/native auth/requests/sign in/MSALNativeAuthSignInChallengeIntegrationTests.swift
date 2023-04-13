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

class MSALNativeAuthSignInChallengeIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private typealias Error = MSALNativeAuthSignInChallengeResponseError
    private var provider: MSALNativeAuthSignInRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignInRequestProvider(config: config)

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.signInChallengeRequest(
            parameters: .init(
                config: config,
                context: context,
                credentialToken: "Test Credential Token",
                challengeTypes: nil,
                challengeTarget: nil
            ),
            context: context
        )
    }

    func test_succeedRequest_challengeTypePassword() async throws {
        try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
        let response: MSALNativeAuthSignInChallengeResponse? = try await performTestSucceed()

        XCTAssertTrue(response?.challengeType == .password)
        XCTAssertNotNil(response?.credentialToken)
    }

    func test_succeedRequest_challengeTypeOOB() async throws {
        try await mockResponse(.challengeTypeOOB, endpoint: .signInChallenge)
        let response: MSALNativeAuthSignInChallengeResponse? = try await performTestSucceed()

        XCTAssertTrue(response?.challengeType == .oob)
        XCTAssertNotNil(response?.credentialToken)
        XCTAssertNotNil(response?.bindingMethod)
        XCTAssertNotNil(response?.displayName)
        XCTAssertNotNil(response?.codeLength)
        XCTAssertNotNil(response?.interval)
    }

    func test_succeedRequest_challengeTypeRedirect() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signInChallenge)
        let response: MSALNativeAuthSignInChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .redirect)
        XCTAssertNil(response?.credentialToken)
    }


    func test_failRequest_invalidClient() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .invalidClient,
            expectedError: Error(error: .invalidClient, errorDescription: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_invalidPurposeToken() async throws {
        let response = try await perform_testFail(
            endpoint: .signInChallenge,
            response: .invalidPurposeToken,
            expectedError: Error(error: .invalidRequest, errorDescription: nil, errorURI: nil, innerErrors: nil)
        )

        guard let innerError = response.innerErrors?.first else {
            return XCTFail("There should be an inner error")
        }

        XCTAssertEqual(innerError.error, "invalid_purpose_token")
        XCTAssertNotNil(innerError.errorDescription)
    }

    func test_failRequest_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .expiredToken,
            expectedError: Error(error: .expiredToken, errorDescription: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .unsupportedChallengeType,
            expectedError: Error(error: .unsupportedChallengeType, errorDescription: nil, errorURI: nil, innerErrors: nil)
        )
    }
}
