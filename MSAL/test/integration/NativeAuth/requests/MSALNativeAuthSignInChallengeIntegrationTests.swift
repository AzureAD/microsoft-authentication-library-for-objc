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

class MSALNativeAuthSignInChallengeIntegrationTests: MSALNativeAuthIntegrationBaseTests {
    private var provider: MSALNativeAuthRequestProvider!

    override func setUpWithError() throws {
        provider = MSALNativeAuthRequestProvider(config: config)
        try super.setUpWithError()
    }

    func test_succeedRequest_challengeTypePassword() async throws {
        let expectation = XCTestExpectation()
        try await mockAPIHandler.addResponse(endpoint: .signInChallenge, correlationId: correlationId, responses: [.challengeTypePassword])
        let request = createRequest()
        request.send { result, error in
            if let result = result as? MSALNativeAuthSignInChallengeRequestResponse {
                XCTAssertTrue(result.challengeType == .password)
                XCTAssertNotNil(result.credentialToken)
            } else {
                XCTFail("Response for MSALNativeAuthSignInChallengeRequest is not of type MSALNativeAuthSignInChallengeRequestResponse")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_succeedRequest_challengeTypeOOB() async throws {
        let expectation = XCTestExpectation()
        try await mockAPIHandler.addResponse(endpoint: .signInChallenge, correlationId: correlationId, responses: [.challengeTypeOOB])
        let request = createRequest()
        request.send { result, error in
            if let result = result as? MSALNativeAuthSignInChallengeRequestResponse {
                XCTAssertTrue(result.challengeType == .oob)
                XCTAssertNotNil(result.credentialToken)
            } else {
                XCTFail("Response for MSALNativeAuthSignInChallengeRequest is not of type MSALNativeAuthSignInChallengeRequestResponse")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_succeedRequest_challengeTypeRedirect() async throws {
        let expectation = XCTestExpectation()
        try await mockAPIHandler.addResponse(endpoint: .signInChallenge, correlationId: correlationId, responses: [.challengeTypeRedirect])
        let request = createRequest()
        request.send { result, error in
            if let result = result as? MSALNativeAuthSignInChallengeRequestResponse {
                XCTAssertTrue(result.challengeType == .redirect)
            } else {
                XCTFail("Response for MSALNativeAuthSignInChallengeRequest is not of type MSALNativeAuthSignInChallengeRequestResponse")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }


    func test_failRequest_invalidClient() async throws {
        let expectation = XCTestExpectation()
        try await mockAPIHandler.addResponse(endpoint: .signInChallenge, correlationId: correlationId, responses: [.invalidClient])
        let request = createRequest()
        request.send { result, error in
            if let error = error as? MSALNativeAuthRequestError {
                XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidClient)
            } else {
                XCTFail("MSALNativeAuthSignInChallengeRequest should fail with error of type MSALNativeAuthRequestError for this test")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_invalidPurposeToken() async throws {
        let expectation = XCTestExpectation()
        try await mockAPIHandler.addResponse(endpoint: .signInChallenge, correlationId: correlationId, responses: [.invalidPurposeToken])
        let request = createRequest()
        request.send { result, error in
            if let error = error as? MSALNativeAuthRequestError {
                XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidRequest)
                XCTAssertNotNil(error.errorDescription)
                XCTAssertNotNil(error.errorURI)
                XCTAssertEqual(error.innerErrors![0].error, NativeAuthOauth2ErrorCode.invalidPurposeToken)
                XCTAssertEqual(error.innerErrors![0].errorDescription, "Invalid purpose token")
            } else {
                XCTFail("MSALNativeAuthSignInChallengeRequest should fail with error of type MSALNativeAuthRequestError for this test")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_expiredToken() async throws {
        let expectation = XCTestExpectation()
        try await mockAPIHandler.addResponse(endpoint: .signInChallenge, correlationId: correlationId, responses: [.expiredToken])
        let request = createRequest()

        request.send { result, error in
            if let error = error as? MSALNativeAuthRequestError {
                XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.expiredToken)
            } else {
                XCTFail("MSALNativeAuthSignInChallengeRequest should fail with error of type MSALNativeAuthRequestError for this test")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }

    func test_failRequest_unsupportedChallengeType() async throws {
        let expectation = XCTestExpectation()
        try await mockAPIHandler.addResponse(endpoint: .signInChallenge, correlationId: correlationId, responses: [.unsupportedChallengeType])
        let request = createRequest()

        request.send { result, error in
            if let error = error as? MSALNativeAuthRequestError {
                XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.unsupportedChallengeType)
            } else {
                XCTFail("MSALNativeAuthSignInChallengeRequest should fail with error of type MSALNativeAuthRequestError for this test")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 2)
    }
    
    private func createRequest() -> MSALNativeAuthSignInChallengeRequest {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let parameters = MSALNativeAuthSignInChallengeRequestParameters(config: config,
                                                                        context: context,
                                                                        credentialToken: "Test Credential Token",
                                                                        challengeType: nil,
                                                                        challengeTarget: nil)

        return try! provider.signInChallengeRequest(parameters: parameters,
                                                    context: context)
    }
}
