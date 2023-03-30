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
    private var provider: MSALNativeAuthRequestProvider!
    let telemetryProvider = MSALNativeAuthTelemetryProvider()

    override func setUpWithError() throws {
        provider = MSALNativeAuthRequestProvider(config: config)
        try super.setUpWithError()
    }

    func test_succeedRequest_correctParameters() {
        let request = createCorrectRequest()
        let expectation = XCTestExpectation()
        request.send { result, error in
            if let result = result as? MSALNativeAuthSignInInitiateRequestResponse {
                XCTAssertNotNil(result.credentialToken)
            } else {
                XCTFail("Response for MSALNativeAuthSignInInitiateRequest is not of type MSALNativeAuthSignInInitiateRequestResponse")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 10)
    }

    func test_succeedRequest_challengeTypeRedirect() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInInitiate, correlationId: correlationId, responses: [.challengeTypeRedirect])
            let request = createCorrectRequest()
            request.send { result, error in
                if let result = result as? MSALNativeAuthSignInInitiateRequestResponse {
                    XCTAssertNotNil(result.challengeType)
                } else {
                    XCTFail("Response for MSALNativeAuthSignInInitiateRequest is not of type MSALNativeAuthSignInInitiateRequestResponse")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 10)
    }

    func test_failRequest_incorrectParameters() {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let parameters = MSALNativeAuthSignInInitiateRequestParameters(config: config,
                                                                       context: context,
                                                                       username: "",
                                                                       challengeType: .otp)

        let request = try! provider.signInInitiateRequest(parameters: parameters,
                                                     context: context)
        let expectation = XCTestExpectation()
        request.send { result, error in
            if let error = error as? MSALNativeAuthRequestError {
                XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidRequest)
            } else {
                XCTFail("MSALNativeAuthSignInInitiateRequest should fail with error of type MSALNativeAuthRequestError for this test")
            }
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: 10)
    }

    func test_failRequest_invalidClient() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInInitiate, correlationId: correlationId, responses: [.invalidClient])
            let request = createCorrectRequest()
            request.send { result, error in
                print("Response received \(String(describing: self.correlationId))")
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidClient)
                } else {
                    XCTFail("MSALNativeAuthSignInInitiateRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 10)
    }

    func test_failRequest_userNotFound() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInInitiate, correlationId: correlationId, responses: [.userNotFound])
            let request = createCorrectRequest()
            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.invalidGrant)
                } else {
                    XCTFail("MSALNativeAuthSignInInitiateRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 10)
    }

    func test_failRequest_unsupportedChallengeType() async {
        let expectation = XCTestExpectation()
        do {
            try await mockAPIHandler.addResponse(endpoint: .signInInitiate, correlationId: correlationId, responses: [.unsupportedChallengeType])
            let request = createCorrectRequest()

            request.send { result, error in
                if let error = error as? MSALNativeAuthRequestError {
                    XCTAssertEqual(error.error, NativeAuthOauth2ErrorCode.unsupportedChallengeType)
                } else {
                    XCTFail("MSALNativeAuthSignInInitiateRequest should fail with error of type MSALNativeAuthRequestError for this test")
                }
                expectation.fulfill()
            }

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTWaiter().wait(for: [expectation], timeout: 10)
    }

    private func createCorrectRequest() -> MSALNativeAuthSignInInitiateRequest {
        let context = MSALNativeAuthRequestContext(correlationId: correlationId)
        let parameters = MSALNativeAuthSignInInitiateRequestParameters(config: config,
                                                                       context: context,
                                                                       username: "test@contoso.com",
                                                                       challengeType: .otp)

        return try! provider.signInInitiateRequest(parameters: parameters,
                                                          context: context)
    }
}
