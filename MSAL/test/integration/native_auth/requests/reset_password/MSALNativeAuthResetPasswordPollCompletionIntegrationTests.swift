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

final class MSALNativeAuthResetPasswordPollCompletionIntegrationTests: MSALNativeAuthIntegrationBaseTests {

    private var provider: MSALNativeAuthResetPasswordRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        provider = MSALNativeAuthResetPasswordRequestProvider(
            requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.pollCompletion(
            parameters: MSALNativeAuthResetPasswordPollCompletionRequestParameters(context: context,
                                                                                   continuationToken: "<continuation-token")

        )
    }

    func test_whenResetPasswordPollCompletion_succeeds() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .resetPasswordPollCompletion,
            correlationId: correlationId,
            responses: [.ssprPollSuccess]
        )

        let response: MSALNativeAuthResetPasswordPollCompletionResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.status)
        XCTAssertNotNil(response?.continuationToken)
        XCTAssertNil(response?.expiresIn)
    }

    func test_whenResetPasswordPollCompletion_inProgress() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .resetPasswordPollCompletion,
            correlationId: correlationId,
            responses: [.ssprPollInProgress]
        )

        let response: MSALNativeAuthResetPasswordPollCompletionResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.status)
        XCTAssertNil(response?.continuationToken)
        XCTAssertNil(response?.expiresIn)
    }

    func test_whenResetPasswordPollCompletion_failed() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .resetPasswordPollCompletion,
            correlationId: correlationId,
            responses: [.ssprPollFailed]
        )

        let response: MSALNativeAuthResetPasswordPollCompletionResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.status)
        XCTAssertNil(response?.continuationToken)
        XCTAssertNil(response?.expiresIn)
    }

    func test_whenResetPasswordPollCompletion_notStarted() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .resetPasswordPollCompletion,
            correlationId: correlationId,
            responses: [.ssprPollNotStarted]
        )

        let response: MSALNativeAuthResetPasswordPollCompletionResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.status)
        XCTAssertNil(response?.continuationToken)
        XCTAssertNil(response?.expiresIn)
    }

    func test_resetPasswordPollCompletion_unauthorizedClient() async throws {
        throw XCTSkip()
        
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .unauthorizedClient,
            expectedError: createResetPasswordPollCompletionError(error: .unauthorizedClient)
        )
    }

    func test_resetPasswordPollCompletion_invalidContinuationToken() async throws {
        throw XCTSkip()

        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .invalidContinuationToken,
            expectedError: createResetPasswordPollCompletionError(error: .invalidRequest)
        )
    }

    func test_resetPasswordPollCompletion_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .expiredToken,
            expectedError: createResetPasswordPollCompletionError(error: .expiredToken)
        )
    }

    func test_resetPasswordPollCompletion_passwordTooWeak() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .passwordTooWeak,
            expectedError: createResetPasswordPollCompletionError(error: .invalidGrant, subError: .passwordTooWeak)
        )
    }

    func test_resetPasswordPollCompletion_passwordTooShort() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .passwordTooShort,
            expectedError: createResetPasswordPollCompletionError(error: .invalidGrant, subError: .passwordTooShort)
        )
    }

    func test_resetPasswordPollCompletion_passwordTooLong() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .passwordTooLong,
            expectedError: createResetPasswordPollCompletionError(error: .invalidGrant, subError: .passwordTooLong)
        )
    }

    func test_resetPasswordPollCompletion_passwordRecentlyUsed() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .passwordRecentlyUsed,
            expectedError: createResetPasswordPollCompletionError(error: .invalidGrant, subError: .passwordRecentlyUsed)
        )
    }

    func test_resetPasswordPollCompletion_passwordBanned() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .passwordBanned,
            expectedError: createResetPasswordPollCompletionError(error: .invalidGrant, subError: .passwordBanned)
        )
    }

    func test_resetPasswordPollCompletion_userNotFound() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordPollCompletion,
            response: .userNotFound,
            expectedError: createResetPasswordPollCompletionError(error: .userNotFound)
        )
    }

    private func createResetPasswordPollCompletionError(
        error: MSALNativeAuthResetPasswordPollCompletionOauth2ErrorCode,
        subError: MSALNativeAuthSubErrorCode? = nil,
        errorDescription: String? = nil,
        errorCodes: [Int]? = nil,
        errorURI: String? = nil,
        innerErrors: [MSALNativeAuthInnerError]? = nil,
        target: String? = nil
    ) -> MSALNativeAuthResetPasswordPollCompletionResponseError {
        .init(
            error: error,
            subError: subError,
            errorDescription: errorDescription,
            errorCodes: errorCodes,
            errorURI: errorURI,
            innerErrors: innerErrors,
            target: target
        )
    }
}
