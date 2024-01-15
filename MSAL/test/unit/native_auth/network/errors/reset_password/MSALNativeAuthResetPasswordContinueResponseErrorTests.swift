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

    // MARK: - to toVerifyCodePublicError tests
    
    func test_toResetPasswordStartPublicError_invalidRequest() {
        sut = MSALNativeAuthResetPasswordContinueResponseError(error: .invalidRequest, subError: nil, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil, continuationToken: nil)
        let error = sut.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertNotNil(error.errorDescription)
    }
    
    func test_toResetPasswordStartPublicError_unauthorizedClient() {
        sut = MSALNativeAuthResetPasswordContinueResponseError(error: .unauthorizedClient, subError: nil, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil, continuationToken: nil)
        let error = sut.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }

    func test_toResetPasswordStartPublicError_invalidGrant() {
        sut = MSALNativeAuthResetPasswordContinueResponseError(error: .invalidGrant, subError: nil, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil, continuationToken: nil)
        let error = sut.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_toResetPasswordStartPublicError_expiredToken() {
        sut = MSALNativeAuthResetPasswordContinueResponseError(error: .expiredToken, subError: nil, errorDescription: testDescription, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil, continuationToken: nil)
        let error = sut.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }

    func test_toResetPasswordStartPublicError_unsupportedChallengeType() {
        sut = MSALNativeAuthResetPasswordContinueResponseError(error: .verificationRequired, subError: nil, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil, continuationToken: nil)
        let error = sut.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertNotNil(error.errorDescription)
    }
    
    func test_toResetPasswordStartPublicError_invalidOOBValue() {
        sut = MSALNativeAuthResetPasswordContinueResponseError(error: .invalidGrant, subError: .invalidOOBValue, errorDescription: nil, errorCodes: nil, errorURI: nil, innerErrors: nil, target: nil, continuationToken: nil)
        let error = sut.toVerifyCodePublicError()
        XCTAssertEqual(error.type, .invalidCode)
        XCTAssertNotNil(error.errorDescription)
    }
}
