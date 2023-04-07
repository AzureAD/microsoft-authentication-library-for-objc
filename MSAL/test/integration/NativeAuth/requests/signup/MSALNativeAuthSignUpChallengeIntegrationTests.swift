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

final class MSALNativeAuthSignUpChallengeIntegrationTests: MSALNativeAuthIntegrationBaseTests {

    private typealias Error = MSALNativeAuthSignUpChallengeRequestError
    private var provider: MSALNativeAuthSignUpRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignUpRequestProvider(
            config: config,
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.challenge(
            token: "<token>",
            challengeTypes: [.redirect, .password, .oob],
            context: MSALNativeAuthRequestContext(correlationId: correlationId)
        )
    }

    func test_whenSignUpChallengePassword_succeeds() async throws {
        try await mockResponse(.challengeTypePassword, endpoint: .signUpChallenge)
        let response: MSALNativeAuthSignUpChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .password)
        XCTAssertNotNil(response?.signUpToken)
    }

    func test_whenSignUpChallengeOOB_succeeds() async throws {
        try await mockResponse(.challengeTypeOOB, endpoint: .signUpChallenge)
        let response: MSALNativeAuthSignUpChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .oob)
        XCTAssertNotNil(response?.signUpToken)
        XCTAssertNotNil(response?.bindingMethod)
        XCTAssertNotNil(response?.displayName)
        XCTAssertNotNil(response?.codeLength)
        XCTAssertNotNil(response?.interval)
    }

    func test_whenSignUpChallenge_redirects() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signUpChallenge)
        let response: MSALNativeAuthSignUpChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .redirect)
        XCTAssertNil(response?.signUpToken)
    }

    func test_signUpChallenge_invalidClient() async throws {
        try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .invalidClient,
            expectedError: Error(error: .invalidClient)
        )
    }

    func test_signUpChallenge_invalidPurposeToken() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .invalidPurposeToken,
            expectedError: Error(error: .invalidRequest)
        )

        guard let innerError = response.innerErrors?.first else {
            return XCTFail("There should be an inner error")
        }

        XCTAssertEqual(innerError.error, "invalid_purpose_token")
        XCTAssertNotNil(innerError.errorDescription)
    }

    func test_signUpChallenge_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .expiredToken,
            expectedError: Error(error: .expiredToken)
        )
    }

    func test_signUpChallenge_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .unsupportedChallengeType,
            expectedError: Error(error: .unsupportedChallengeType)
        )
    }
}
