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

final class MSALNativeAuthSignInInitiateValidatedErrorTypeTests: XCTestCase {
    
    private typealias sut = MSALNativeAuthSignInInitiateValidatedErrorType
    private let testDescription = "testDescription"
    private let testErrorCodes = [1, 2, 3]
    private let testCorrelationId = UUID()
    private var apiErrorStub: MSALNativeAuthSignInInitiateResponseError {
        .init(
            error: .invalidRequest,
            errorDescription: testDescription,
            errorCodes: testErrorCodes
        )
    }

    // MARK: - convertToSignInStartError tests
    
    func test_convertToSignInStartError_redirect() {
        let error = sut.redirect.convertToSignInStartError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))
        
        XCTAssertEqual(error.type, .browserRequired)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.browserRequired)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
    
    func test_convertToSignInStartError_unauthorizedClient() {
        let error = sut.unauthorizedClient(apiErrorStub).convertToSignInStartError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
    
    func test_convertToSignInStartError_invalidRequest() {
        let error = sut.invalidRequest(.init(errorDescription: testDescription)).convertToSignInStartError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
    
    func test_convertToSignInStartError_invalidServerResponse() {
        let error = sut.unexpectedError(.init(errorDescription: "Unexpected response body received")).convertToSignInStartError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, "Unexpected response body received")
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
    
    func test_convertToSignInStartError_userNotFound() {
        let error = sut.userNotFound(apiErrorStub).convertToSignInStartError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .userNotFound)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
    
    func test_convertToSignInStartError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType(apiErrorStub).convertToSignInStartError(context: MSALNativeAuthRequestContextMock(correlationId: testCorrelationId))

        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
        XCTAssertEqual(error.errorCodes, testErrorCodes)
        XCTAssertEqual(error.correlationId, testCorrelationId)
    }
}
