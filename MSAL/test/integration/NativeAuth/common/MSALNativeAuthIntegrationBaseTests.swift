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

class MSALNativeAuthIntegrationBaseTests: XCTestCase {
    
    let mockAPIHandler = MockAPIHandler()
    let correlationId = UUID()
    let config: MSALNativeAuthConfiguration = try! MSALNativeAuthConfiguration(clientId: UUID().uuidString,
                                                                               authority: MSALAADAuthority(url:  URL(string: "https://native-ux-mock-api.azurewebsites.net/test")!),
                                                                               rawTenant: "test")
    var sut: MSIDHttpRequest!
    
    override func tearDown() {
        try? mockAPIHandler.clearQueues(correlationId: correlationId)
    }

    func performTestSucceed<T: Any>() async -> T? {
        return await withCheckedContinuation { continuation in
            let exp = expectation(description: "msal_native_auth_integration_test_exp")

            sut.send { response, error in
                guard error == nil else {
                    XCTFail("Error should be nil")
                    continuation.resume(returning: nil)
                    return
                }

                guard let response = response as? T else {
                    XCTFail("Response should be castable to `T`")
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: response)
                exp.fulfill()
            }

            wait(for: [exp], timeout: 3)
        }
    }

    func performTestFail() async -> MSALNativeAuthRequestError? {
        return await withCheckedContinuation { continuation  in
            let exp = expectation(description: "msal_native_auth_integration_test_exp")

            sut.send { response, error in
                guard response == nil else {
                    XCTFail("Response should be nil")
                    continuation.resume(returning: nil)
                    return
                }

                guard let error = error as? MSALNativeAuthRequestError else {
                    XCTFail("Error should be MSALNativeAuthRequestError")
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: error)
                exp.fulfill()
            }

            wait(for: [exp], timeout: 3)
        }
    }

    func mockResponse(_ response: MockAPIResponse, endpoint: MockAPIEndpoint) async throws {
        try await mockAPIHandler.addResponse(
            endpoint: endpoint,
            correlationId: correlationId,
            responses: [response]
        )
    }

    // MARK: - Common Fail test cases

    func perform_testFail_invalidClient(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.invalidClient, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .invalidClient)
    }

    func perform_testFail_invalidPurposeToken(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.invalidPurposeToken, endpoint: endpoint)

        let response = await performTestFail()
        XCTAssertEqual(response?.error, .invalidRequest)

        guard let innerError = response?.innerErrors?.first else {
            return XCTFail("There should be an inner error")
        }

        XCTAssertEqual(innerError.error, .invalidPurposeToken)
        XCTAssertNotNil(innerError.errorDescription)
    }

    func perform_testFail_expiredToken(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.expiredToken, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .expiredToken)
    }

    func perform_testFail_unsupportedChallengeType(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.unsupportedChallengeType, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .unsupportedChallengeType)
    }

    func perform_testFail_passwordTooWeak(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.passwordTooWeak, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .passwordTooWeak)
    }

    func perform_testFail_passwordTooShort(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.passwordTooShort, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .passwordTooShort)
    }

    func perform_testFail_passwordTooLong(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.passwordTooLong, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .passwordTooLong)
    }

    func perform_testFail_passwordRecentlyUsed(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.passwordRecentlyUsed, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .passwordRecentlyUsed)
    }

    func perform_testFail_passwordBanned(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.passwordBanned, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .passwordBanned)
    }

    func perform_testFail_userAlreadyExists(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.userAlreadyExists, endpoint: endpoint)
        let response = await performTestFail()
        XCTAssertEqual(response?.error, .userAlreadyExists)
    }

    func perform_testFail_attributesRequired(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.attributesRequired, endpoint: endpoint)

        let response = await performTestFail()
        XCTAssertEqual(response?.error, .attributesRequired)
        XCTAssertNotNil(response?.signUpToken)
    }

    func perform_testFail_verificationRequired(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.verificationRequired, endpoint: endpoint)

        let response = await performTestFail()
        XCTAssertEqual(response?.error, .verificationRequired)
        XCTAssertNotNil(response?.signUpToken)
        XCTAssertNotNil(response?.attributesToVerify)
    }

    func perform_testFail_validationFailed(endpoint: MockAPIEndpoint) async throws {
        try await mockResponse(.validationFailed, endpoint: endpoint)

        let response = await performTestFail()
        XCTAssertEqual(response?.error, .validationFailed)
        XCTAssertNotNil(response?.signUpToken)
    }
}
