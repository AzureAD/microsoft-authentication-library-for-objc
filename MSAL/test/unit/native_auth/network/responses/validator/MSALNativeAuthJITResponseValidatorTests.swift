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

    func test_untypedFailuresAreRejectedAtEveryRegistrationStage() throws {
        let failure = NSError(domain: "RegistrationResponseTests", code: 1)
        let introspect = sut.validateIntrospect(context: context, result: .failure(failure))
        let challenge = sut.validateChallenge(context: context, result: .failure(failure))
        let continuation = sut.validateContinue(context: context, result: .failure(failure))
        guard case .error(.unexpectedError(let introspectError)) = introspect,
              case .error(.unexpectedError(let challengeError)) = challenge,
              case .error(.unexpectedError(let continueError)) = continuation else {
            return XCTFail("Unrecognized failures must not produce a usable continuation")
        }
        XCTAssertEqual(try XCTUnwrap(introspectError).errorDescription, MSALNativeAuthErrorMessage.unexpectedResponseBody)
        XCTAssertEqual(try XCTUnwrap(challengeError).errorDescription, MSALNativeAuthErrorMessage.unexpectedResponseBody)
        XCTAssertEqual(try XCTUnwrap(continueError).errorDescription, MSALNativeAuthErrorMessage.unexpectedResponseBody)
    }

    func test_unknownIntrospectionFailurePreservesCompleteServerDiagnostics() {
        let input = MSALNativeAuthJITIntrospectResponseError(
            errorDescription: "Cannot list methods", errorCodes: [90023],
            errorURI: "https://example.com/error", correlationId: UUID()
        )
        let result = sut.validateIntrospect(context: context, result: .failure(input))
        guard case .error(.unexpectedError(let received)) = result else {
            return XCTFail("Unknown introspection errors must not return authentication methods")
        }
        XCTAssertEqual(received, input)
    }

    func test_incompletePreverifiedAndContinueResponsesCannotAdvanceRegistration() throws {
        let challenge = MSALNativeAuthJITChallengeResponse(
            continuationToken: nil, challengeType: "preverified", bindingMethod: nil,
            challengeTarget: nil, challengeChannel: nil, codeLength: nil, interval: nil, redirectReason: nil
        )
        let continuation = MSALNativeAuthJITContinueResponse(
            continuationToken: nil, redirectReason: nil, challengeType: nil
        )
        guard case .error(.unexpectedError(let challengeError)) =
                sut.validateChallenge(context: context, result: .success(challenge)),
              case .error(.unexpectedError(let continueError)) =
                sut.validateContinue(context: context, result: .success(continuation)) else {
            return XCTFail("A missing continuation token cannot advance registration")
        }
        XCTAssertEqual(try XCTUnwrap(challengeError).errorDescription, MSALNativeAuthErrorMessage.unexpectedResponseBody)
        XCTAssertEqual(try XCTUnwrap(continueError).errorDescription, MSALNativeAuthErrorMessage.unexpectedResponseBody)
    }

    func test_unclassifiedChallengeFailuresPreserveDiagnosticsWithoutInventingContactErrors() {
        let codes: [MSALNativeAuthJITChallengeOauth2ErrorCode] = [.accessDenied, .invalidRequest, .unknown]
        for code in codes {
            let input = MSALNativeAuthJITChallengeResponseError(
                error: code, errorDescription: "Unclassified failure", errorCodes: [90023],
                errorURI: "https://example.com/error", correlationId: UUID()
            )
            let result = sut.validateChallenge(context: context, result: .failure(input))
            guard case .error(.unexpectedError(let received)) = result else {
                return XCTFail("This response does not establish a blocked or invalid contact")
            }
            XCTAssertEqual(received, input)
        }
    }

    func test_unclassifiedContinueFailuresPreserveCompleteServerDiagnostics() {
        let codes: [MSALNativeAuthJITContinueOauth2ErrorCode] = [.invalidGrant, .unknown]
        for code in codes {
            let input = MSALNativeAuthJITContinueResponseError(
                error: code, errorDescription: "Cannot verify", errorCodes: [90023],
                errorURI: "https://example.com/error", correlationId: UUID()
            )
            let result = sut.validateContinue(context: context, result: .failure(input))
            guard case .error(.unexpectedError(let received)) = result else {
                return XCTFail("An unspecified failure is not an invalid-code response")
            }
            XCTAssertEqual(received, input)
        }
    }

    // MARK: introspect API tests
    func test_whenIntrospectWithNilAuthMethod_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthJITIntrospectResponse(continuationToken: continuationToken, methods: nil, challengeType: nil, redirectReason: nil)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(MSALNativeAuthJITIntrospectResponseError(error: .unknown, errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody, errorCodes: nil, errorURI: nil, innerErrors: nil, correlationId: nil))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenIntrospectWithEmptyAuthMethodList_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthJITIntrospectResponse(continuationToken: continuationToken, methods: [], challengeType: nil, redirectReason: nil)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(MSALNativeAuthJITIntrospectResponseError(error: .unknown, errorDescription: MSALNativeAuthErrorMessage.unexpectedResponseBody, errorCodes: nil, errorURI: nil, innerErrors: nil, correlationId: nil))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectReturnsValidResult_validationNotFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let methods = [MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "us******so.com")]
        let challengeResponse = MSALNativeAuthJITIntrospectResponse(continuationToken: continuationToken, methods: methods, challengeType: nil, redirectReason: nil)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .authMethodsRetrieved(continuationToken: continuationToken, authMethods: methods) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenIntrospectReturnsRedirect_validationNotFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let reason = "reason"
        let challengeResponse = MSALNativeAuthJITIntrospectResponse(continuationToken: nil, methods: nil, challengeType: .redirect, redirectReason: reason)
        let result = sut.validateIntrospect(context: context, result: .success(challengeResponse))
        if case .error(.redirect(reason: reason)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    // MARK: challenge API tests

    func test_whenChallengeTypeInvalidRequestWithCorrectErrorCode_validationShouldReturnInvalidVerificationContact() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeErrorResponse = MSALNativeAuthJITChallengeResponseError(error: .invalidRequest, errorCodes: [901001])
        let result = sut.validateChallenge(context: context, result: .failure(challengeErrorResponse))
        if case .error(.invalidVerificationContact) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeTypeInvalidRequestWithCorrectErrorCode_validationShouldReturnBlockedVerificationContact() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeErrorResponse = MSALNativeAuthJITChallengeResponseError(error: .accessDenied, errorCodes: [550024], subError: .providerBlockedByRep)
        let result = sut.validateChallenge(context: context, result: .failure(challengeErrorResponse))
        if case .error(.verificationContactBlocked) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenChallengeTypePassword_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continuationToken = "continuationToken"
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "password", bindingMethod: nil, challengeTarget: nil, challengeChannel: nil, codeLength: nil, interval: nil, redirectReason: nil)
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
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: channelTypeRawValue, codeLength: codeLength, interval: nil, redirectReason: nil)
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
        let missingCredentialToken = MSALNativeAuthJITChallengeResponse(continuationToken: nil, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: channelType, codeLength: codeLength, interval: nil, redirectReason: nil)
        var result = sut.validateChallenge(context: context, result: .success(missingCredentialToken))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingTargetLabel = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: nil, challengeChannel: channelType, codeLength: codeLength, interval: nil, redirectReason: nil)
        result = sut.validateChallenge(context: context, result: .success(missingTargetLabel))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingChannelType = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: nil, codeLength: codeLength, interval: nil, redirectReason: nil)
        result = sut.validateChallenge(context: context, result: .success(missingChannelType))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
        let missingCodeLength = MSALNativeAuthJITChallengeResponse(continuationToken: continuationToken, challengeType: "oob", bindingMethod: nil, challengeTarget: targetLabel, challengeChannel: channelType, codeLength: nil, interval: nil, redirectReason: nil)
        result = sut.validateChallenge(context: context, result: .success(missingCodeLength))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenChallengeTypeOTP_validationShouldFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: "something", challengeType: "otp", bindingMethod: nil, challengeTarget: "some", challengeChannel: "email", codeLength: 2, interval: nil, redirectReason: nil)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected challenge type"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenChallengeReturnsRedirect_validationNotFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let reason = "reason"
        let challengeResponse = MSALNativeAuthJITChallengeResponse(continuationToken: nil, challengeType: "redirect", bindingMethod: nil, challengeTarget: nil, challengeChannel: nil, codeLength: nil, interval: nil, redirectReason: reason)
        let result = sut.validateChallenge(context: context, result: .success(challengeResponse))
        if case .error(.redirect(reason: reason)) = result {} else {
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
        let continueResponse = MSALNativeAuthJITContinueResponse(continuationToken: nil, redirectReason: nil, challengeType: nil, correlationId: context.correlationId())
        let result = sut.validateContinue(context: context, result: .success(continueResponse))
        if case .error(.unexpectedError(.init(errorDescription: "Unexpected response body received"))) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }

    func test_whenJITContinueSuccessResponseContainsContinuationToken_validationShouldSucceed() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let continueResponse = MSALNativeAuthJITContinueResponse(continuationToken: "<continuationToken>", redirectReason: nil, challengeType: nil, correlationId: context.correlationId())
        let result = sut.validateContinue(context: context, result: .success(continueResponse))
        if case .success(continuationToken: "<continuationToken>") = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
    
    func test_whenJITContinueReturnsRedirect_validationNotFail() {
        let context = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let reason = "reason"
        let continueResponse = MSALNativeAuthJITContinueResponse(continuationToken: nil, redirectReason: reason, challengeType: .redirect, correlationId: context.correlationId())
        let result = sut.validateContinue(context: context, result: .success(continueResponse))
        if case .error(.redirect(reason: reason)) = result {} else {
            XCTFail("Unexpected result: \(result)")
        }
    }
}
