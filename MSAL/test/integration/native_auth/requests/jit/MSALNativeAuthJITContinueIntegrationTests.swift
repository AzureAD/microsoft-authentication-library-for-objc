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

class MSALNativeAuthJITContinueIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private typealias Error = MSALNativeAuthJITContinueResponseError
    private var provider: MSALNativeAuthJITRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthJITRequestProvider(requestConfigurator: MSALNativeAuthRequestConfigurator(config: config))

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.continue(
            parameters: .init(context: context,
                              grantType: .oobCode,
                              continuationToken: "Test Credential Token",
                              oobCode: "code"),
            context: context
        )
    }

    func test_succeedRequest_continueSuccess() async throws {
        try await mockResponse(.registrationContinueSuccess, endpoint: .jitContinue)
        let response: MSALNativeAuthJITContinueResponse? = try await performTestSucceed()

        XCTAssertNotNil(response?.continuationToken)
    }

    func test_failRequest_InvalidChallengeTarget() async throws {
        let result = try await perform_testFail(
            endpoint: .jitContinue,
            response: .registrationInvalidOOBValue,
            expectedError: Error(error: .invalidGrant, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, subError: .invalidOOBValue)
        )
        XCTAssertEqual(result.subError, .invalidOOBValue)
    }
    
    func test_failRequest_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .jitContinue,
            response: .expiredToken,
            expectedError: Error(error: .unknown, errorDescription: nil, errorCodes: [55112], errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_invalidRequest() async throws {
        try await perform_testFail(
            endpoint: .jitContinue,
            response: .invalidRequest,
            expectedError: Error(error: .unknown, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_invalidGrant() async throws {
        try await perform_testFail(
            endpoint: .jitContinue,
            response: .invalidGrant,
            expectedError: Error(error: .invalidGrant, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_accessDenied() async throws {
        try await perform_testFail(
            endpoint: .jitContinue,
            response: .accessDenied,
            expectedError: Error(error: .unknown, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_authorizationPending() async throws {
        try await perform_testFail(
            endpoint: .jitContinue,
            response: .authorizationPending,
            expectedError: Error(error: .unknown, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }
}
