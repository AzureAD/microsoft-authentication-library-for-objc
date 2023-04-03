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

    private var provider: MSALNativeAuthRequestProvider.MSALNativeAuthSignUpRequestProvider!

    override func setUpWithError() throws {
        let config = try MSALNativeAuthConfiguration(
            clientId: "726E6501-BF0F-4A8B-9DDC-2ECF189DF7A7",
            authority: try .init(url: URL(string: "https://native-ux-mock-api.azurewebsites.net/test")!, rawTenant: nil)
        )

        provider = MSALNativeAuthRequestProvider.MSALNativeAuthSignUpRequestProvider(
            config: config,
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.challenge(
            token: "<token>",
            context: MSALNativeAuthRequestContext(correlationId: correlationId)
        )
    }

    func test_whenSignUpChallengePassword_succeeds() async throws {
        try await mockResponse(.challengeTypePassword)
        let response: MSALNativeAuthSignUpChallengeResponse? = await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .password)
        XCTAssertNotNil(response?.signUpToken)
        XCTAssertNil(response?.bindingMethod)
        XCTAssertNil(response?.displayName)
        XCTAssertNil(response?.codeLength)
        XCTAssertNil(response?.interval)
        XCTAssertNil(response?.displayType)
    }

    func test_whenSignUpChallengeOOB_succeeds() async throws {
        try await mockResponse(.challengeTypeOOB)
        let response: MSALNativeAuthSignUpChallengeResponse? = await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .oob)
        XCTAssertNotNil(response?.signUpToken)
        XCTAssertNotNil(response?.bindingMethod)
        XCTAssertNotNil(response?.displayName)
        XCTAssertNotNil(response?.codeLength)
        XCTAssertNotNil(response?.interval)
        XCTAssertNil(response?.displayType)
    }

    func test_whenSignUpChallenge_redirects() async throws {
        try await mockResponse(.challengeTypeRedirect)
        let response: MSALNativeAuthSignUpChallengeResponse? = await performTestSucceed()

        XCTAssertEqual(response?.challengeType, .redirect)
        XCTAssertNil(response?.signUpToken)
        XCTAssertNil(response?.bindingMethod)
        XCTAssertNil(response?.codeLength)
        XCTAssertNil(response?.displayName)
        XCTAssertNil(response?.displayType)
        XCTAssertNil(response?.interval)
    }

    func test_signUpChallenge_invalidClient() async throws {
        try await mockResponse(.invalidClient)
        await perform_testFail_invalidClient()
    }

    func test_signUpChallenge_invalidPurposeToken() async throws {
        try await mockResponse(.invalidPurposeToken)
        await perform_testFail_invalidPurposeToken()
    }

    func test_signUpChallenge_expiredToken() async throws {
        try await mockResponse(.expiredToken)
        await perform_testFail_expiredToken()
    }

    func test_signUpChallenge_unsupportedChallengeType() async throws {
        try await mockResponse(.unsupportedChallengeType)
        await perform_testFail_unsupportedChallengeType()
    }

    private func mockResponse(_ response: MockAPIResponse) async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .signUpChallenge,
            correlationId: correlationId,
            responses: [response]
        )
    }
}
