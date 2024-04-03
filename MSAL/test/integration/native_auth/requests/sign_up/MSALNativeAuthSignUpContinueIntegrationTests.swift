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

    private var provider: MSALNativeAuthSignUpRequestProvider!
    private var context: MSALNativeAuthRequestContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignUpRequestProvider(
            requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        context = MSALNativeAuthRequestContext(correlationId: correlationId)

        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            continuationToken: "<token>",
            password: "12345",
            context: context
        )

        sut = try provider.continue(parameters: params)
    }

    func test_signUpContinue_withPassword_succeeds() async throws {
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .password,
            continuationToken: "<token>",
            password: "12345",
            context: context
        )

        try await performSuccessfulTestCase(with: params)
    }

    func test_signUpContinue_withOOB_succeeds() async throws {
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .oobCode,
            continuationToken: "<token>",
            oobCode: "1234",
            context: context
        )

        try await performSuccessfulTestCase(with: params)
    }

    func test_signUpContinue_withAttributes_succeeds() async throws {
        let params = MSALNativeAuthSignUpContinueRequestProviderParams(
            grantType: .attributes,
            continuationToken: "<token>",
            attributes: ["key": "value"],
            context: context
        )

        try await performSuccessfulTestCase(with: params)
    }

    func test_signUpContinue_unauthorizedClient() async throws {
        throw XCTSkip()
        
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .unauthorizedClient,
            expectedError: createError(.unauthorizedClient)
        )
    }

    func test_signUpContinue_invalidGrant() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .invalidGrant,
            expectedError: createError(.invalidGrant)
        )
    }

    func test_signUpContinue_invalidContinuationToken() async throws {
        throw XCTSkip()

        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .invalidContinuationToken,
            expectedError: createError(.invalidRequest)
        )
    }

    func test_signUpContinue_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .expiredToken,
            expectedError: createError(.expiredToken)
        )
    }

    func test_signUpContinue_invalidOOBValue() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .invalidOOBValue,
            expectedError: createError(.invalidGrant, subError: .invalidOOBValue)
        )
    }

    func test_signUpContinue_passwordTooWeak() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .passwordTooWeak,
            expectedError: createError(.invalidGrant, subError: .passwordTooWeak)
        )
    }

    func test_signUpContinue_passwordTooShort() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .passwordTooShort,
            expectedError: createError(.invalidGrant, subError: .passwordTooShort)
        )
    }

    func test_signUpContinue_passwordTooLong() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .passwordTooLong,
            expectedError: createError(.invalidGrant, subError: .passwordTooLong)
        )
    }

    func test_signUpContinue_passwordRecentlyUsed() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .passwordRecentlyUsed,
            expectedError: createError(.invalidGrant, subError: .passwordRecentlyUsed)
        )
    }

    func test_signUpContinue_passwordBanned() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .passwordBanned,
            expectedError: createError(.invalidGrant, subError: .passwordBanned)
        )
    }

    func test_signUpContinue_userAlreadyExists() async throws {
        try await perform_testFail(
            endpoint: .signUpContinue,
            response: .userAlreadyExists,
            expectedError: createError(.userAlreadyExists)
        )
    }

    func test_signUpContinue_attributesRequired() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpContinue,
            response: .attributesRequired,
            expectedError: createError(.attributesRequired)
        )

        XCTAssertNotNil(response.continuationToken)
    }

    func test_signUpContinue_verificationRequired() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpContinue,
            response: .verificationRequired,
            expectedError: createError(.verificationRequired)
        )

        XCTAssertNotNil(response.continuationToken)
        XCTAssertNotNil(response.unverifiedAttributes)
    }

    func test_signUpContinue_validationFailed() async throws {
        throw XCTSkip()

        let response = try await perform_testFail(
            endpoint: .signUpContinue,
            response: .attributeValidationFailed,
            expectedError: createError(.invalidGrant, subError: .attributeValidationFailed)
        )

        XCTAssertNotNil(response.continuationToken)
        XCTAssertNotNil(response.invalidAttributes)
    }

    func test_signUpContinue_credentialRequired() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpContinue,
            response: .credentialRequired,
            expectedError: createError(.credentialRequired)
        )

        XCTAssertNotNil(response.continuationToken)
    }

    func performSuccessfulTestCase(with params: MSALNativeAuthSignUpContinueRequestProviderParams) async throws {
        try await mockAPIHandler.addResponse(endpoint: .signUpContinue, correlationId: correlationId, responses: [])
        sut = try provider.continue(parameters: params)

        let response: MSALNativeAuthSignUpContinueResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.continuationToken)
    }

    private func createError(_ error: MSALNativeAuthSignUpContinueOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil) -> MSALNativeAuthSignUpContinueResponseError {
        .init(
            error: error,
            subError: subError,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            continuationToken: nil,
            requiredAttributes: nil,
            unverifiedAttributes: nil,
            invalidAttributes: nil
        )
    }
}
