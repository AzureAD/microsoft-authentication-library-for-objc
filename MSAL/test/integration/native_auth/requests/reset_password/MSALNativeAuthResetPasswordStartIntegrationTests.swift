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

final class MSALNativeAuthResetPasswordStartIntegrationTests: MSALNativeAuthIntegrationBaseTests {

    private typealias Error = MSALNativeAuthResetPasswordStartResponseError
    private var provider: MSALNativeAuthResetPasswordRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        provider = MSALNativeAuthResetPasswordRequestProvider(
            requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.start(
            parameters: MSALNativeAuthResetPasswordStartRequestParameters(context: context,
                                                                          username: DEFAULT_TEST_ID_TOKEN_USERNAME),
            context: MSALNativeAuthRequestContext(correlationId: correlationId)
        )
    }

    func test_whenResetPasswordStart_succeeds() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .resetPasswordStart,
            correlationId: correlationId,
            responses: []
        )

        let response: MSALNativeAuthResetPasswordStartResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.passwordResetToken)
        XCTAssertNil(response?.challengeType)
    }

    func test_whenResetPasswordStart_redirects() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .resetPasswordStart)
        let response: MSALNativeAuthResetPasswordStartResponse? = try await performTestSucceed()

        XCTAssertNil(response?.passwordResetToken)
        XCTAssertEqual(response?.challengeType, .redirect)
    }

    func test_resetPasswordStart_invalidClient() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordStart,
            response: .invalidClient,
            expectedError: Error(error: .invalidClient)
        )
    }

    func test_resetPasswordStart_userNotFound() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordStart,
            response: .explicityUserNotFound,
            expectedError: Error(error: .userNotFound)
        )
    }

    func test_resetPasswordStart_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordStart,
            response: .unsupportedChallengeType,
            expectedError: Error(error: .unsupportedChallengeType)
        )
    }
}
