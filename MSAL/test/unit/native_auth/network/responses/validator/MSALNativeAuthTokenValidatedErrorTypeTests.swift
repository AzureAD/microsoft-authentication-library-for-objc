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

final class MSALNativeAuthTokenValidatedErrorTypeTests: XCTestCase {
    
    private typealias sut = MSALNativeAuthTokenValidatedErrorType
    private let testDescription = "testDescription"
    
    // MARK: - convertToSignInPasswordStartError tests
    
    func test_convertToSignInPasswordStartError_generalError() {
        let error = sut.generalError.convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, "General error")
    }
    
    func test_convertToSignInPasswordStartError_expiredToken() {
        let error = sut.expiredToken(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_expiredRefreshToken() {
        let error = sut.expiredRefreshToken(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_invalidClient() {
        let error = sut.invalidClient(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_invalidRequest() {
        let error = sut.invalidRequest(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_invalidServerResponse() {
        let error = sut.invalidServerResponse.convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, MSALNativeAuthErrorMessage.invalidServerResponse)
    }
    
    func test_convertToSignInPasswordStartError_userNotFound() {
        let error = sut.userNotFound(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .userNotFound)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_invalidPassword() {
        let error = sut.invalidPassword(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .invalidPassword)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_invalidOOBCode() {
        let error = sut.invalidOOBCode(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_strongAuthRequired() {
        let error = sut.strongAuthRequired(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .browserRequired)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_invalidScope() {
        let error = sut.invalidScope(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_authorizationPending() {
        let error = sut.authorizationPending(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_slowDown() {
        let error = sut.slowDown(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
}
