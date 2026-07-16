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
@_implementationOnly import MSAL_Private

class MSALNativeAuthV2RequestProviderMock: MSALNativeAuthV2RequestProviding {

    var throwError = false

    private(set) var authorizeChallengeStartCalled = false
    private(set) var authorizeChallengeContinueCalled = false
    private(set) var tokenCalled = false
    private(set) var tokenScopes: [String]?
    private(set) var resetPasswordStartCalled = false
    private(set) var signInStartCalled = false
    private(set) var signUpStartCalled = false
    private(set) var submitPasswordCalled = false
    private(set) var submitCodeCalled = false
    private(set) var submitAttributesCalled = false
    private(set) var registerMethodCalled = false
    private(set) var challengeCalled = false
    private(set) var verifyCalled = false
    private(set) var updatePasswordCalled = false
    private(set) var pollCalled = false

    private(set) var challengeHrefReceived: String?
    private(set) var verifyHrefReceived: String?
    private(set) var submitPasswordHrefReceived: String?
    private(set) var submitCodeHrefReceived: String?
    private(set) var submitAttributesHrefReceived: String?
    private(set) var submitAttributesReceived: [String: Any]?
    private(set) var submitAttributesHistory: [[String: Any]] = []
    private(set) var registerMethodHrefReceived: String?
    private(set) var updateHrefReceived: String?
    private(set) var pollHrefReceived: String?

    func mockRequest(throwError: Bool = false) {
        self.throwError = throwError
    }

    private func resolveRequest() throws -> MSIDHttpRequest {
        if throwError {
            throw ErrorMock.error
        }
        // A fresh stubbed request per call queues its own MSIDTestURLSession response,
        // so flows that perform multiple sends each find a matching response.
        return MSALNativeAuthHTTPRequestMock.prepareMockRequest()
    }

    func authorizeChallengeStart(context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        authorizeChallengeStartCalled = true
        return try resolveRequest()
    }

    func authorizeChallengeContinue(continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        authorizeChallengeContinueCalled = true
        return try resolveRequest()
    }

    func token(code: String, scopes: [String], context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        tokenCalled = true
        tokenScopes = scopes
        return try resolveRequest()
    }

    func resetPasswordStart(username: String, continuationToken: String, href: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        resetPasswordStartCalled = true
        return try resolveRequest()
    }

    func signInStart(username: String, continuationToken: String, href: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        signInStartCalled = true
        return try resolveRequest()
    }

    func signUpStart(username: String, continuationToken: String, href: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        signUpStartCalled = true
        return try resolveRequest()
    }

    func submitPassword(href: String, password: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        submitPasswordCalled = true
        submitPasswordHrefReceived = href
        return try resolveRequest()
    }

    func submitCode(href: String, code: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        submitCodeCalled = true
        submitCodeHrefReceived = href
        return try resolveRequest()
    }

    func submitAttributes(href: String, attributes: [String: Any], continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        submitAttributesCalled = true
        submitAttributesHrefReceived = href
        submitAttributesReceived = attributes
        submitAttributesHistory.append(attributes)
        return try resolveRequest()
    }

    func registerMethod(href: String, target: String?, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        registerMethodCalled = true
        registerMethodHrefReceived = href
        return try resolveRequest()
    }

    func challenge(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        challengeCalled = true
        challengeHrefReceived = href
        return try resolveRequest()
    }

    func verify(href: String, otp: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        verifyCalled = true
        verifyHrefReceived = href
        return try resolveRequest()
    }

    func updatePassword(href: String, newPassword: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        updatePasswordCalled = true
        updateHrefReceived = href
        return try resolveRequest()
    }

    func poll(href: String, continuationToken: String, context: MSALNativeAuthRequestContext) throws -> MSIDHttpRequest {
        pollCalled = true
        pollHrefReceived = href
        return try resolveRequest()
    }
}
