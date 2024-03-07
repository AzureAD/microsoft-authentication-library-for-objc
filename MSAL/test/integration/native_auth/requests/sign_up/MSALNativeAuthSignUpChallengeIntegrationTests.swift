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

    private var provider: MSALNativeAuthSignUpRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignUpRequestProvider(
            requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.challenge(
            token: "<token>",
            context: MSALNativeAuthRequestContext(correlationId: correlationId)
        )
    }

    func test_whenSignUpChallengePassword_succeeds() async throws {
        try await mockResponse(.challengeTypePassword, endpoint: .signUpChallenge)
        let response: MSALNativeAuthSignUpChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .password)
        XCTAssertNotNil(response?.continuationToken)
    }

    func test_whenSignUpChallengeOOB_succeeds() async throws {
        try await mockResponse(.challengeTypeOOB, endpoint: .signUpChallenge)
        let response: MSALNativeAuthSignUpChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .oob)
        XCTAssertNotNil(response?.continuationToken)
        XCTAssertNotNil(response?.bindingMethod)
        XCTAssertNotNil(response?.challengeTargetLabel)
        XCTAssertNotNil(response?.codeLength)
        XCTAssertNotNil(response?.interval)
    }

    func test_whenSignUpChallenge_redirects() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signUpChallenge)
        let response: MSALNativeAuthSignUpChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .redirect)
        XCTAssertNil(response?.continuationToken)
    }

    func test_signUpChallenge_unauthorizedClient() async throws {
        throw XCTSkip()
        
        try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .unauthorizedClient,
            expectedError: createError(.unauthorizedClient)
        )
    }

    func test_signUpChallenge_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .expiredToken,
            expectedError: createError(.expiredToken)
        )
    }

    func test_signUpChallenge_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .unsupportedChallengeType,
            expectedError: createError(.unsupportedChallengeType)
        )
    }

    func test_signUpChallenge_invalidContinuationToken() async throws {
        throw XCTSkip()
        
        try await perform_testFail(
            endpoint: .signUpChallenge,
            response: .invalidContinuationToken,
            expectedError: createError(.invalidRequest)
        )
    }

    private func createError(_ error: MSALNativeAuthSignUpChallengeOauth2ErrorCode) -> MSALNativeAuthSignUpChallengeResponseError {
        .init(error: error, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
    }
}
