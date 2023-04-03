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

    private var params: MSALNativeAuthSignUpContinueRequestProviderParams {
        .init(
            grantType: .password,
            signUpToken: "<token>",
            password: "12345",
            context: context
        )
    }

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

    func test_signUpChallenge_invalidClient() async throws {
        try await mockResponse(.invalidClient)
        sut = try provider.continue(params: params)
        await perform_testFail_invalidClient()
    }

    func test_signUpChallenge_invalidPurposeToken() async throws {
        try await mockResponse(.invalidPurposeToken)
        sut = try provider.continue(params: params)
        await perform_testFail_invalidPurposeToken()
    }

    func test_signUpChallenge_expiredToken() async throws {
        try await mockResponse(.expiredToken)
        sut = try provider.continue(params: params)
        await perform_testFail_expiredToken()
    }

    func test_signUpChallenge_passwordTooWeak() async throws {
        try await mockResponse(.passwordTooWeak)
        sut = try provider.continue(params: params)
        await perform_testFail_passwordTooWeak()
    }

    func test_signUpChallenge_passwordTooShort() async throws {
        try await mockResponse(.passwordTooShort)
        sut = try provider.continue(params: params)
        await perform_testFail_passwordTooShort()
    }

    func test_signUpChallenge_passwordTooLong() async throws {
        try await mockResponse(.passwordTooLong)
        sut = try provider.continue(params: params)
        await perform_testFail_passwordTooLong()
    }

    func test_signUpChallenge_passwordRecentlyUsed() async throws {
        try await mockResponse(.passwordRecentlyUsed)
        sut = try provider.continue(params: params)
        await perform_testFail_passwordRecentlyUsed()
    }

    func test_signUpChallenge_passwordBanned() async throws {
        try await mockResponse(.passwordBanned)
        sut = try provider.continue(params: params)
        await perform_testFail_passwordBanned()
    }

    func test_signUpChallenge_userAlreadyExists() async throws {
        try await mockResponse(.userAlreadyExists)
        sut = try provider.continue(params: params)
        await perform_testFail_userAlreadyExists()
    }

    func test_signUpChallenge_attributesRequired() async throws {
        try await mockResponse(.attributesRequired)
        sut = try provider.continue(params: params)
        await perform_testFail_attributesRequired()
    }

    func test_signUpChallenge_verificationRequired() async throws {
        try await mockResponse(.verificationRequired)
        sut = try provider.continue(params: params)
        await perform_testFail_verificationRequired()
    }

    func test_signUpChallenge_validationFailed() async throws {
        try await mockResponse(.validationFailed)
        sut = try provider.continue(params: params)
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
