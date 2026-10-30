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

// swiftlint:disable:next type_body_length
class MSALNativeAuthV2RequestProviderMock: MSALNativeAuthV2RequestProviding {

    var throwError = false
    var responseError: Error?
    var authorizeChallengeStartResponseJSON: [String: Any]?
    var signUpStartResponseJSON: [String: Any]?
    var challengeResponseJSON: [String: Any]?
    private(set) var requests: [MSALNativeAuthV2HTTPRequestMock] = []
    private(set) var enrollHrefReceived: String?
    private(set) var enrollVerificationContactReceived: String?
    private(set) var enrollChannelTypeReceived: MSALNativeAuthV2EnrollmentMethod.ChannelType?
    var enrollResponseJSON: [String: Any]?
    private(set) var enrollTokenReceived: String?
    private(set) var enrollApiIdReceived: MSALNativeAuthTelemetryApiId?
    private(set) var activateHrefReceived: String?
    private(set) var activateCodeReceived: String?
    private(set) var activateTokenReceived: String?
    private(set) var activateApiIdReceived: MSALNativeAuthTelemetryApiId?

    private(set) var authorizeChallengeStartCalled = false
    private(set) var authorizeChallengeStartScopes: [String]?
    private(set) var authorizeChallengeStartClaimsRequestJson: String?
    private(set) var authorizeChallengeContinueCalled = false
    private(set) var authorizeChallengeContinueToken: String?
    private(set) var tokenCalled = false
    private(set) var tokenCode: String?
    private(set) var tokenScopes: [String]?
    private(set) var tokenClaimsRequestJson: String?
    private(set) var resetPasswordStartCalled = false
    private(set) var signInStartCalled = false
    private(set) var signInStartUsername: String?
    private(set) var signUpStartCalled = false
    private(set) var signUpStartUsername: String?
    private(set) var submitAttributesCalled = false
    private(set) var submitAttributesHrefReceived: String?
    private(set) var submitAttributesReceived: [String: Any]?
    private(set) var submitAttributesApiIdReceived: MSALNativeAuthTelemetryApiId?
    private(set) var challengeCalled = false
    private(set) var challengeCallCount = 0
    private(set) var challengeApiIdReceived: MSALNativeAuthTelemetryApiId?
    private(set) var verifyCalled = false
    private(set) var submitPasswordCalled = false
    private(set) var submitPasswordCallCount = 0
    private(set) var submitPasswordReceived: String?
    private(set) var updatePasswordCalled = false
    private(set) var pollCalled = false
    private(set) var riskVerifyCalled = false
    private(set) var riskVerifyCallCount = 0

    private(set) var challengeHrefReceived: String?
    private(set) var challengeTokenReceived: String?
    private(set) var verifyHrefReceived: String?
    private(set) var verifyTokenReceived: String?
    private(set) var verifyCodeReceived: String?
    private(set) var verifyApiIdReceived: MSALNativeAuthTelemetryApiId?
    private(set) var submitPasswordHrefReceived: String?
    private(set) var submitPasswordTokenReceived: String?
    private(set) var submitPasswordApiIdReceived: MSALNativeAuthTelemetryApiId?
    private(set) var updateHrefReceived: String?
    private(set) var pollHrefReceived: String?
    private(set) var riskVerifyHrefReceived: String?
    private(set) var riskVerifyTokenReceived: String?
    private(set) var riskVerifyApiIdReceived: MSALNativeAuthTelemetryApiId?
    private(set) var pollHrefsReceived: [String] = []
    private(set) var pollTokensReceived: [String] = []

    func mockRequest(throwError: Bool = false) {
        self.throwError = throwError
    }

    func enroll(
        href: String,
        verificationContact: String,
        channelType: MSALNativeAuthV2EnrollmentMethod.ChannelType,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        enrollHrefReceived = href
        enrollVerificationContactReceived = verificationContact
        enrollChannelTypeReceived = channelType
        enrollTokenReceived = continuationToken
        enrollApiIdReceived = apiId
        return try resolveRequest(context: context, responseJSON: enrollResponseJSON ?? [:])
    }

    func activate(
        href: String,
        otp: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        activateHrefReceived = href
        activateCodeReceived = otp
        activateTokenReceived = continuationToken
        activateApiIdReceived = apiId
        return try resolveRequest(context: context)
    }

    private func resolveRequest(
        context: MSALNativeAuthRequestContext,
        responseJSON: [String: Any] = [:],
        expectsRawJSONResponse: Bool = false
    ) throws -> MSIDHttpRequestProtocol {
        if throwError {
            throw ErrorMock.error
        }
        let request = try MSALNativeAuthV2HTTPRequestMock(
            responseJSON: responseJSON,
            expectsRawJSONResponse: expectsRawJSONResponse,
            context: context,
            responseError: responseError
        )
        requests.append(request)
        return request
    }

    func authorizeChallengeStart(
        scopes: [String]?,
        claimsRequestJson: String?,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        authorizeChallengeStartCalled = true
        authorizeChallengeStartScopes = scopes
        authorizeChallengeStartClaimsRequestJson = claimsRequestJson
        return try resolveRequest(context: context, responseJSON: authorizeChallengeStartResponseJSON ?? [:])
    }

