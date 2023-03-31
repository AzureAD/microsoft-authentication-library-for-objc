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

final class MSALNativeAuthSignUpContinueIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private var provider: MSALNativeAuthRequestProvider.MSALNativeAuthSignUpRequestProvider!
    private var context: MSIDRequestContext!

    override func setUpWithError() throws {
        let config = try MSALNativeAuthConfiguration(
            clientId: "726E6501-BF0F-4A8B-9DDC-2ECF189DF7A7",
            authority: try .init(url: URL(string: "https://native-ux-mock-api.azurewebsites.net/test")!, rawTenant: nil)
        )

        provider = MSALNativeAuthRequestProvider.MSALNativeAuthSignUpRequestProvider(
            config: config,
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        context = MSALNativeAuthRequestContext(correlationId: correlationId)
    }

    func test_signUpContinue_withPassword_succeeds() async throws {
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            signUpToken: "<token>",
            password: "12345",
            context: context
        )

        try await performSuccessfulTestCase(with: params)
    }

    func test_signUpContinue_withOOB_succeeds() async throws {
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .oob,
            signUpToken: "<token>",
            oob: "1234",
            context: context
        )

        try await performSuccessfulTestCase(with: params)
    }

    func test_signUpContinue_withAttributes_succeeds() async throws {
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .attributes,
            signUpToken: "<token>",
            attributes: ["key": "value"],
            context: context
        )

        try await performSuccessfulTestCase(with: params)
    }

    func test_signUpContinue_fail_cases() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .signUpContinue,
            correlationId: correlationId,
            responses: [
                .invalidClient,
                .invalidPurposeToken,
                .expiredToken,
                .passwordTooWeak,
                .passwordTooShort,
                .passwordTooLong,
                .passwordRecentlyUsed,
                .passwordBanned,
                .userAlreadyExists,
                .attributesRequired,
                .verificationRequired,
                .validationFailed
            ]
        )

        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            signUpToken: "<token>",
            password: "1234",
            context: context
        )

        sut = try provider.continue(params: params)

        await perform_testFail_invalidClient()
        await perform_testFail_invalidPurposeToken()
        await perform_testFail_expiredToken()
        await perform_testFail_passwordTooWeak()
        await perform_testFail_passwordTooShort()
        await perform_testFail_passwordTooLong()
        await perform_testFail_passwordRecentlyUsed()
        await perform_testFail_passwordBanned()
        await perform_testFail_userAlreadyExists()
        await perform_testFail_attributesRequired()
        await perform_testFail_verificationRequired()
        await perform_testFail_validationFailed()
    }

    func performSuccessfulTestCase(with params: MSALNativeAuthSignUpContinueRequestProviderParams) async throws {
        try await mockAPIHandler.addResponse(endpoint: .signUpContinue, correlationId: correlationId, responses: [])
        sut = try provider.continue(params: params)

        let response: MSALNativeAuthSignUpContinueResponse? = await performTestSucceed()

        XCTAssertNotNil(response?.signinSLT)
//        XCTAssertNotNil(response?.expiresIn) // TODO: Enable when Mock Api fixes it
        XCTAssertNil(response?.signupToken)
    }

    private func mockResponse(_ response: MockAPIResponse) async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .signUpContinue,
            correlationId: correlationId,
            responses: [response]
        )
    }
}
