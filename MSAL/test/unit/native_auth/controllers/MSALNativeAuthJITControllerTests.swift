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
@_implementationOnly import MSAL_Unit_Test_Private

class MSALNativeAuthJITControllerTests: MSALNativeAuthTestCase {

    var sut: MSALNativeAuthJITController!
    var jitRequestProviderMock: MSALNativeAuthJITRequestProviderMock!
    var jitResponseValidatorMock: MSALNativeAuthJITResponseValidatorMock!
    var signInControllerMock: MSALNativeAuthSignInControllerMock!
    var contextMock: MSALNativeAuthRequestContextMock!
    var defaultUUID = UUID(uuidString: DEFAULT_TEST_UID)!

    override func setUpWithError() throws {
        jitRequestProviderMock = .init()
        jitResponseValidatorMock = .init()
        signInControllerMock = .init()
        contextMock = .init()
        contextMock.mockTelemetryRequestId = "telemetry_request_id"

        sut = .init(
            clientId: DEFAULT_TEST_CLIENT_ID,
            jitRequestProvider: jitRequestProviderMock,
            jitResponseValidator: jitResponseValidatorMock,
            signInController: signInControllerMock
        )

        try super.setUpWithError()
    }

    func test_whenGetJITAuthMethodsIntrospectRequestFail_anErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.expectedContext = expectedContext
        jitRequestProviderMock.throwingIntrospectError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)

        let result = await sut.getJITAuthMethods(continuationToken: "CT", context: expectedContext)

        checkTelemetryEventResult(id: .telemetryApiIdJITIntrospect, isSuccessful: false)
        if case .error(let error) = result.result {
            XCTAssertNotNil(error)
        } else {
            XCTFail("Expected error result")
        }
    }

    func test_whenGetJITAuthMethodsIntrospectReturnsError_anErrorShouldBeReturned() async {
        await checkGetJITAuthMethodsWithIntrospectValidatorError(validatedError: .invalidRequest(.init()), expectedType: .generalError)
        await checkGetJITAuthMethodsWithIntrospectValidatorError(validatedError: .unexpectedError(.init()), expectedType: .generalError)
    }

    func test_whenGetAuthMethods_correctResultShouldBeReturned() async {
        let expectedContinuationToken = "continuationToken"
        let internalAuthMethod = MSALNativeAuthInternalAuthenticationMethod(id: "1", challengeType: .oob, challengeChannel: "email", loginHint: "hint")
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitResponseValidatorMock.introspectValidatedResponse = .authMethodsRetrieved(continuationToken: expectedContinuationToken, authMethods: [internalAuthMethod])

        let result = await sut.getJITAuthMethods(continuationToken: expectedContinuationToken, context: expectedContext)
        result.telemetryUpdate?(.success(()))

        checkTelemetryEventResult(id: .telemetryApiIdJITIntrospect, isSuccessful: true)
        if case .selectionRequired(let authMethods, let newState) = result.result {
            XCTAssertEqual(authMethods.count, 1)
            XCTAssertEqual(authMethods.first?.challengeType, internalAuthMethod.challengeType.rawValue)
            XCTAssertEqual(authMethods.first?.id, internalAuthMethod.id)
            XCTAssertEqual(authMethods.first?.channelTargetType.value, internalAuthMethod.challengeChannel)
            XCTAssertEqual(authMethods.first?.loginHint, internalAuthMethod.loginHint)
            XCTAssertEqual(newState.continuationToken, expectedContinuationToken)
        } else {
            XCTFail("Expected selectionRequired result")
        }
    }

    func test_whenRequestJITChallenge_VerificationRequiredIsSentBackToUser() async {
        let authMethod = MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "hint", channelTargetType: MSALNativeAuthChannelType(value:"email"))
        let verificationContact = "email@contoso.com"
        let expectedContinuationToken = "continuationToken"
        let expectedSentTo = "sentTo"
        let expectedChannelType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 8
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitResponseValidatorMock.challengeValidatedResponse = .codeRequired(
            continuationToken: expectedContinuationToken,
            sentTo: expectedSentTo,
            channelType: expectedChannelType,
            codeLength: expectedCodeLength
        )
        let result = await sut.requestJITChallenge(continuationToken: expectedContinuationToken, authMethod: authMethod, verificationContact: verificationContact, context: expectedContext)
        result.telemetryUpdate?(.success(()))

        checkTelemetryEventResult(id: .telemetryApiIdJITChallenge, isSuccessful: true)
        if case .verificationRequired(let sentTo, let channelTargetType, let codeLength, let newState) = result.result {
            XCTAssertEqual(sentTo, expectedSentTo)
            XCTAssertEqual(channelTargetType, expectedChannelType)
            XCTAssertEqual(codeLength, expectedCodeLength)
            XCTAssertEqual(newState.continuationToken, expectedContinuationToken)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }

    func test_whenRequestJITChallengePreverified_CompletedIsSentBackToUser() async {
        let expectedContinuationToken = "continuationToken"
        let verificationContact = "email@contoso.com"
        let authMethod = MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "hint", channelTargetType: MSALNativeAuthChannelType(value:"email"))
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitResponseValidatorMock.challengeValidatedResponse = .codeRequired(
            continuationToken: expectedContinuationToken,
            sentTo: "sentTo",
            channelType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        let userAccountResult = MSALNativeAuthUserAccountResultStub.result
        signInControllerMock.continuationTokenResult = .init(.completed(userAccountResult), correlationId: defaultUUID)
        jitResponseValidatorMock.challengeValidatedResponse = .preverified(continuationToken: "continuationToken")
        jitResponseValidatorMock.continueValidatedResponse = .success(continuationToken: "continuationToken 2")
        let result = await sut.requestJITChallenge(continuationToken: expectedContinuationToken, authMethod: authMethod, verificationContact: verificationContact, context: expectedContext)
        result.telemetryUpdate?(.success(()))

        checkTelemetryEventResult(id: .telemetryApiIdJITChallenge, isSuccessful: true, expectedNumberOfEvents: 3)
        checkTelemetryEventResult(id: .telemetryApiIdJITContinue, isSuccessful: true, expectedNumberOfEvents: 2)
        if case .completed(let account) = result.result {
            XCTAssertEqual(account.idToken, userAccountResult.idToken)
        } else {
            XCTFail("Expected completed result")
        }
    }

    func test_whenRequestJITChallengeRequestFails_ErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authMethod = MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "hint", channelTargetType: MSALNativeAuthChannelType(value:"email"))

        jitRequestProviderMock.expectedContext = expectedContext
        jitRequestProviderMock.throwingChallengeError = MSALNativeAuthError(message: nil, correlationId: defaultUUID)

        let result = await sut.requestJITChallenge(continuationToken: "continuationToken", authMethod: authMethod, verificationContact: nil, context: expectedContext)

        checkTelemetryEventResult(id: .telemetryApiIdJITChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }

    func test_whenInvalidInputJITChallenge_ErrorShouldBeReturned() async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authMethod = MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "hint", channelTargetType: MSALNativeAuthChannelType(value:"email"))

        jitRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitRequestProviderMock.expectedContext = expectedContext
        jitResponseValidatorMock.challengeValidatedResponse = .error(.invalidVerificationContact(.init(error: .invalidRequest, errorCodes: [MSALNativeAuthESTSApiErrorCodes.invalidVerificationContact.rawValue])))

        let result = await sut.requestJITChallenge(continuationToken: "continuationToken", authMethod: authMethod, verificationContact: nil, context: expectedContext)

        checkTelemetryEventResult(id: .telemetryApiIdJITChallenge, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .invalidInput)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }

    func test_whenRequestJITContinueSucceeds_CompletedIsSentBackToUser() async {
        let expectedContinuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitResponseValidatorMock.continueValidatedResponse = .success(continuationToken: expectedContinuationToken)
        let userAccountResult = MSALNativeAuthUserAccountResultStub.result

        signInControllerMock.continuationTokenResult = .init(.completed(userAccountResult), correlationId: defaultUUID)
        jitResponseValidatorMock.continueValidatedResponse = .success(continuationToken: expectedContinuationToken)
        let result = await sut.submitJITChallenge(challenge: "123456", continuationToken: expectedContinuationToken, grantType: .oobCode, context: expectedContext)
        result.telemetryUpdate?(.success(()))

        checkTelemetryEventResult(id: .telemetryApiIdJITContinue, isSuccessful: true, expectedNumberOfEvents: 2)
        checkTelemetryEventResult(id: .telemetryApiISignInAfterJIT, isSuccessful: true, expectedNumberOfEvents: 1)
        if case .completed(let account) = result.result {
            XCTAssertEqual(account.idToken, userAccountResult.idToken)
        } else {
            XCTFail("Expected selectionRequired result")
        }
    }

    func test_whenRequestJITContinueReturnsJITRequired_ErrorShouldBeReturned() async {
        let expectedContinuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)
        let authMethod = MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "hint", channelTargetType: MSALNativeAuthChannelType(value:"email"))
        let authMethods = [authMethod]
        let newState = RegisterStrongAuthState(
            controller: sut,
            continuationToken: expectedContinuationToken,
            correlationId: defaultUUID
        )

        jitRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitResponseValidatorMock.continueValidatedResponse = .success(continuationToken: expectedContinuationToken)

        signInControllerMock.continuationTokenResult = .init(.jitAuthMethodsSelectionRequired(authMethods: authMethods, newState: newState), correlationId: defaultUUID)
        jitResponseValidatorMock.continueValidatedResponse = .success(continuationToken: expectedContinuationToken)
        let result = await sut.submitJITChallenge(challenge: "123456", continuationToken: expectedContinuationToken, grantType: .oobCode, context: expectedContext)
        result.telemetryUpdate?(.success(()))

        checkTelemetryEventResult(id: .telemetryApiIdJITContinue, isSuccessful: true)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }

    func test_whenRequestJITContinueRequestFails_ErrorShouldBeReturned() async {
        let expectedContinuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitRequestProviderMock.expectedContext = expectedContext
        jitResponseValidatorMock.continueValidatedResponse = .error(.invalidRequest(.init(error: .unknown)))

        let result = await sut.submitJITChallenge(challenge: "123456", continuationToken: expectedContinuationToken, grantType: .oobCode, context: expectedContext)

        checkTelemetryEventResult(id: .telemetryApiIdJITContinue, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }

    func test_whenInvalidOOBCodeJITContinue_ErrorShouldBeReturned() async {
        let expectedContinuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitRequestProviderMock.expectedContext = expectedContext
        jitResponseValidatorMock.continueValidatedResponse = .error(.invalidOOBCode(.init(error: .invalidGrant, subError: .invalidOOBValue)))

        let result = await sut.submitJITChallenge(challenge: "123456", continuationToken: expectedContinuationToken, grantType: .oobCode, context: expectedContext)

        checkTelemetryEventResult(id: .telemetryApiIdJITContinue, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .invalidChallenge)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }

    func test_whenUnexpectedErrorJITContinue_ErrorShouldBeReturned() async {
        let expectedContinuationToken = "continuationToken"
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitRequestProviderMock.expectedContext = expectedContext
        jitResponseValidatorMock.continueValidatedResponse = .error(.unexpectedError(.init(error: .unknown)))

        let result = await sut.submitJITChallenge(challenge: "123456", continuationToken: expectedContinuationToken, grantType: .oobCode, context: expectedContext)

        checkTelemetryEventResult(id: .telemetryApiIdJITContinue, isSuccessful: false)
        if case .error(let error, let newState) = result.result {
            XCTAssertEqual(error.type, .generalError)
            XCTAssertNotNil(newState)
        } else {
            XCTFail("Expected verificationRequired result")
        }
    }



    // MARK: telemetry

    func checkTelemetryEventResult(id: MSALNativeAuthTelemetryApiId, isSuccessful: Bool, expectedNumberOfEvents: Int = 1) {
        XCTAssertEqual(receivedEvents.count, expectedNumberOfEvents)

        guard let telemetryEventDict = receivedEvents.first else {
            return XCTFail("Telemetry test fail")
        }

        let expectedApiId = String(id.rawValue)
        XCTAssertEqual(telemetryEventDict["api_id"] as? String, expectedApiId)
        XCTAssertEqual(telemetryEventDict["event_name"] as? String, "api_event" )
        XCTAssertEqual(telemetryEventDict["correlation_id" ] as? String, DEFAULT_TEST_UID.uppercased())
        XCTAssertEqual(telemetryEventDict["is_successfull"] as? String, isSuccessful ? "yes" : "no")
        XCTAssertEqual(telemetryEventDict["status"] as? String, isSuccessful ? "succeeded" : "failed")
        XCTAssertNotNil(telemetryEventDict["start_time"])
        XCTAssertNotNil(telemetryEventDict["stop_time"])
        XCTAssertNotNil(telemetryEventDict["response_time"])
        receivedEvents.removeFirst()
    }

    // MARK: Private methods

    private func checkGetJITAuthMethodsWithIntrospectValidatorError(validatedError: MSALNativeAuthJITIntrospectValidatedErrorType, expectedType: RegisterStrongAuthChallengeError.ErrorType) async {
        let expectedContext = MSALNativeAuthRequestContext(correlationId: defaultUUID)

        jitRequestProviderMock.expectedContext = expectedContext
        jitRequestProviderMock.mockIntrospectRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        jitResponseValidatorMock.introspectValidatedResponse = .error(validatedError)
        let result = await sut.getJITAuthMethods(continuationToken: "CT", context: expectedContext)

        checkTelemetryEventResult(id: .telemetryApiIdJITIntrospect, isSuccessful: false)
        if case .error(let error) = result.result {
            XCTAssertNotNil(error)
        } else {
            XCTFail("Expected error result")
        }
        receivedEvents.removeAll()
    }
}
