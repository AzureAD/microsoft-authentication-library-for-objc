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

class MSALNativeAuthJITControllerMock: MSALNativeAuthJITControlling {

    private(set) var continuationToken: String?
    private(set) var authMethod: MSALAuthMethod?
    private(set) var verificationContact: String?
    private(set) var challenge: String?
    private(set) var context: MSALNativeAuthRequestContext?
    private(set) var grantType: MSALNativeAuthGrantType?
    var expectation: XCTestExpectation?

    var getJITAuthMethodsResponse: JITGetJITAuthMethodsControllerResponse!
    var requestJITChallengeResponse: JITRequestChallengeControllerResponse!
    var submitJITChallengeResponse: JITSubmitChallengeControllerResponse!

    func getJITAuthMethods(continuationToken: String, context: MSALNativeAuthRequestContext) async -> JITGetJITAuthMethodsControllerResponse {
        self.continuationToken = continuationToken
        self.context = context
        expectation?.fulfill()
        return getJITAuthMethodsResponse
    }

    func requestJITChallenge(continuationToken: String, authMethod: MSALAuthMethod, verificationContact: String?, context: MSALNativeAuthRequestContext) async -> JITRequestChallengeControllerResponse {
        self.continuationToken = continuationToken
        self.authMethod = authMethod
        self.verificationContact = verificationContact
        self.context = context
        expectation?.fulfill()
        return requestJITChallengeResponse
    }

    func submitJITChallenge(challenge: String?, continuationToken: String, grantType: MSALNativeAuthGrantType, context: MSALNativeAuthRequestContext) async -> JITSubmitChallengeControllerResponse {
        self.challenge = challenge
        self.continuationToken = continuationToken
        self.grantType = grantType
        self.context = context
        expectation?.fulfill()
        return submitJITChallengeResponse
    }
}
