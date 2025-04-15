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

final class MSALNativeAuthJITResponseValidatorTests: XCTestCase {

    private var sut: MSALNativeAuthJITResponseValidator!
    private var context: MSALNativeAuthRequestContext!
    private var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = MSALNativeAuthJITResponseValidator()
        context = MSALNativeAuthRequestContext(correlationId: UUID())
    }

    // MARK: introspect API tests
    func test_whenIntrospectWithNilAuthMethod_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthJITIntrospectResponse(continuationToken: continuationToken, methods: nil)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(MSALNativeAuthJITIntrospectResponseError(error: .unknown, errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody, errorCodes: nil, errorURI: nil, innerErrors: nil, correlationId: nil))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenIntrospectWithEmptyAuthMethodList_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthJITIntrospectResponse(continuationToken: continuationToken, methods: [])
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(MSALNativeAuthJITIntrospectResponseError(error: .unknown, errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody, errorCodes: nil, errorURI: nil, innerErrors: nil, correlationId: nil))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenIntrospectReturnsValidResult_validationNotFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let methods = [MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "us******so.com")]
        let challengeResponse = MSALNativeAuthJITIntrospectResponse(continuationToken: continuationToken, methods: methods)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .authMethodsRetrieved(continuationToken: continuationToken, authMethods: methods) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    // MARK: challenge API tests

    func test_whenChallengeTypeRedirect_validationShouldReturnRedirectError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: nil, challengeType: "redirect", bindingMethod: nil, challengeTarget: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.redirect) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenChallengeTypeInvalidRequest_validationShouldReturnInvalidVerificationContact() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeErrorResponse = MSALNativeAuthJITChallengeResponseError(error: .invalidRequest, errorCodes: [901001])
        let result = sut.validateChallenge(context: context, result: .failure(challengeErrorResponse))
        if case .invalidVerificationContact = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenChallengeTypePassword_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "password", bindingMethod: nil, challengeTarget: nil, challengeChannel: nil, codeLength: nil, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected challenge type"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenChallengeTypeOOB_validationShouldReturnCodeRequired() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let targetLabel = "targetLabel"
        let codeLength = 4
        let channelTypeRawValue = "email"
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: channelTypeRawValue, codeLength: codeLength, interval: nil)
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
        let missingCredentialToken = MSALNativeAuthJITChallengeResponse(continuationToken: nil, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: channelType, codeLength: codeLength, interval: nil)
        var result = sut.validateChallenge(context: context, result: .success(missingCredentialToken))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingTargetLabel = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: nil, challengeChannel: channelType, codeLength: codeLength, interval: nil)
        result = sut.validateChallenge(context: context, result: .success(missingTargetLabel))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingChannelType = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: nil, codeLength: codeLength, interval: nil)
        result = sut.validateChallenge(context: context, result: .success(missingChannelType))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingCodeLength = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: channelType, codeLength: nil, interval: nil)
        result = sut.validateChallenge(context: context, result: .success(missingCodeLength))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenChallengeTypeOTP_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: "something", challengeType: "otp", bindingMethod: nil, challengeTarget: "some", challengeChannel: "email", codeLength: 2, interval: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected challenge type"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    // MARK: - continue API tests

    func test_whenContinueReturnsInvalidGrantWithoutCorrectSubError_validationShouldReturnUnexpectedError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continueErrorResponse = MSALNativeAuthJITContinueResponseError(error: .invalidGrant)
        let result = sut.validateContinue(context: context, result: .failure(continueErrorResponse))
        if case .error(.unexpectedError(.init(error:.invalidGrant, errorDescription: nil))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenContinueReturnsInvalidGrantWithoutCorrectSubError_validationShouldReturnCorrectError() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continueErrorResponse = MSALNativeAuthJITContinueResponseError(error: .invalidGrant, subError: .invalidOOBValue)
        let result = sut.validateContinue(context: context, result: .failure(continueErrorResponse))
        if case .error(.invalidOOBCode(continueErrorResponse)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenJITContinueSuccessResponseMissingContinuationToken_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continueResponse = MSALNativeAuthJITContinueResponse(continuationToken: nil, correlationId: context.correlationId())
        let result = sut.validateContinue(context: context, result: .success(continueResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenJITContinueSuccessResponseContainsContinuationToken_validationShouldSucceed() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continueResponse = MSALNativeAuthJITContinueResponse(continuationToken: "<continuationToken>", correlationId: context.correlationId())
        let result = sut.validateContinue(context: context, result: .success(continueResponse))
        if case .success(continuationToken: "<continuationToken>") = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
}
