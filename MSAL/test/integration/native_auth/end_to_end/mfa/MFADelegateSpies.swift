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

import Foundation
import XCTest
import MSAL

class MFARequestChallengeDelegateSpy: MFARequestChallengeDelegate {
    
    private let expectation: XCTestExpectation
    private(set) var onMFARequestChallengeError = false
    private(set) var error: MSAL.MFARequestChallengeError?
    
    private(set) var onVerificationRequiredCalled = false
    private(set) var newStateMFARequired: MSAL.MFARequiredState?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSAL.MSALNativeAuthChannelType?
    private(set) var codeLength: Int?
    
    private(set) var onSelectionRequiredCalled = false
    private(set) var authMethods: [MSALAuthMethod]?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    
    func onMFARequestChallengeError(error: MSAL.MFARequestChallengeError, newState: MSAL.MFARequiredState?) {
        onMFARequestChallengeError = true
        self.newStateMFARequired = newState
        self.error = error

        expectation.fulfill()
    }
    
    func onMFARequestChallengeSelectionRequired(authMethods: [MSALAuthMethod], newState: MFARequiredState) {
        onSelectionRequiredCalled = true
        self.newStateMFARequired = newState
        self.authMethods = authMethods
        
        expectation.fulfill()
    }
    
    func onMFARequestChallengeVerificationRequired(newState: MFARequiredState, sentTo: String, channelTargetType: MSALNativeAuthChannelType, codeLength: Int) {
        onVerificationRequiredCalled = true
        self.newStateMFARequired = newState
        self.sentTo = sentTo
        self.channelTargetType = channelTargetType
        self.codeLength = codeLength

        expectation.fulfill()
    }
}

final class MFASubmitChallengeDelegateSpy: MFASubmitChallengeDelegate {
    
    private let expectation: XCTestExpectation
    private(set) var onSignInCompletedCalled = false
    private(set) var onMFASubmitChallengeErrorCalled = false
    private(set) var error: MSAL.MFASubmitChallengeError?
    private(set) var result: MSAL.MSALNativeAuthUserAccountResult?
    private(set) var newStateMFARequiredState: MSAL.MFARequiredState?
    
    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    
    func onMFASubmitChallengeError(error: MSAL.MFASubmitChallengeError, newState: MSAL.MFARequiredState?) {
        onMFASubmitChallengeErrorCalled = true
        self.newStateMFARequiredState = newState
        self.error = error

        expectation.fulfill()
    }
    
    func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        onSignInCompletedCalled = true
        self.result = result

        expectation.fulfill()
    }
}
