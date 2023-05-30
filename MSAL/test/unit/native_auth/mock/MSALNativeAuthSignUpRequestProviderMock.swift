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
@_implementationOnly import MSAL_Private

class MSALNativeAuthSignUpRequestProviderMock: MSALNativeAuthSignUpRequestProviding {
    private var requestStart: MSIDHttpRequest?
    private var requestChallenge: MSIDHttpRequest?
    private var requestContinue: MSIDHttpRequest?
    private var throwErrorStart = false
    private var throwErrorChallenge = false
    private var throwErrorContinue = false
    private(set) var startCalled = false
    private(set) var challengeCalled = false
    private(set) var continueCalled = false

    func mockStartRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        self.requestStart = request
        self.throwErrorStart = throwError
    }

    func start(parameters: MSAL.MSALNativeAuthSignUpStartRequestProviderParameters) throws -> MSIDHttpRequest {
        startCalled = true
        
        if let request = requestStart {
            return request
        } else if throwErrorStart {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockStartRequestFunc()")
        }
    }

    func mockChallengeRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        self.requestChallenge = request
        self.throwErrorChallenge = throwError
    }

    func challenge(token: String, context: MSIDRequestContext) throws -> MSIDHttpRequest {
        challengeCalled = true

        if let request = requestChallenge {
            return request
        } else if throwErrorChallenge {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockChallengeRequestFunc()")
        }
    }

    func mockContinueRequestFunc(_ request: MSIDHttpRequest?, throwError: Bool = false) {
        self.requestContinue = request
        self.throwErrorContinue = throwError
    }

    func `continue`(parameters: MSAL.MSALNativeAuthSignUpContinueRequestProviderParams) throws -> MSIDHttpRequest {
        continueCalled = true

        if let request = requestContinue {
            return request
        } else if throwErrorContinue {
            throw ErrorMock.error
        } else {
            fatalError("Make sure to use mockContinueRequestFunc()")
        }
    }
}
