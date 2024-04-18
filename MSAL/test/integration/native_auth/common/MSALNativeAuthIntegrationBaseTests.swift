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

    var defaultTimeout: TimeInterval = 5
    let mockAPIHandler = MockAPIHandler()
    let correlationId = UUID()
    let config: MSALNativeAuthConfiguration = try! MSALNativeAuthConfiguration(clientId: UUID().uuidString,
                                                                               authority: MSALCIAMAuthority(url: URL(string: (ProcessInfo.processInfo.environment["authorityURL"] ?? "<mock api url not set>") + "/test")!),
                                                                               challengeTypes: [.password, .oob, .redirect])
    var sut: MSIDHttpRequest!
    
    override func tearDown() {
        try? mockAPIHandler.clearQueues(correlationId: correlationId)
    }

    // MARK: - Utility methods

    func performTestSucceed<T: Any>() async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let exp = expectation(description: "msal_native_auth_integration_test_exp")

            sut.send { response, error in
                guard error == nil else {
                    XCTFail("Error should be nil")
                    continuation.resume(throwing: MockAPIError.invalidRequest)
                    return
                }

                guard let response = response as? T else {
                    XCTFail("Response should be castable to `T`")
                    continuation.resume(throwing: MockAPIError.invalidRequest)
                    return
                }

                continuation.resume(returning: response)
                exp.fulfill()
            }

            wait(for: [exp], timeout: defaultTimeout)
        }
    }

    @discardableResult
    func perform_testFail<Error: MSALNativeAuthResponseError>(
        endpoint: MockAPIEndpoint,
        response: MockAPIResponse,
        expectedError: Error
    ) async throws -> Error {
        try await mockResponse(response, endpoint: endpoint)
        let response: Error = try await perform_uncheckedTestFail()

        XCTAssertEqual(response.error?.rawValue, expectedError.error?.rawValue)

        // TODO: Fix these checks
        if expectedError.errorDescription != nil {
            XCTAssertNotNil(response.errorDescription)
        }
        if expectedError.errorCodes != nil {
            XCTAssertEqual(response.errorCodes, expectedError.errorCodes)
        }

        if expectedError.errorURI != nil {
            XCTAssertNotNil(response.errorURI)
        }
        return response
    }

    func mockResponse(_ response: MockAPIResponse, endpoint: MockAPIEndpoint) async throws {
        try await mockAPIHandler.addResponse(
            endpoint: endpoint,
            correlationId: correlationId,
            responses: [response]
        )
    }

    func perform_uncheckedTestFail<T: MSALNativeAuthResponseError>() async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let exp = expectation(description: "msal_native_auth_integration_test_exp")

            sut.send { response, error in
                guard response == nil else {
                    XCTFail("Response should be nil")
                    continuation.resume(throwing: MockAPIError.invalidRequest)
                    return
                }

                guard let error = error as? T else {
                    XCTFail("Error should be MSALNativeAuthResponseError")
                    continuation.resume(throwing: MockAPIError.invalidRequest)
                    return
                }

                continuation.resume(returning: error)
                exp.fulfill()
            }

            wait(for: [exp], timeout: defaultTimeout)
        }
    }
}
