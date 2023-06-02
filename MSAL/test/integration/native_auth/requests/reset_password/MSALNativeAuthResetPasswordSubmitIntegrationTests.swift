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

    private typealias Error = MSALNativeAuthResetPasswordSubmitResponseError
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
                                                                           passwordSubmitToken: "<password-submit-token>",
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

        XCTAssertNotNil(response?.passwordResetToken)
        XCTAssertNotNil(response?.pollInterval)
    }

    func test_resetPasswordSubmit_invalidClient() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .invalidClient,
            expectedError: Error(error: .invalidClient)
        )
    }

    func test_resetPasswordSubmit_invalidPurposeToken() async throws {
        let response = try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .invalidPurposeToken,
            expectedError: Error(error: .invalidRequest)
        )

        guard let innerError = response.innerErrors?.first else {
            return XCTFail("There should be an inner error")
        }

        XCTAssertEqual(innerError.error, "invalid_purpose_token")
        XCTAssertNotNil(innerError.errorDescription)
    }

    func test_resetPasswordSubmit_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .expiredToken,
            expectedError: Error(error: .expiredToken)
        )
    }

    func test_resetPasswordSubmit_passwordTooWeak() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordTooWeak,
            expectedError: Error(error: .passwordTooWeak)
        )
    }

    func test_resetPasswordSubmit_passwordTooShort() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordTooShort,
            expectedError: Error(error: .passwordTooShort)
        )
    }

    func test_resetPasswordSubmit_passwordTooLong() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordTooLong,
            expectedError: Error(error: .passwordTooLong)
        )
    }

    func test_resetPasswordSubmit_passwordRecentlyUsed() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordRecentlyUsed,
            expectedError: Error(error: .passwordRecentlyUsed)
        )
    }

    func test_resetPasswordSubmit_passwordBanned() async throws {
        try await perform_testFail(
            endpoint: .resetPasswordSubmit,
            response: .passwordBanned,
            expectedError: Error(error: .passwordBanned)
        )
    }
}
