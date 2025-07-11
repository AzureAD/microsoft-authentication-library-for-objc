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
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthSignInResponseValidatorTests: MSALNativeAuthTestCase {

    private let baseUrl = URL(string: DEFAULT_TEST_AUTHORITY)!
    private var sut: MSALNativeAuthSignInResponseValidator!
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!


    override func setUpWithError() throws {
        try super.setUpWithError()

        sut = MSALNativeAuthSignInResponseValidator()
    }
    
    // MARK: challenge API tests
    
    func test_whenChallengeTypeRedirect_validationShouldReturnRedirectError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let reason = "reason"
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(continuationToken: nil, challengeType: .redirect, redirectReason: reason, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.redirect(reason)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypePassword_validationShouldReturnPasswordRequired() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(continuationToken: continuationToken, challengeType: .password, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .passwordRequired(continuationToken: continuationToken) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypeHasNoValue_validationShouldReturnError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(continuationToken: continuationToken, challengeType: nil, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(.init(errorDescription: MSALNativeAuthErrorMessage.unexpectedChallengeType))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypePasswordAndNoCredentialToken_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(continuationToken: nil, challengeType: .password, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypeOOB_validationShouldReturnCodeRequired() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let targetLabel = "targetLabel"
        let codeLength = 4
        let channelTypeRawValue = "email"
        let challengeResponse = MSALNativeAuthSignInChallengeResponse(continuationToken: continuationToken, challengeType: .oob, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: channelTypeRawValue, codeLength: codeLength, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .codeRequired(let validatedCT, let sentTo, let channelType, let validatedCodeLength) = result {
            XCTAssertEqual(validatedCT, continuationToken)
            XCTAssertEqual(sentTo, targetLabel)
            XCTAssertTrue(channelType.isEmailType)
            XCTAssertEqual(validatedCodeLength, codeLength)
        } else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypeOOBButMissingAttributes_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let targetLabel = "targetLabel"
        let codeLength = 4
        let channelType = "email"
        let missingCredentialToken = MSALNativeAuthSignInChallengeResponse(continuationToken: nil, challengeType: .oob, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: channelType, codeLength: codeLength, interval: nil)
        var result = sut.validateChallenge(context: context, result: .success(missingCredentialToken))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingTargetLabel = MSALNativeAuthSignInChallengeResponse(continuationToken: continuationToken, challengeType: .oob, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: nil, challengeChannel: channelType, codeLength: codeLength, interval: nil)
        result = sut.validateChallenge(context: context, result: .success(missingTargetLabel))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingChannelType = MSALNativeAuthSignInChallengeResponse(continuationToken: continuationToken, challengeType: .oob, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: nil, codeLength: codeLength, interval: nil)
        result = sut.validateChallenge(context: context, result: .success(missingChannelType))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingCodeLength = MSALNativeAuthSignInChallengeResponse(continuationToken: continuationToken, challengeType: .oob, redirectReason: nil, bindingMethod: nil, challengeTargetLabel: targetLabel, challengeChannel: channelType, codeLength: nil, interval: nil)
        result = sut.validateChallenge(context: context, result: .success(missingCodeLength))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectRequiredError_validationNotFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeErrorResponse = MSALNativeAuthSignInChallengeResponseError(error: .invalidRequest, subError: .introspectRequired, correlationId: defaultUUID)
        let result = sut.validateChallenge(context: context, result: .failure(challengeErrorResponse))
        if case .introspectRequired = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    // MARK: initiate API tests
    
    func test_whenInitiateResponseIsValid_validationShouldBeSuccessful() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let initiateResponse = MSALNativeAuthSignInInitiateResponse(continuationToken: continuationToken, challengeType: nil, redirectReason: nil)
        let result = sut.validateInitiate(context: context, result: .success(initiateResponse))
        if case .success(continuationToken: continuationToken) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInitiateResponseIsInvalid_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let initiateResponse = MSALNativeAuthSignInInitiateResponse(continuationToken: nil, challengeType: nil, redirectReason: nil)
        let result = sut.validateInitiate(context: context, result: .success(initiateResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInitiateChallengeTypeIsRedirect_validationShouldReturnRedirectError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let reason = "reason"
        let initiateResponse = MSALNativeAuthSignInInitiateResponse(continuationToken: nil, challengeType: .redirect, redirectReason: reason)
        let result = sut.validateInitiate(context: context, result: .success(initiateResponse))
        if case .error(.redirect(reason)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenInitiateChallengeTypeIsInvalid_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        var initiateResponse = MSALNativeAuthSignInInitiateResponse(continuationToken: nil, challengeType: .oob, redirectReason: nil)
        var result = sut.validateInitiate(context: context, result: .success(initiateResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        initiateResponse = MSALNativeAuthSignInInitiateResponse(continuationToken: nil, challengeType: .oob, redirectReason: nil)
        result = sut.validateInitiate(context: context, result: .success(initiateResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        initiateResponse = MSALNativeAuthSignInInitiateResponse(continuationToken: nil, challengeType: .password, redirectReason: nil)
        result = sut.validateInitiate(context: context, result: .success(initiateResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    // MARK: introspect API tests
    
    func test_whenIntrospectReturnsRedirect_validationShouldReturnRedirectError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let reason = "reason"
        let challengeResponse = MSALNativeAuthSignInIntrospectResponse(continuationToken: nil, methods: nil, challengeType: .redirect, redirectReason: reason)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.redirect(reason)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectReturnsInvalidRequest_validationShouldReturnRightError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let introspectErrorResponse = MSALNativeAuthSignInIntrospectResponseError(error: .invalidRequest)
        let result = sut.validateIntrospect(context: context, result: .failure(introspectErrorResponse))
        if case .error(.invalidRequest(introspectErrorResponse)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectReturnsExpiredToken_validationShouldReturnRightError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let introspectErrorResponse = MSALNativeAuthSignInIntrospectResponseError(error: .expiredToken)
        let result = sut.validateIntrospect(context: context, result: .failure(introspectErrorResponse))
        if case .error(.expiredToken(introspectErrorResponse)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectWithNilAuthMethod_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthSignInIntrospectResponse(continuationToken: continuationToken, methods: nil, challengeType: nil, redirectReason: nil)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(MSALNativeAuthSignInIntrospectResponseError(error: .unknown, errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody, errorCodes: nil, errorURI: nil, innerErrors: nil, correlationId: nil))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectWithEmptyAuthMethodList_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthSignInIntrospectResponse(continuationToken: continuationToken, methods: [], challengeType: nil, redirectReason: nil)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(MSALNativeAuthSignInIntrospectResponseError(error: .unknown, errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody, errorCodes: nil, errorURI: nil, innerErrors: nil, correlationId: nil))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectReturnsValidResult_validationNotFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let methods = [MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "us******so.com")]
        let challengeResponse = MSALNativeAuthSignInIntrospectResponse(continuationToken: continuationToken, methods: methods, challengeType: nil, redirectReason: nil)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .authMethodsRetrieved(continuationToken: continuationToken, authMethods: methods) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
}
