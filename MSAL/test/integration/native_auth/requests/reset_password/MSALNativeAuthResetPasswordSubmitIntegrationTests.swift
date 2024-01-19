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

final class MSALNativeAuthResetPasswordSubmitIntegrationTests: MSALNativeAuthIntegrationBaseTests {

    private var provider: MSALNativeAuthResetPasswordRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        provider = MSALNativeAuthResetPasswordRequestProvider(
            requestConfigurator: MSALNativeAuthRequestConfigurator(config: config),
            telemetryProvider: MSALNativeAuthTelemetryProvider()
        )

        sut = try provider.submit(
            parameters: MSALNativeAuthResetPasswordSubmitRequestParameters(context: context,
                                                                           continuationToken: "<continuation-token>",
                                                                           newPassword:"new-password")
        )
    }

    func test_whenResetPasswordSubmit_succeeds() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .resetPasswordSubmit,
            correlationId: correlationId,
            responses: [.ssprSubmitSuccess]
        )

        let response: MSALNativeAuthResetPasswordSubmitResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.continuationToken)
        XCTAssertNotNil(response?.pollInterval)
    }

    func test_resetPasswordSubmit_unauthorizedClient() async throws {
        throw XCTSkip()
        
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .unauthorizedClient,
            expectedError: createError(.unauthorizedClient)
        )
    }

    func test_resetPasswordSubmit_invalidContinuationToken() async throws {
        throw XCTSkip()

        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .invalidContinuationToken,
            expectedError: createError(.invalidRequest)
        )
    }

    func test_resetPasswordSubmit_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .expiredToken,
            expectedError: createError(.expiredToken)
        )
    }

    func test_resetPasswordSubmit_passwordTooWeak() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordTooWeak,
            expectedError: createError(.invalidGrant, subError: .passwordTooWeak)
        )
    }

    func test_resetPasswordSubmit_passwordTooShort() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordTooShort,
            expectedError: createError(.invalidGrant, subError: .passwordTooShort)
        )
    }

    func test_resetPasswordSubmit_passwordTooLong() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordTooLong,
            expectedError: createError(.invalidGrant, subError: .passwordTooLong)
        )
    }

    func test_resetPasswordSubmit_passwordRecentlyUsed() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordRecentlyUsed,
            expectedError: createError(.invalidGrant, subError: .passwordRecentlyUsed)
        )
    }

    func test_resetPasswordSubmit_passwordBanned() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordBanned,
            expectedError: createError(.invalidGrant, subError: .passwordBanned)
        )
    }

    private func createError(_ error: MSALNativeAuthResetPasswordSubmitOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil) -> MSALNativeAuthResetPasswordSubmitResponseError {
        .init(
            error: error,
            subError: subError,
            errorDescription: nil,
            errorCodes: nil,
            errorURI: nil,
            innerErrors: nil,
            target: nil
        )
    }
}
