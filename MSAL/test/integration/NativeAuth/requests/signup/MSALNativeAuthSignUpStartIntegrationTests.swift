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

final class MSALNativeAuthSignUpStartIntegrationTests: MSALNativeAuthIntegrationBaseTests {

    private var provider: MSALNativeAuthRequestProvider.MSALNativeAuthSignUpRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let config = try MSALNativeAuthConfiguration(
            clientId: "726E6501-BF0F-4A8B-9DDC-2ECF189DF7A7",
            authority: try .init(url: URL(string: "https://native-ux-mock-api.azurewebsites.net/test")!, rawTenant: nil)
        )

        provider = MSALNativeAuthRequestProvider.MSALNativeAuthSignUpRequestProvider(
            config: config,
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.start(
            parameters: MSALNativeAuthSignUpParameters(email: DEFAULT_TEST_ID_TOKEN_USERNAME, password: "1234"),
            context: MSALNativeAuthRequestContext(correlationId: correlationId)
        )
    }

    func test_whenSignUpStart_succeeds() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .signUpStart,
            correlationId: correlationId,
            responses: []
        )

        let response: MSALNativeAuthSignUpStartResponse? = await performTestSucceed()

        XCTAssertNotNil(response?.signupToken)
        XCTAssertNil(response?.challengeType)
    }

    func test_whenSignUpStart_redirects() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .signUpStart,
            correlationId: correlationId,
            responses: [.challengeTypeRedirect]
        )

        let response: MSALNativeAuthSignUpStartResponse? = await performTestSucceed()

        XCTAssertNil(response?.signupToken)
        XCTAssertEqual(response?.challengeType, .redirect)
    }

    func test_all_fail_cases() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .signUpStart,
            correlationId: correlationId,
            responses: [
                .invalidClient,
                .unsupportedChallengeType,
                .passwordTooWeak,
                .passwordTooShort,
                .passwordTooLong,
                .passwordRecentlyUsed,
                .passwordBanned,
                .userAlreadyExists,
                .attributesRequired,
                .verificationRequired,
                .validationFailed,
                .authNotSupported
            ]
        )

        await perform_testFail_invalidClient()
        await perform_testFail_unsupportedChallengeType()
        await perform_testFail_passwordTooWeak()
        await perform_testFail_passwordTooShort()
        await perform_testFail_passwordTooLong()
        await perform_testFail_passwordRecentlyUsed()
        await perform_testFail_passwordBanned()
        await perform_testFail_userAlreadyExists()
        await perform_testFail_attributesRequired()
        await perform_testFail_verificationRequired()
        await perform_testFail_validationFailed()
        await perform_testFail_authNotSupported()
    }

    private func perform_testFail_authNotSupported() async {
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .authNotSupported)
    }
}
