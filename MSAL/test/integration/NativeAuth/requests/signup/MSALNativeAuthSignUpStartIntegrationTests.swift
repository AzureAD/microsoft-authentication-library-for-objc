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

    func test_signUpStart_invalidClient() async throws {
        try await perform_testFail_invalidClient(endpoint: .signUpStart)
    }

    func test_signUpStart_unsupportedChallengeType() async throws {
        try await perform_testFail_unsupportedChallengeType(endpoint: .signUpStart)
    }

    func test_signUpStart_passwordTooWeak() async throws {
        try await perform_testFail_passwordTooWeak(endpoint: .signUpStart)
    }

    func test_signUpStart_passwordTooShort() async throws {
        try await perform_testFail_passwordTooShort(endpoint: .signUpStart)
    }

    func test_signUpStart_passwordTooLong() async throws {
        try await perform_testFail_passwordTooLong(endpoint: .signUpStart)
    }

    func test_signUpStart_passwordRecentlyUsed() async throws {
        try await perform_testFail_passwordRecentlyUsed(endpoint: .signUpStart)
    }

    func test_signUpStart_passwordBanned() async throws {
        try await perform_testFail_passwordBanned(endpoint: .signUpStart)
    }

    func test_signUpStart_userAlreadyExists() async throws {
        try await perform_testFail_userAlreadyExists(endpoint: .signUpStart)
    }

    func test_signUpStart_attributesRequired() async throws {
        try await perform_testFail_attributesRequired(endpoint: .signUpStart)
    }

    func test_signUpStart_verificationRequired() async throws {
        try await perform_testFail_verificationRequired(endpoint: .signUpStart)
    }

    func test_signUpStart_validationFailed() async throws {
        try await perform_testFail_validationFailed(endpoint: .signUpStart)
    }

    func test_signUpStart_authNotSupported() async throws {
        try await mockResponse(.authNotSupported, endpoint: .signUpStart)
        await perform_testFail_authNotSupported()
    }

    private func perform_testFail_authNotSupported() async {
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .authNotSupported)
    }
}
