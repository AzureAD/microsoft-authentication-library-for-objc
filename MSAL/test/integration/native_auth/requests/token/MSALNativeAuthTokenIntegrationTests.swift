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

class MSALNativeAuthTokenIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private typealias Error = MSALNativeAuthTokenResponseError
    private var provider: MSALNativeAuthTokenRequestProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()

        provider = MSALNativeAuthTokenRequestProvider(requestConfigurator: MSALNativeAuthRequestConfigurator(config: config))
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)

        sut = try provider.refreshToken(
            parameters: .init(
                context: context,
                username: "test@contoso.com",
                continuationToken: nil,
                grantType: .otp,
                scope: nil,
                password: nil,
                oobCode: nil,
                includeChallengeType: false,
                refreshToken: nil
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

    func test_succeedRequest_scopesWithAmpersandAndSpaces() async throws {
        let expectation = XCTestExpectation()
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let parameters = MSALNativeAuthTokenRequestParameters(context: context,
                                                              username: "test@contoso.com",
                                                              continuationToken: nil,
                                                              grantType: .otp,
                                                              scope: "test & alt test",
                                                              password: nil,
                                                              oobCode: nil,
                                                              includeChallengeType: false,
                                                              refreshToken: nil)


        let request = try! provider.refreshToken(parameters: parameters,
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
        await fulfillment(of: [expectation], timeout: defaultTimeout)
    }

    func test_failRequest_invalidPurposeToken() async throws {
        throw XCTSkip()
        
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

    func test_failRequest_invalidPassword() async throws {
        try await perform_testFail(
            endpoint: .signInToken,
            response: .invalidPassword,
            expectedError: createError(.invalidGrant, subError: .passwordInvalid)
        )
    }

    func test_failRequest_invalidOOBValue() async throws {
        try await perform_testFail(
            endpoint: .signInToken,
            response: .invalidOOBValue,
            expectedError: createError(.invalidGrant, subError: .invalidOOBValue)
        )
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
        let result: MSALNativeAuthTokenResponseError = try await perform_uncheckedTestFail()

        let expectedError = createError(.slowDown)

        XCTAssertEqual(result.error?.rawValue, expectedError.error?.rawValue)
    }

    private func createError(_ code: MSALNativeAuthTokenOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil, errorCodes: [MSALNativeAuthESTSApiErrorCodes]? = nil) -> Error {
        .init(error: code, subError: subError, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, continuationToken: nil)
    }
}
