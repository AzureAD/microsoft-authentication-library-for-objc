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

final class MSALNativeAuthResetPasswordContinueResponseErrorTests: XCTestCase {

    private var sut: MSALNativeAuthResetPasswordContinueResponseError!
    private let testDescription = "testDescription"
    private let testErrorCodes = [1, 2, 3]
    private let correlationId = UUID()
    private let testErrorUri = "test error uri"

    private func createApiError(type: MSALNativeAuthResetPasswordContinueOauth2ErrorCode, subError: MSALNativeAuthSubErrorCode? = nil) -> MSALNativeAuthResetPasswordContinueResponseError {
        .init(
            error: type,
            subError: subError,
            errorDescription: testDescription,
            errorCodes: testErrorCodes,
            errorURI: testErrorUri,
            correlationId: correlationId
        )
    }

    // MARK: - to toVerifyCodePublicError tests
    
    func test_toResetPasswordStartPublicError_invalidRequest() {
        sut = createApiError(type: .invalidRequest)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_toResetPasswordStartPublicError_unauthorizedClient() {
        sut = createApiError(type: .unauthorizedClient)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResetPasswordStartPublicError_invalidGrant() {
        sut = createApiError(type: .invalidGrant)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)
        
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_toResetPasswordStartPublicError_expiredToken() {
        sut = createApiError(type: .expiredToken)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResetPasswordStartPublicError_unsupportedChallengeType() {
        sut = createApiError(type: .verificationRequired)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)
        
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
    
    func test_toResetPasswordStartPublicError_invalidOOBValue() {
        sut = createApiError(type: .invalidGrant, subError: .invalidOOBValue)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .invalidCode)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResetPasswordStartPublicError_errorUnknown() {
        sut = createApiError(type: .unknown, subError: .invalidOOBValue)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }

    func test_toResetPasswordStartPublicError_suberrorUnknown() {
        sut = createApiError(type: .invalidGrant, subError: .unknown)
        let error = sut.toVerifyCodePublicError(correlationId: correlationId)

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, correlationId)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.errorUri, testErrorUri)
    }
}
