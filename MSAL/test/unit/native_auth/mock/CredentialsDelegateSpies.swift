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

@testable import MSAL
import XCTest

open class CredentialsDelegateSpy: CredentialsDelegate {

    private let expectation: XCTestExpectation
    var expectedError: RetrieveAccessTokenError?
    var expectedAccessToken: String?
    
    init(expectation: XCTestExpectation, expectedError: RetrieveAccessTokenError? = nil, expectedAccessToken: String? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
        self.expectedAccessToken = expectedAccessToken
    }

    public func onAccessTokenRetrieveCompleted(accessToken: String) {
        if let expectedAccessToken = expectedAccessToken {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(expectedAccessToken, accessToken)
        } else {
            XCTFail("This method should not be called")
        }
        expectation.fulfill()
    }

    public func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(error.type, expectedError.type)
            XCTAssertEqual(error.errorDescription, expectedError.errorDescription)
            XCTAssertEqual(error.correlationId, expectedError.correlationId)
            XCTAssertEqual(error.errorCodes, expectedError.errorCodes)
            expectation.fulfill()
            return
        }
    }
}

final class CredentialsDelegateOptionalMethodsNotImplemented: CredentialsDelegate {

    private let expectation: XCTestExpectation
    var expectedError: RetrieveAccessTokenError?

    init(expectation: XCTestExpectation, expectedError: RetrieveAccessTokenError? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
    }

    public func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(error.type, expectedError.type)
            XCTAssertEqual(error.errorDescription, expectedError.errorDescription)
            expectation.fulfill()
            return
        }
    }
}

class CredentialsTestValidatorHelper: CredentialsDelegateSpy {

    func onAccessTokenRetrieveCompleted(_ response: MSALNativeAuthCredentialsController.RefreshTokenCredentialControllerResponse) {
        guard case let .success(token) = response.result else {
            return XCTFail("wrong result")
        }

        Task { await self.onAccessTokenRetrieveCompleted(accessToken: token) }
    }

    func onAccessTokenRetrieveError(_ response: MSALNativeAuthCredentialsController.RefreshTokenCredentialControllerResponse) {
        guard case let .failure(error) = response.result else {
            return XCTFail("wrong result")
        }

        Task { await self.onAccessTokenRetrieveError(error: error) }
    }
}
