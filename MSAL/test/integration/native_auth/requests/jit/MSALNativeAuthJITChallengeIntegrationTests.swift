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

class MSALNativeAuthJITChallengeIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private typealias Error = MSALNativeAuthJITChallengeResponseError
    private var provider: MSALNativeAuthJITRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthJITRequestProvider(requestConfigurator: MSALNativeAuthRequestConfigurator(config: config))

        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.challenge(
            parameters: .init(context: context,
                              continuationToken: "Test Credential Token",
                              authMethod: MSALAuthMethod(id: "1",
                                                         challengeType: "oob",
                                                         loginHint: "not-used-test@contoso.com",
                                                         channelTargetType: MSALNativeAuthChannelType(value: "email")),
                              verificationContact: "test@contoso.com"),
            context: context
        )
    }

    func test_succeedRequest_challengeSuccess() async throws {
        try await mockResponse(.registrationChallengeSuccess, endpoint: .jitChallenge)
        let response: MSALNativeAuthJITChallengeResponse? = try await performTestSucceed()

        XCTAssertTrue(response?.challengeType == "oob")
        XCTAssertTrue(response?.bindingMethod == "prompt")
        XCTAssertTrue(response?.challengeTarget == "bar@contoso.com")
        XCTAssertTrue(response?.challengeChannel == "email")
        XCTAssertTrue(response?.codeLength == 8)
        XCTAssertNotNil(response?.continuationToken)
    }

    func test_failRequest_InvalidChallengeTarget() async throws {
        try await perform_testFail(
            endpoint: .jitChallenge,
            response: .registraionInvalidChallengeTarget,
            expectedError: Error(error: .invalidRequest, errorDescription: nil, errorCodes: [901001], errorURI: nil, innerErrors: nil)
        )
    }
    
    func test_failRequest_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .jitChallenge,
            response: .expiredToken,
            expectedError: Error(error: .unknown, errorDescription: nil, errorCodes: [55112], errorURI: nil, innerErrors: nil)
        )
    }

    func test_failRequest_invalidRequest() async throws {
        try await perform_testFail(
            endpoint: .jitChallenge,
            response: .invalidRequest,
            expectedError: Error(error: .invalidRequest, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil)
        )
    }
}
