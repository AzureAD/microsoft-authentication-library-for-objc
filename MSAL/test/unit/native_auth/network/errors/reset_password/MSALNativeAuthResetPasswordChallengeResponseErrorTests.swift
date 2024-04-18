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

final class MSALNativeAuthResetPasswordChallengeResponseErrorTests: XCTestCase {

    private var sut: MSALNativeAuthResetPasswordChallengeResponseError!
    private let testDescription = "testDescription"
    private let testErrorCodes = [1, 2, 3]
    private let correlationId = UUID()
    private let testErrorUri = "test error uri"

    private func createApiChallengeError(type: MSALNativeAuthResetPasswordChallengeOauth2ErrorCode) -> MSALNativeAuthResetPasswordChallengeResponseError {
        .init(
            error: type,
            errorDescription: testDescription,
            errorCodes: testErrorCodes,
            errorURI: testErrorUri,
            correlationId: correlationId
        )
    }

    private func createApiResendCodeError(type: MSALNativeAuthResetPasswordChallengeOauth2ErrorCode) -> MSALNativeAuthResetPasswordChallengeResponseError {
        .init(
            error: type,
            errorDescription: testDescription,
            errorCodes: testErrorCodes,
            errorURI: testErrorUri,
            correlationId: correlationId
        )
    }

    // MARK: - to ResetPasswordStartError tests

    func test_toResetPasswordStartPublicError_unauthorizedClient() {
        sut = createApiChallengeError(type: .unauthorizedClient)
        let error = sut.toResetPasswordStartPublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResetPasswordStartPublicError_invalidRequest() {
        sut = createApiChallengeError(type: .invalidRequest)
        let error = sut.toResetPasswordStartPublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.correlationId, correlationId)
    }

    func test_toResetPasswordStartPublicError_expiredToken() {
        sut = createApiChallengeError(type: .expiredToken)
        let error = sut.toResetPasswordStartPublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResetPasswordStartPublicError_unsupportedChallengeType() {
        sut = createApiChallengeError(type: .unsupportedChallengeType)
        let error = sut.toResetPasswordStartPublicError(correlationId: correlationId)
        
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    // MARK: - to ResendCodePublicError tests

    func test_toResendCodePublicError_unauthorizedClient() {
        sut = createApiResendCodeError(type: .unauthorizedClient)
        let error = sut.toResendCodePublicError(correlationId: correlationId)
        
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResendCodePublicError_invalidRequest() {
        sut = createApiResendCodeError(type: .invalidRequest)
        let error = sut.toResendCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResendCodePublicError_expiredToken() {
        sut = createApiResendCodeError(type: .expiredToken)
        let error = sut.toResendCodePublicError(correlationId: correlationId)
        
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResendCodePublicError_unsupportedChallengeType() {
        sut = createApiResendCodeError(type: .unsupportedChallengeType)
        let error = sut.toResendCodePublicError(correlationId: correlationId)
        
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResendCodePublicError_errorUnknown() {
        sut = createApiResendCodeError(type: .unknown)
        let error = sut.toResendCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
}
