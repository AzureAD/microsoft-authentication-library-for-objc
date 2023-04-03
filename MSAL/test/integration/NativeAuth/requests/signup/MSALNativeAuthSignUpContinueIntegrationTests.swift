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
        try super.setUpWithError()

        provider = MSALNativeAuthRequestProvider.MSALNativeAuthSignUpRequestProvider(
            config: config,
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        context = MSALNativeAuthRequestContext(correlationId: correlationId)

        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            signUpToken: "<token>",
            password: "12345",
            context: context
        )

        sut = try provider.continue(params: params)
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

    func test_signUpChallenge_invalidClient() async throws {
        try await perform_testFail_invalidClient(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_invalidPurposeToken() async throws {
        try await perform_testFail_invalidPurposeToken(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_expiredToken() async throws {
        try await perform_testFail_expiredToken(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_passwordTooWeak() async throws {
        try await perform_testFail_passwordTooWeak(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_passwordTooShort() async throws {
        try await perform_testFail_passwordTooShort(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_passwordTooLong() async throws {
        try await perform_testFail_passwordTooLong(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_passwordRecentlyUsed() async throws {
        try await perform_testFail_passwordRecentlyUsed(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_passwordBanned() async throws {
        try await perform_testFail_passwordBanned(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_userAlreadyExists() async throws {
        try await perform_testFail_userAlreadyExists(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_attributesRequired() async throws {
        try await perform_testFail_attributesRequired(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_verificationRequired() async throws {
        try await perform_testFail_verificationRequired(endpoint: .signUpContinue)
    }

    func test_signUpChallenge_validationFailed() async throws {
        try await perform_testFail_validationFailed(endpoint: .signUpContinue)
    }

    func performSuccessfulTestCase(with params: MSALNativeAuthSignUpContinueRequestProviderParams) async throws {
        try await mockAPIHandler.addResponse(endpoint: .signUpContinue, correlationId: correlationId, responses: [])
        sut = try provider.continue(params: params)

        let response: MSALNativeAuthSignUpContinueResponse? = await performTestSucceed()

        XCTAssertNotNil(response?.signinSLT)
//        XCTAssertNotNil(response?.expiresIn) // TODO: Enable when Mock Api fixes it
        XCTAssertNil(response?.signupToken)
    }
}
