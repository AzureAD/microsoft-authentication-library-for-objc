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
    private var provider: MSALNativeAuthRequestProvider!

    override func setUpWithError() throws {
        provider = MSALNativeAuthRequestProvider(config: config)
        try super.setUpWithError()
    }

    func test_succeedRequest_tokenSuccess() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.tokenSuccess])
            let request = createRequest()
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

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_credentialRequired() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.credentialRequired])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.credentialRequired)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_invalidPurposeToken() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.invalidPurposeToken])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidRequest)
                    XCTAssertNotNil(error.errorDescription)
                    XCTAssertNotNil(error.errorURI)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_invalidPasword() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.invalidPassword])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidGrant)
                    XCTAssertNotNil(error.errorDescription)
                    XCTAssertNotNil(error.errorURI)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_invalidOOBValue() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.invalidOOBValue])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidGrant)
                    XCTAssertNotNil(error.errorDescription)
                    XCTAssertNotNil(error.errorURI)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_invalidGrant() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.invalidGrant])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidGrant)
                    XCTAssertNotNil(error.errorDescription)
                    XCTAssertNotNil(error.errorURI)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_expiredToken() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.expiredToken])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.expiredToken)
                    XCTAssertNotNil(error.errorDescription)
                    XCTAssertNotNil(error.errorURI)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_unsupportedChallengeType() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.unsupportedChallengeType])
            let request = createRequest()

            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.unsupportedChallengeType)
                    XCTAssertNotNil(error.errorDescription)
                    XCTAssertNotNil(error.errorURI)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_succeedRequest_authorizationPending() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.authorizationPending])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.authorizationPending)
                    XCTAssertNotNil(error.errorDescription)
                    XCTAssertNotNil(error.errorURI)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_succeedRequest_slowDown() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInToken, correlationId: correlationId, responses: [.slowDown])
            let request = createRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.slowDown)
                    XCTAssertNotNil(error.errorDescription)
                } else {
                    XCTFail("MSALNativeAuthSignInTokenRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }


    private func createRequest() -> MSALNativeAuthSignInTokenRequest {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let parameters = MSALNativeAuthSignInTokenRequestParameters(config: config,
                                                                    context: context,
                                                                    username: "test@contoso.com",
                                                                    grantType: .otp)

        return try! provider.signInTokenRequest(parameters: parameters,
                                                context: context)
    }
}
