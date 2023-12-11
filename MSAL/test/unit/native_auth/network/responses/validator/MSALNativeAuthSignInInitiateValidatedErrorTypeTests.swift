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
    
    // MARK: - convertToSignInStartError tests
    
    func test_convertToSignInStartError_redirect() {
        let error = sut.redirect.convertToSignInStartError()
        XCTAssertEqual(error.type, .browserRequired)
        XCTAssertEqual(error.errorDescription, "Browser required")
    }
    
    func test_convertToSignInStartError_invalidClient() {
        let error = sut.invalidClient(message: testDescription).convertToSignInStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInStartError_invalidRequest() {
        let error = sut.invalidRequest(message: testDescription).convertToSignInStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInStartError_invalidServerResponse() {
        let error = sut.invalidServerResponse.convertToSignInStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, "General error")
    }
    
    func test_convertToSignInStartError_userNotFound() {
        let error = sut.userNotFound(message: testDescription).convertToSignInStartError()
        XCTAssertEqual(error.type, .userNotFound)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInStartError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType(message: testDescription).convertToSignInStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    // MARK: - convertToSignInPasswordStartError tests
    
    func test_convertToSignInPasswordStartError_redirect() {
        let error = sut.redirect.convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .browserRequired)
        XCTAssertEqual(error.errorDescription, "Browser required")
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
        XCTAssertEqual(error.errorDescription, "General error")
    }
    
    func test_convertToSignInPasswordStartError_userNotFound() {
        let error = sut.userNotFound(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .userNotFound)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
    func test_convertToSignInPasswordStartError_unsupportedChallengeType() {
        let error = sut.unsupportedChallengeType(message: testDescription).convertToSignInPasswordStartError()
        XCTAssertEqual(error.type, .generalError)
        XCTAssertEqual(error.errorDescription, testDescription)
    }
    
}
