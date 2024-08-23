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

open class MFASendChallengeDelegateSpy: MFASendChallengeDelegate {
    
    let expectation: XCTestExpectation
    var expectedError: MFAError?
    private(set) var newUserAccountResult: MSALNativeAuthUserAccountResult?
    private(set) var newSentTo: String?
    private(set) var newChannelTargetType: MSALNativeAuthChannelType?
    private(set) var newCodeLength: Int?
    private(set) var newMFARequiredState: MFARequiredState?
    private(set) var newAuthMethods: [MSALAuthMethod]?
    
    init(expectation: XCTestExpectation, expectedError: MFAError? = nil) {
        self.expectation = expectation
        self.expectedError = expectedError
    }
    
    public func onMFASendChallengeError(error: MSAL.MFAError, newState: MSAL.MFARequiredState?) {
        if let expectedError = expectedError {
            XCTAssertTrue(Thread.isMainThread)
            checkErrors(error: error, expectedError: expectedError)
            expectation.fulfill()
            return
        }
        XCTFail("This method should not be called")
        expectation.fulfill()
    }
    
    public func onMFASendChallengeSelectionRequired(authMethods: [MSALAuthMethod], newState: MFARequiredState) {
        XCTAssertTrue(Thread.isMainThread)
        newMFARequiredState = newState
        newAuthMethods = authMethods

        expectation.fulfill()
    }
    
    public func onMFASendChallengeVerificationRequired(newState: MFARequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        XCTAssertTrue(Thread.isMainThread)
        newMFARequiredState = newState
        newSentTo = sentTo
        newChannelTargetType = channelTargetType
        newCodeLength = codeLength

        expectation.fulfill()
    }
}

open class MFASendChallengeNotImplementedDelegateSpy: MFASendChallengeDelegate {
    
    let expectation: XCTestExpectation
    let expectedError: MFAError

    init(expectation: XCTestExpectation, expectedError: MFAError) {
        self.expectation = expectation
        self.expectedError = expectedError
    }
    
    public func onMFASendChallengeError(error: MSAL.MFAError, newState: MSAL.MFARequiredState?) {
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(newState)
        checkErrors(error: error, expectedError: expectedError)
        expectation.fulfill()
    }
}

fileprivate func checkErrors(error: MFAError, expectedError: MFAError?) {
    XCTAssertEqual(error.type, expectedError?.type)
    XCTAssertEqual(error.errorDescription, expectedError?.errorDescription)
    XCTAssertEqual(error.errorCodes, expectedError?.errorCodes)
    XCTAssertEqual(error.errorUri, expectedError?.errorUri)
    XCTAssertEqual(error.correlationId, expectedError?.correlationId)
}
