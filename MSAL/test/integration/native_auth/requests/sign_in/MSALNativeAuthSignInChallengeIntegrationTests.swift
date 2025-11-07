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

        provider = MSALNativeAuthSignInRequestProvider(requestConfigurator: MSALNativeAuthRequestConfigurator(config: config))

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.challenge(
            parameters: .init(
                context: context,
                mfaAuthMethodId: nil,
                continuationToken: "Test Credential Token"
            ),
            context: context
        )
    }

    func test_succeedRequest_challengeTypePassword() async throws {
        try await mockResponse(.challengeTypePassword, endpoint: .signInChallenge)
        let response: MSALNativeAuthSignInChallengeResponse? = try await performTestSucceed()

        XCTAssertTrue(response?.challengeType == .password)
        XCTAssertNotNil(response?.continuationToken)
    }

    func test_succeedRequest_challengeTypeOOB() async throws {
        try await mockResponse(.challengeTypeOOB, endpoint: .signInChallenge)
        let response: MSALNativeAuthSignInChallengeResponse? = try await performTestSucceed()

        XCTAssertTrue(response?.challengeType == .oob)
        XCTAssertEqual(response?.continuationToken, "Q3JlZGVudGlhbCB0b2tlbiBpcyB0ZXN0")
        XCTAssertEqual(response?.bindingMethod, "prompt")
        XCTAssertEqual(response?.challengeTargetLabel, "...")
        XCTAssertEqual(response?.challengeChannel, "email")
        XCTAssertEqual(response?.codeLength, 6)
        XCTAssertEqual(response?.interval, 300)
    }
    
    func test_succeedRequest_challengeSuccessSMS() async throws {
        try await mockResponse(.challengeSuccessSMS, endpoint: .signInChallenge)
        let response: MSALNativeAuthSignInChallengeResponse? = try await performTestSucceed()

        XCTAssertTrue(response?.challengeType == .oob)
        XCTAssertEqual(response?.continuationToken, "Q3JlZGVudGlhbCB0b2tlbiBpcyB0ZXN0")
        XCTAssertEqual(response?.bindingMethod, "prompt")
        XCTAssertEqual(response?.challengeTargetLabel, "+3538331***")
        XCTAssertEqual(response?.challengeChannel, "sms")
        XCTAssertEqual(response?.codeLength, 8)
    }

    func test_succeedRequest_challengeTypeRedirect() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signInChallenge)
        let response: MSALNativeAuthSignInChallengeResponse? = try await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .redirect)
        XCTAssertNil(response?.continuationToken)
        XCTAssertNotNil(response?.redirectReason)
    }


    func test_failRequest_unauthorizedClient() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .unauthorizedClient,
            expectedError: Error(error: .unauthorizedClient, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }
    
    func test_failRequest_invalidContinuationToken() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .invalidContinuationToken,
            expectedError: Error(error: .invalidRequest, errorDescription: nil, errorCodes: [55000], errorURI: nil, innerErrors: nil)
        )
    }
    
    func test_failRequest_BlockedVerificationContact() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .authMethodBlocked,
            expectedError: Error(error: .invalidRequest, errorDescription: "AADSTS550024: Configuring multi-factor authentication method is blocked. Trace ID: 48dc1336-6096-4167-ae1d-5bf3baa40400 Correlation ID: dbbcff90-8ad6-497f-aabb-73cc05ffdbdd Timestamp: 2025-10-07 12:59:45Z", errorCodes: [550024], errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .expiredToken,
            expectedError: Error(error: .expiredToken, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signInChallenge,
            response: .unsupportedChallengeType,
            expectedError: Error(error: .unsupportedChallengeType, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }
}
