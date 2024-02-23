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
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthSignUpStartIntegrationTests: MSALNativeAuthIntegrationBaseTests {

    private var provider: MSALNativeAuthSignUpRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignUpRequestProvider(
            requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.start(
            parameters: MSALNativeAuthSignUpStartRequestProviderParameters(
                username: DEFAULT_TEST_ID_TOKEN_USERNAME,
                password: "1234",
                attributes: [:],
                context: MSALNativeAuthRequestContext(correlationId: correlationId)
            )
        )
    }

    func test_whenSignUpStart_succeeds() async throws {
        try await mockResponse(.signUpStartSuccess, endpoint: .signUpStart)
        let response: MSALNativeAuthSignUpStartResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.continuationToken)
    }

    func test_whenSignUpStart_redirects() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signUpStart)
        let response: MSALNativeAuthSignUpStartResponse? = try await performTestSucceed()

        XCTAssertNil(response?.continuationToken)
        XCTAssertEqual(response?.challengeType, .redirect)
    }

    func test_signUpStart_unauthorizedClient() async throws {
        throw XCTSkip()
        
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .unauthorizedClient,
            expectedError: createError(.unauthorizedClient)
        )
    }

    func test_signUpStart_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .unsupportedChallengeType,
            expectedError: createError(.unsupportedChallengeType)
        )
    }

    func test_signUpStart_passwordTooWeak() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordTooWeak,
            expectedError: createError(.invalidGrant, subError: .passwordTooWeak)
        )
    }

    func test_signUpStart_passwordTooShort() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordTooShort,
            expectedError: createError(.invalidGrant, subError: .passwordTooShort)
        )
    }

    func test_signUpStart_passwordTooLong() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordTooLong,
            expectedError: createError(.invalidGrant, subError: .passwordTooLong)
        )
    }

    func test_signUpStart_passwordRecentlyUsed() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordRecentlyUsed,
            expectedError: createError(.invalidGrant, subError: .passwordRecentlyUsed)
        )
    }

    func test_signUpStart_passwordBanned() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordBanned,
            expectedError: createError(.invalidGrant, subError: .passwordBanned)
        )
    }

    func test_signUpStart_userAlreadyExists() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .userAlreadyExists,
            expectedError: createError(.userAlreadyExists)
        )
    }

    func test_signUpStart_attributesRequired() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpStart,
            response: .attributesRequired,
            expectedError: createError(.attributesRequired)
        )

        XCTAssertNotNil(response.continuationToken)
    }

    func test_signUpStart_validationFailed() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpStart,
            response: .attributeValidationFailed,
            expectedError: createError(.invalidGrant, subError: .attributeValidationFailed)
        )

        XCTAssertNotNil(response.invalidAttributes)
    }

    func test_signUpStart_unsupportedAuthMethod() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .authNotSupported,
            expectedError: createError(.unsupportedAuthMethod)
        )
    }

    func test_signUpStart_invalidRequest_withESTSErrorInvalidEmail() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .invalidUsername,
            expectedError: createError(.invalidRequest, errorCodes: [90100])
        )
    }

    private func createError(_ error: MSALNativeAuthSignUpStartOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil, errorCodes: [Int]? = nil) -> MSALNativeAuthSignUpStartResponseError {
        .init(
            error: error,
            subError: subError,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            continuationToken: nil,
            unverifiedAttributes: nil,
            invalidAttributes: nil
        )
    }
}
