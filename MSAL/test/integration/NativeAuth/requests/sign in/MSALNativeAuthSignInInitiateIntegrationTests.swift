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

class MSALNativeAuthSignInInitiateIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private typealias Error = MSALNativeAuthSignInInitiateResponseError
    private var provider: MSALNativeAuthSignInRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignInRequestProvider(config: config)

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.signInInitiateRequest(
            parameters: .init(
                config: config,
                context: context,
                username: "test@contoso.com",
                challengeTypes: [.otp]
            ),
            context: context
        )
    }

    func test_succeedRequest_initiateSuccess() async throws {
        try await mockAPIHandler.addResponse(
            endpoint: .signInInitiate,
            correlationId: correlationId,
            responses: []
        )
        let response: MSALNativeAuthSignInInitiateResponse? = try await performTestSucceed()
        XCTAssertNotNil(response?.credentialToken)
    }

    func test_succeedRequest_challengeTypeRedirect() async throws {
        try await mockResponse(.challengeTypeRedirect, endpoint: .signInInitiate)
        let response: MSALNativeAuthSignInInitiateResponse? = try await performTestSucceed()

        XCTAssertNil(response?.credentialToken)
        XCTAssertEqual(response?.challengeType, .redirect)
    }

    func test_failRequest_invalidClient() async throws {
        try await perform_testFail(
            endpoint: .signInInitiate,
            response: .invalidClient,
            expectedError: Error(error: .invalidClient, errorDescription: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_userNotFound() async throws {
        try await perform_testFail(
            endpoint: .signInInitiate,
            response: .userNotFound,
            expectedError: Error(error: .invalidGrant, errorDescription: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signInInitiate,
            response: .unsupportedChallengeType,
            expectedError: Error(error: .unsupportedChallengeType, errorDescription: nil, errorURI: nil, innerErrors: nil)
        )
    }
}
