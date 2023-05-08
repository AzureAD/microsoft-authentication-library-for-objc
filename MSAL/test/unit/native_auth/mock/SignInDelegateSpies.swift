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

open class SignInStartDelegateSpy: SignInStartDelegate {
    
    private let expectation: XCTestExpectation
    var expectedError: SignInStartError?
    
    init(expectation: XCTestExpectation, expectedError: SignInStartError? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
    }
    
    public func onSignInError(error: MSAL.SignInStartError) {
        if let expectedError = expectedError {
            XCTAssertEqual(error.type, expectedError.type)
            XCTAssertEqual(error.errorDescription, expectedError.errorDescription)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
    
    public func onSignInCodeSent(newState: MSAL.SignInCodeSentState, displayName: String, codeLength: Int) {
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
    
    public func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccount) {
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
}
