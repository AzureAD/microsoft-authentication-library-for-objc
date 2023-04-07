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

class MSALNativeAuthSignInTokenIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private typealias Error = MSALNativeAuthSignInTokenRequestError
    private var provider: MSALNativeAuthSignInRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthSignInRequestProvider(config: config)
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.signInTokenRequest(
            parameters: .init(
                config: config,
                context: context,
                username: "test@contoso.com",
                credentialToken: nil,
                signInSLT: nil,
                grantType: .otp,
                challengeTypes: nil,
                scope: nil,
                password: nil,
                oob: nil
            ),
            context: context
        )
    }

    func test_succeedRequest_tokenSuccess() async throws {
        try await mockResponse(.tokenSuccess, endpoint: .signInToken)
        let response: [String: Any]? = try await performTestSucceed()

        XCTAssertNotNil(response?["token_type"])
        XCTAssertNotNil(response?["scope"])
        XCTAssertNotNil(response?["ext_expires_in"])
        XCTAssertNotNil(response?["refresh_token"])
        XCTAssertNotNil(response?["access_token"])
        XCTAssertNotNil(response?["id_token"])
        XCTAssertNotNil(response?["expires_in"])
    }

    func test_failRequest_credentialRequired() async throws {
        let expectedError = createError(.credentialRequired)

        try await mockResponse(.credentialRequired, endpoint: .signInToken)
        let result: MSALNativeAuthSignInTokenRequestError = try await perform_uncheckedTestFail()

        XCTAssertEqual(result.error.rawValue, expectedError.error.rawValue)
        XCTAssertNotNil(result.credentialToken)
    }

    func test_succeedRequest_scopesWithAmpersandAndSpaces() async throws {
        let expectation = XCTestExpectation()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let parameters = MSALNativeAuthSignInTokenRequestParameters(config: config,
                                                                    context: context,
                                                                    username: "test@contoso.com",
                                                                    credentialToken: nil,
                                                                    signInSLT: nil,
                                                                    grantType: .otp,
                                                                    challengeTypes: nil,
                                                                    scope: "test & alt test",
                                                                    password: nil,
                                                                    oob: nil)


        let request = try! provider.signInTokenRequest(parameters: parameters,
                                                       context: context)

        request.send { result, error in
            if let result = result as? [String: Any] {
                XCTAssertNotNil(result["token_type"])
                XCTAssertNotNil(result["scope"])
                XCTAssertNotNil(result["ext_expires_in"])
                XCTAssertNotNil(result["refresh_token"])
                XCTAssertNotNil(result["access_token"])
                XCTAssertNotNil(result["id_token"])
                XCTAssertNotNil(result["expires_in"])
            } else {
                XCTFail("MSALNativeAuthSignInTokenRequest should return a [String: Any] structure in this test")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_invalidPurposeToken() async throws {
        let response = try await perform_testFail(
            endpoint: .signInToken,
            response: .invalidPurposeToken,
            expectedError: createError(.invalidRequest)
        )

        guard let innerError = response.innerErrors?.first else {
            return XCTFail("There should be an inner error")
        }

        XCTAssertEqual(innerError.error, "invalid_purpose_token")
        XCTAssertNotNil(innerError.errorDescription)
    }

    func test_failRequest_invalidPasword() async throws {
        let response = try await perform_testFail(
            endpoint: .signInToken,
            response: .invalidPassword,
            expectedError: createError(.invalidGrant)
        )

        guard let innerError = response.innerErrors?.first else {
            return XCTFail("There should be an inner error")
        }

        XCTAssertEqual(innerError.error, "invalid_password")
        XCTAssertNotNil(innerError.errorDescription)
    }

    func test_failRequest_invalidOOBValue() async throws {
        let response = try await perform_testFail(
            endpoint: .signInToken,
            response: .invalidOOBValue,
            expectedError: createError(.invalidGrant)
        )

        guard let innerError = response.innerErrors?.first else {
            return XCTFail("There should be an inner error")
        }

        XCTAssertEqual(innerError.error, "invalid_oob_value")
        XCTAssertNotNil(innerError.errorDescription)
    }

    func test_failRequest_invalidGrant() async throws {
        try await perform_testFail(
            endpoint: .signInToken,
            response: .invalidGrant,
            expectedError: createError(.invalidGrant)
        )
    }

    func test_failRequest_expiredToken() async throws {
        try await perform_testFail(
            endpoint: .signInToken,
            response: .expiredToken,
            expectedError: createError(.expiredToken)
        )
    }

    func test_failRequest_unsupportedChallengeType() async throws {
        try await perform_testFail(
            endpoint: .signInToken,
            response: .unsupportedChallengeType,
            expectedError: createError(.unsupportedChallengeType)
        )
    }

    func test_succeedRequest_authorizationPending() async throws {
        try await perform_testFail(
            endpoint: .signInToken,
            response: .authorizationPending,
            expectedError: createError(.authorizationPending)
        )
    }

    func test_succeedRequest_slowDown() async throws {
        try await mockResponse(.slowDown, endpoint: .signInToken)
        let result: MSALNativeAuthSignInTokenRequestError = try await perform_uncheckedTestFail()

        let expectedError = createError(.slowDown)

        XCTAssertEqual(result.error.rawValue, expectedError.error.rawValue)
        XCTAssertNotNil(result.interval)
    }

    private func createError(_ code: MSALNativeAuthSignInTokenOauth2ErrorCode) -> Error {
        .init(error: code, errorDescription: nil, errorURI: nil, innerErrors: nil, credentialToken: nil, interval: nil)
    }
}
