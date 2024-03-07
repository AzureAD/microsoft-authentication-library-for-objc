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

final class MSALNativeAuthResetPasswordStartValidatedErrorTypeTests: XCTestCase {

    private typealias sut = MSALNativeAuthResetPasswordStartValidatedErrorType
    private var testDescription = "testDescription"
    private let testErrorCodes = [1, 2, 3]
    private let testCorrelationId = UUID()
    private let testErrorUri = "test error uri"
    private var apiErrorStub: MSALNativeAuthResetPasswordStartResponseError {
        .init(
            error: .unauthorizedClient,
            errorDescription: testDescription,
            errorCodes: testErrorCodes,
            errorURI: testErrorUri,
            correlationId: testCorrelationId
        )
    }

    // MARK: - to ResetPasswordStartError tests

    func test_toResetPasswordStartPublicError_unauthorizedClient() {
        let error = sut.unauthorizedClient(apiErrorStub).toResetPasswordStartPublicError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }

    func test_toResetPasswordStartPublicError_invalidRequest() {
        let error = sut.invalidRequest(apiErrorStub).toResetPasswordStartPublicError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
    
    func test_toResetPasswordStartPublicError_userDoesNotHavePassword() {
        testDescription = MSALNativeAuthErrorMessage.userDoesNotHavePassword
        let error = sut.userDoesNotHavePassword(apiErrorStub).toResetPasswordStartPublicError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .userDoesNotHavePassword)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.userDoesNotHavePassword)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }

    func test_toResetPasswordStartPublicError_userNotFound() {
        let error = sut.userNotFound(apiErrorStub).toResetPasswordStartPublicError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .userNotFound)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }

    func test_toResetPasswordStartPublicError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType(apiErrorStub).toResetPasswordStartPublicError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
}
