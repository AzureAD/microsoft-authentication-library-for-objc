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

    private typealias Error = MSALNativeAuthSignUpStartResponseError
    private var provider: MSALNativeAuthSignUpRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignUpRequestProvider(
            requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
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

        let response: MSALNativeAuthSignUpStartResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.signupToken)
        XCTAssertNil(response?.challengeType)
    }

    func test_whenSignUpStart_redirects() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signUpStart)
        let response: MSALNativeAuthSignUpStartResponse? = try await performTestSucceed()

        XCTAssertNil(response?.signupToken)
        XCTAssertEqual(response?.challengeType, .redirect)
    }

    func test_signUpStart_invalidClient() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .invalidClient,
            expectedError: Error(error: .invalidClient)
        )
    }

    func test_signUpStart_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .unsupportedChallengeType,
            expectedError: Error(error: .unsupportedChallengeType)
        )
    }

    func test_signUpStart_passwordTooWeak() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordTooWeak,
            expectedError: Error(error: .passwordTooWeak)
        )
    }

    func test_signUpStart_passwordTooShort() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordTooShort,
            expectedError: Error(error: .passwordTooShort)
        )
    }

    func test_signUpStart_passwordTooLong() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordTooLong,
            expectedError: Error(error: .passwordTooLong)
        )
    }

    func test_signUpStart_passwordRecentlyUsed() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordRecentlyUsed,
            expectedError: Error(error: .passwordRecentlyUsed)
        )
    }

    func test_signUpStart_passwordBanned() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .passwordBanned,
            expectedError: Error(error: .passwordBanned)
        )
    }

    func test_signUpStart_userAlreadyExists() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .userAlreadyExists,
            expectedError: Error(error: .userAlreadyExists)
        )
    }

    func test_signUpStart_attributesRequired() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpStart,
            response: .attributesRequired,
            expectedError: Error(error: .attributesRequired)
        )

        XCTAssertNotNil(response.signUpToken)
    }

    func test_signUpStart_verificationRequired() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpStart,
            response: .verificationRequired,
            expectedError: Error(error: .verificationRequired)
        )

        XCTAssertNotNil(response.signUpToken)
        XCTAssertNotNil(response.unverifiedAttributes)
    }

    func test_signUpStart_validationFailed() async throws {
        let response = try await perform_testFail(
            endpoint: .signUpStart,
            response: .attributeValidationFailed,
            expectedError: Error(error: .attributeValidationFailed)
        )

        XCTAssertNotNil(response.signUpToken)
    }

    func test_signUpStart_authNotSupported() async throws {
        try await perform_testFail(
            endpoint: .signUpStart,
            response: .authNotSupported,
            expectedError: Error(error: .authNotSupported)
        )
    }
}