    func authorizeChallengeContinue(
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        authorizeChallengeContinueCalled = true
        authorizeChallengeContinueToken = continuationToken
        return try resolveRequest(context: context)
    }

    func token(
        code: String,
        scopes: [String],
        claimsRequestJson: String?,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        tokenCalled = true
        tokenCode = code
        tokenScopes = scopes
        tokenClaimsRequestJson = claimsRequestJson
        return try resolveRequest(
            context: context,
            responseJSON: Self.successfulTokenResponseJson,
            expectsRawJSONResponse: true
        )
    }

    static let successfulTokenResponseJson: [String: Any] = [
        "token_type": "Bearer",
        "access_token": "access-token",
        "id_token": "idToken",
        "refresh_token": "refresh-token",
        "expires_in": 3600,
        "scope": "scope"
    ]

    func resetPasswordStart(
        username: String,
        continuationToken: String,
        href: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        resetPasswordStartCalled = true
        return try resolveRequest(context: context)
    }

    func signInStart(
        username: String,
        continuationToken: String,
        href: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        signInStartCalled = true
        signInStartUsername = username
        return try resolveRequest(context: context)
    }

    func signUpStart(
        username: String,
        continuationToken: String,
        href: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        signUpStartCalled = true
        signUpStartUsername = username
        return try resolveRequest(context: context, responseJSON: signUpStartResponseJSON ?? [:])
    }

    func submitAttributes(
        href: String,
        attributes: [String: Any],
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        submitAttributesCalled = true
        submitAttributesHrefReceived = href
        submitAttributesReceived = attributes
        submitAttributesApiIdReceived = apiId
        return try resolveRequest(context: context)
    }

    func challenge(
        href: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        challengeCalled = true
        challengeCallCount += 1
        challengeApiIdReceived = apiId
        challengeHrefReceived = href
        challengeTokenReceived = continuationToken
        return try resolveRequest(context: context, responseJSON: challengeResponseJSON ?? [:])
    }

    func verify(
        href: String,
        otp: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        verifyCalled = true
        verifyHrefReceived = href
        verifyTokenReceived = continuationToken
        verifyCodeReceived = otp
        verifyApiIdReceived = apiId
        return try resolveRequest(context: context)
    }

    func submitPassword(
        href: String,
        password: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        submitPasswordCalled = true
        submitPasswordCallCount += 1
        submitPasswordHrefReceived = href
        submitPasswordReceived = password
        submitPasswordTokenReceived = continuationToken
        submitPasswordApiIdReceived = apiId
        return try resolveRequest(context: context)
    }

    func updatePassword(
        href: String,
        newPassword: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        updatePasswordCalled = true
        updateHrefReceived = href
        return try resolveRequest(context: context)
    }

    func poll(
        href: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        pollCalled = true
        pollHrefReceived = href
        pollHrefsReceived.append(href)
        pollTokensReceived.append(continuationToken)
        return try resolveRequest(context: context)
    }

    func riskVerify(
        href: String,
        continuationToken: String,
        apiId: MSALNativeAuthTelemetryApiId,
        context: MSALNativeAuthRequestContext
    ) throws -> MSIDHttpRequestProtocol {
        riskVerifyCalled = true
        riskVerifyCallCount += 1
        riskVerifyHrefReceived = href
        riskVerifyTokenReceived = continuationToken
        riskVerifyApiIdReceived = apiId
        return try resolveRequest(context: context)
    }
}

final class MSALNativeAuthV2HTTPRequestMock: NSObject, MSIDHttpRequestProtocol {
    var retryCounter = 0
    var retryInterval: TimeInterval = 0
    var urlRequest: URLRequest!
    private let context: MSIDRequestContext
    private(set) var sendCallCount = 0

    private let response: HTTPURLResponse
    private let responseData: Data
    private let expectsRawJSONResponse: Bool
    private let responseError: Error?

    init(
        responseJSON: [String: Any],
        expectsRawJSONResponse: Bool = false,
        context: MSIDRequestContext,
        responseError: Error? = nil
    ) throws {
        let url = try XCTUnwrap(URL(string: "https://contoso.com/test"))
        self.urlRequest = URLRequest(url: url)
        self.response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        self.responseData = try JSONSerialization.data(withJSONObject: responseJSON)
        self.expectsRawJSONResponse = expectsRawJSONResponse
        self.context = context
        self.responseError = responseError
        super.init()
    }

    func send(_ completionBlock: MSIDHttpRequestDidCompleteBlock!) {
        sendCallCount += 1
        if let responseError {
            completionBlock(nil, responseError)
            return
        }
        do {
            let result: Any
            if expectsRawJSONResponse {
                result = try JSONSerialization.jsonObject(with: responseData)
            } else {
                result = try MSALNativeAuthV2HALResponseSerializer().responseObject(
                    for: response,
                    data: responseData,
                    context: context
                )
            }
            completionBlock(result, nil)
        } catch {
            completionBlock(nil, error)
        }
    }
}
