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
@testable import MSAL
@_implementationOnly import MSAL_Private
@_implementationOnly import MSAL_Unit_Test_Private

final class MSALNativeAuthPublicClientApplicationTest: XCTestCase {

    private let controllerFactoryMock = MSALNativeAuthControllerFactoryMock()
    private let cacheAccessorFactoryMock = MSALNativeAuthCacheAccessorFactoryMock()
    private var sut: MSALNativeAuthPublicClientApplication!
    private var correlationId: UUID = UUID()

    private let clientId = "clientId"
    private let authorityURL = URL(string: "https://microsoft.com")
    
    private var authority: MSALCIAMAuthority!
    private var configuration : MSALNativeAuthInternalConfiguration!
    private var contextMock: MSALNativeAuthRequestContext!
    
    override func setUp() {
        super.setUp()

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactoryMock,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )
        
        authority = try! MSALCIAMAuthority(url: authorityURL!)
        configuration = try! MSALNativeAuthInternalConfiguration(clientId: clientId, authority: authority!, challengeTypes: [.OOB, .password], capabilities: nil, redirectUri: nil)
        contextMock = .init(correlationId: .init(uuidString: correlationId.uuidString)!)
    }

    func testInit_whenPassingNilRedirectUri_itShouldNotThrowError() {
        guard let config = try? MSALNativeAuthPublicClientApplicationConfig(clientId: "genericClient", tenantSubdomain: "genericTenenat", challengeTypes: [.OOB]) else {
            XCTFail("Error not expected to occur")
            return
        }
        XCTAssertNoThrow(try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config))
    }

    func testInit_nativeAuthCacheAccessor_itShouldUseConfigFromSuperclass() {
        XCTAssertEqual(sut.tokenCache, cacheAccessorFactoryMock.tokenCache)
        XCTAssertEqual(sut.accountMetadataCache, cacheAccessorFactoryMock.accountMetadataCache)
    }

    // MARK: - Delegates

    // MARK: - Sign Up with password

    func testSignUpPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        
        let parameters = MSALNativeAuthSignUpParameters(username: "")
        parameters.password = ""
        sut.signUp(parameters: parameters, delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUpPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        
        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = ""
        sut.signUp(parameters: parameters, delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
    }

    func testSignUpPassword_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "sign-up public interface telemetry")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp1)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2])

        XCTAssertNil(controllerFactoryMock.signUpController.signUpStartRequestParameters?.attributes)
        XCTAssertNotNil(controllerFactoryMock.signUpController.signUpStartRequestParameters)
    }

    func testSignUpPassword_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "sign-up public interface telemetry")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        
        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        
        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)
        
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpCodeRequired")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func testSignUpPassword_delegate_whenSendAttributes_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.attributeNames, expectedInvalidAttributes)
    }

    func testSignUpPassword_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription, 
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesInvalid")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    // MARK: - Sign Up using parameters with password

    func testSignUpUsingParametersPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = ""
        sut.signUp(parameters: parameters, delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
    }

    func testSignUpUsingParametersPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        let parameters = MSALNativeAuthSignUpParameters(username: "")
        parameters.password = ""
        sut.signUp(parameters: parameters, delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUpUsingParametersPassword_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "sign-up public interface telemetry")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp1)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2])

        XCTAssertNil(controllerFactoryMock.signUpController.signUpStartRequestParameters?.attributes)
        XCTAssertNotNil(controllerFactoryMock.signUpController.signUpStartRequestParameters)
    }

    func testSignUpUsingParametersPassword_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "sign-up public interface telemetry")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpCodeRequired")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func testSignUpUsingParametersPassword_delegate_whenSendAttributes_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.attributeNames, expectedInvalidAttributes)
    }

    func testSignUpUsingParametersPassword_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        parameters.password = "correct"
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesInvalid")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    // MARK: - Sign Up with code

    func testSignUp_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)
        
        let parameters = MSALNativeAuthSignUpParameters(username: "")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUp_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertNil(controllerFactoryMock.signUpController.signUpStartRequestParameters?.attributes)
        XCTAssertNotNil(controllerFactoryMock.signUpController.signUpStartRequestParameters)
    }

    func testSignUp_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpCodeRequired")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func testSignUp_delegate_whenSendAttributes_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.attributeNames, expectedInvalidAttributes)
    }

    func testSignUp_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesInvalid")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    // MARK: - Sign Up using parameters with code

    func testSignUpUsingParameters_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)
        let parameters = MSALNativeAuthSignUpParameters(username: "")
        sut.signUp(parameters: parameters, delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUpUsingParameters_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertNil(controllerFactoryMock.signUpController.signUpStartRequestParameters?.attributes)
        XCTAssertNotNil(controllerFactoryMock.signUpController.signUpStartRequestParameters)
    }

    func testSignUpUsingParameters_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpCodeRequired")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    func testSignUpUsingParameters_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignUpParameters(username: "correct")
        sut.signUp(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignUpAttributesInvalid")
        )
        XCTAssertEqual(delegate.error?.correlationId, correlationId)
    }

    // MARK: - Sign in with password

    func testSignInPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername, correlationId: correlationId))
        
        let parameters = MSALNativeAuthSignInParameters(username: "")
        parameters.password = ""
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func testSignInPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidCredentials, correlationId: correlationId))
        
        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = ""
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignInPassword_delegate_whenValidUserAndPasswordAreUsed_shouldReturnSuccess() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1, expectedUserAccountResult: MSALNativeAuthUserAccountResultStub.result)

        controllerFactoryMock.signInController.signInStartResult = .init(.init(.completed(MSALNativeAuthUserAccountResultStub.result), correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        }))
        
        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInPassword_delegate_whenSuccessIsReturnedButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCompleted"), correlationId: correlationId)
        let delegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .completed(MSALNativeAuthUserAccountResultStub.result)

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    func testSignInPassword_delegate_whenCodeIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        
        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }
    
    func testSignInPasswordDelegate_checkClaimsParameterRequestShouldReturnedInCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        var error: NSError? = nil
        let claimsRequestJson = "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"c3\"}}}"
        let claimsRequest = MSALClaimsRequest(jsonString: claimsRequestJson , error: &error)

        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: claimsRequestJson, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        
        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        
        let params = MSALNativeAuthSignInParameters(username: "correct")
        params.password = "correct"
        params.claimsRequest = claimsRequest
        sut.signIn(parameters: params, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInPassword_delegate_whenCodeIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCodeRequired"), correlationId: correlationId)
        let delegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // MARK: - Sign in using parameters with password

    func testSignInUsingParametersPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername, correlationId: correlationId))
        let parameters = MSALNativeAuthSignInParameters(username: "")
        parameters.password = ""
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignInUsingParametersPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidCredentials, correlationId: correlationId))
        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = ""
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignInUsingParametersPassword_delegate_whenValidUserAndPasswordAreUsed_shouldReturnSuccess() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1, expectedUserAccountResult: MSALNativeAuthUserAccountResultStub.result)

        controllerFactoryMock.signInController.signInStartResult = .init(.init(.completed(MSALNativeAuthUserAccountResultStub.result), correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        }))
        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInUsingParametersPassword_delegate_whenSuccessIsReturnedButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCompleted"), correlationId: correlationId)
        let delegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .completed(MSALNativeAuthUserAccountResultStub.result)

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    func testSignInUsingParametersPassword_delegate_whenCodeIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInUsingParametersPassword_delegate_whenCodeIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCodeRequired"), correlationId: correlationId)
        let delegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        parameters.password = "correct"
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // MARK: - Sign in with code

    func testSignIn_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername, correlationId: correlationId))
        
        let parameters = MSALNativeAuthSignInParameters(username: "")
        sut.signIn(parameters: parameters, delegate: delegate)
        
        wait(for: [expectation], timeout: 1)
    }

    func testSignIn_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignInCodeStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignIn_delegate_whenValidUserIsUsedButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCodeRequired"), correlationId: correlationId)
        let delegate = SignInCodeStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    func testSignIn_delegate_whenPasswordIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnPasswordRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInCodeStartDelegateWithPasswordRequiredSpy(expectation: exp1)

        let expectedState = SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "continuationToken", correlationId: correlationId)
        let expectedResult: SignInStartResult = .passwordRequired(newState: expectedState)

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)

        XCTAssertEqual(delegate.passwordRequiredState?.continuationToken, expectedState.continuationToken)
    }

    func testSignIn_delegate_whenPasswordIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInPasswordRequired"), correlationId: correlationId)
        let delegate = SignInCodeStartDelegateSpy(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .passwordRequired(
            newState: SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId)
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // MARK: - Sign in using parameters with code

    func testSignInUsingParameters_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername, correlationId: correlationId))
        let parameters = MSALNativeAuthSignInParameters(username: "")
        sut.signIn(parameters: parameters, delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignInUsingParameters_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignInCodeStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInUsingParameters_delegate_whenValidUserIsUsedButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInCodeRequired"), correlationId: correlationId)
        let delegate = SignInCodeStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    func testSignInUsingParameters_delegate_whenPasswordIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnPasswordRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInCodeStartDelegateWithPasswordRequiredSpy(expectation: exp1)

        let expectedState = SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "continuationToken", correlationId: correlationId)
        let expectedResult: SignInStartResult = .passwordRequired(newState: expectedState)

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)

        XCTAssertEqual(delegate.passwordRequiredState?.continuationToken, expectedState.continuationToken)
    }

    func testSignInUsingParameters_delegate_whenPasswordIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onSignInPasswordRequired"), correlationId: correlationId)
        let delegate = SignInCodeStartDelegateSpy(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .passwordRequired(
            newState: SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, claimsRequestJson: nil, continuationToken: "", correlationId: correlationId)
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthSignInParameters(username: "correct")
        sut.signIn(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // MARK: - ResetPassword

    func testResetPassword_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-in public interface")
        let delegate = ResetPasswordStartDelegateSpy(expectation: exp)
        
        let parameters = MSALNativeAuthResetPasswordParameters(username: "")
        sut.resetPassword(parameters: parameters, delegate: delegate)
        wait(for: [exp])
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testResetPassword_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = ResetPasswordStartDelegateSpy(expectation: exp1)

        let expectedResult: ResetPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.resetPasswordController, username: "username", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.resetPasswordController.resetPasswordResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        
        let parameters = MSALNativeAuthResetPasswordParameters(username: "correct")
        sut.resetPassword(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)

        XCTAssertEqual(delegate.newState?.continuationToken, "continuationToken")
        XCTAssertEqual(delegate.newState?.username, "username")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func testResetPassword_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "reset-password public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = ResetPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        let expectedResult: ResetPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.resetPasswordController, username: "username", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.resetPasswordController.resetPasswordResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthResetPasswordParameters(username: "correct")
        sut.resetPassword(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onResetPasswordCodeRequired")
        )
    }

    // MARK: - ResetPassword using parameters

    func testResetPasswordUsingParameters_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-in public interface")
        let delegate = ResetPasswordStartDelegateSpy(expectation: exp)
        let parameters = MSALNativeAuthResetPasswordParameters(username: "")
        sut.resetPassword(parameters: parameters, delegate: delegate)
        wait(for: [exp])
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testResetPasswordUsingParameters_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = ResetPasswordStartDelegateSpy(expectation: exp1)

        let expectedResult: ResetPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.resetPasswordController, username: "username", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )

        controllerFactoryMock.resetPasswordController.resetPasswordResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthResetPasswordParameters(username: "correct")
        sut.resetPassword(parameters: parameters, delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)

        XCTAssertEqual(delegate.newState?.continuationToken, "continuationToken")
        XCTAssertEqual(delegate.newState?.username, "username")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func testResetPasswordUsingParameters_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "reset-password public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = ResetPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        let expectedResult: ResetPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.resetPasswordController, username: "username", continuationToken: "continuationToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 1
        )
        controllerFactoryMock.resetPasswordController.resetPasswordResponse = .init(expectedResult, correlationId: correlationId, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        let parameters = MSALNativeAuthResetPasswordParameters(username: "correct")
        sut.resetPassword(parameters: parameters, delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            String(format: MSALNativeAuthErrorMessage.delegateNotImplemented, "onResetPasswordCodeRequired")
        )
    }

    // MARK: - CorrelationId
        
    // SignUp Password
    // Testing SingUpStart -> SingUpChallenge -> SingUpContinue -> SignInToken with Password
    
    func testSignUpPassword_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationPasswordStart = expectation(description: "Sign Up Password Start")
        let delegatePasswordStart = SignUpPasswordStartDelegateSpy(expectation: expectationPasswordStart)
        let expectationVerifyCode = expectation(description: "Sign Up Verify Code")
        let delegateVerifyCode = SignUpVerifyCodeDelegateSpy(expectation: expectationVerifyCode)
        let expectationSignInAfterSingUp = expectation(description: "Sign In After Sign Up")
        let delegateSignInAfterSignUp = SignInAfterSignUpDelegateSpy(expectation: expectationSignInAfterSingUp)
        
        let signUpRequestProviderMock = MSALNativeAuthSignUpRequestProviderMock()
        signUpRequestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedStartRequestParameters = expectedSignUpStartPasswordParams
        signUpRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedChallengeRequestParameters = expectedSignUpChallengeParams()
        signUpRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedContinueRequestParameters = expectedSignUpContinueParams(token: "continuationToken 2")
        
        let signUpResponseValidatorMock = MSALNativeAuthSignUpResponseValidatorMock()
        signUpResponseValidatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        signUpResponseValidatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", MSALNativeAuthChannelType(value: "email"), 4, "continuationToken 2"))
        signUpResponseValidatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: "continuationToken"))

        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        
        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, continuationToken: "continuationToken", grantType: MSALNativeAuthGrantType.continuationToken, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)
        
        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        
        delegateSignInAfterSignUp.expectedUserAccountResult = userAccountResult
        let signInAfterSignUpController = MSALNativeAuthSignInController(clientId: clientId,
                                                                         signInRequestProvider: signInRequestProviderMock,
                                                                         tokenRequestProvider: tokenRequestProviderMock, 
                                                                         cacheAccessor: cacheAccessorMock,
                                                                         factory: authResultFactoryMock,
                                                                         signInResponseValidator: MSALNativeAuthSignInResponseValidatorMock(),
                                                                         tokenResponseValidator: tokenResponseValidatorMock,
                                                                         nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let signUpController = MSALNativeAuthSignUpController(config: configuration,
                                                              requestProvider: signUpRequestProviderMock,
                                                              responseValidator: signUpResponseValidatorMock,
                                                              signInController: signInAfterSignUpController)
        
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signUpController: signUpController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )
        
        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkStartParameters and checkChallengeParameters functions
        let parameters = MSALNativeAuthSignUpParameters(username: "username")
        parameters.password = "password"
        parameters.attributes = ["key": "value"]
        parameters.correlationId = correlationId
        sut.signUp(parameters: parameters, delegate: delegatePasswordStart)
        
        wait(for: [expectationPasswordStart])
        
        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkContinueParameters function
        delegatePasswordStart.newState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        
        wait(for: [expectationVerifyCode])
        
        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        let parametersSingInAfterSignUp = MSALNativeAuthSignInAfterSignUpParameters()
        parametersSingInAfterSignUp.scopes = ["scope1", "scope2"]
        delegateVerifyCode.newSignInAfterSignUpState?.signIn(parameters: parametersSingInAfterSignUp, delegate: delegateSignInAfterSignUp)
        
        wait(for: [expectationSignInAfterSingUp])
        
        // User account result is validated internally against expectedUserAccountResult in the
        // SignInAfterSignUpDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateSignInAfterSignUp.onSignInCompletedCalled)
    }
    
    // SignUp Code
    // Testing SingUpStart -> SingUpChallenge -> SingUpContinue -> SignInToken with Code
    
    func testSignUpCode_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationCodeStart = expectation(description: "Sign Up Code Start")
        let delegateCodeStart = SignUpCodeStartDelegateSpy(expectation: expectationCodeStart)
        let expectationVerifyCode = expectation(description: "Sign Up Verify Code")
        let delegateVerifyCode = SignUpVerifyCodeDelegateSpy(expectation: expectationVerifyCode)
        let expectationSignInAfterSingUp = expectation(description: "Sign In After Sign Up")
        let delegateSignInAfterSignUp = SignInAfterSignUpDelegateSpy(expectation: expectationSignInAfterSingUp)
        
        let signUpRequestProviderMock = MSALNativeAuthSignUpRequestProviderMock()
        signUpRequestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedStartRequestParameters = expectedSignUpStartCodeParams
        signUpRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedChallengeRequestParameters = expectedSignUpChallengeParams()
        signUpRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedContinueRequestParameters = expectedSignUpContinueParams(token: "continuationToken 2")
        
        let signUpResponseValidatorMock = MSALNativeAuthSignUpResponseValidatorMock()
        signUpResponseValidatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        signUpResponseValidatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", MSALNativeAuthChannelType(value: "email"), 4, "continuationToken 2"))
        signUpResponseValidatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: "continuationToken"))

        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        
        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, continuationToken: "continuationToken", grantType: MSALNativeAuthGrantType.continuationToken, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)
        
        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        
        delegateSignInAfterSignUp.expectedUserAccountResult = userAccountResult
        let signInAfterSignUpController = MSALNativeAuthSignInController(clientId: clientId,
                                                                         signInRequestProvider: signInRequestProviderMock,
                                                                         tokenRequestProvider: tokenRequestProviderMock,
                                                                         cacheAccessor: cacheAccessorMock,
                                                                         factory: authResultFactoryMock,
                                                                         signInResponseValidator: MSALNativeAuthSignInResponseValidatorMock(),
                                                                         tokenResponseValidator: tokenResponseValidatorMock,
                                                                         nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let signUpController = MSALNativeAuthSignUpController(config: configuration,
                                                              requestProvider: signUpRequestProviderMock,
                                                              responseValidator: signUpResponseValidatorMock,
                                                              signInController: signInAfterSignUpController)
        
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signUpController: signUpController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )
        
        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkStartParameters and checkChallengeParameters functions
        let parameters = MSALNativeAuthSignUpParameters(username: "username")
        parameters.attributes = ["key": "value"]
        parameters.correlationId = correlationId
        sut.signUp(parameters: parameters, delegate: delegateCodeStart)
        
        wait(for: [expectationCodeStart])
        
        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkContinueParameters function
        delegateCodeStart.newState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        
        wait(for: [expectationVerifyCode])
        
        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        
        let parametersSingInAfterSignUp = MSALNativeAuthSignInAfterSignUpParameters()
        parametersSingInAfterSignUp.scopes = ["scope1", "scope2"]
        delegateVerifyCode.newSignInAfterSignUpState?.signIn(parameters: parametersSingInAfterSignUp, delegate: delegateSignInAfterSignUp)
        wait(for: [expectationSignInAfterSingUp])
        
        // User account result is validated internally against expectedUserAccountResult in the
        // SignInAfterSignUpDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateSignInAfterSignUp.onSignInCompletedCalled)
    }
    
    // SignIn Password
    // Testing SignInInitiate -> SignInChallenge -> SignInToken with Password
    
    func testSignInPassword_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationPasswordStart = expectation(description: "Sign In Password Start")
        let delegatePasswordStart = SignInPasswordStartDelegateSpy(expectation: expectationPasswordStart)
        let expectationVerifyCode = expectation(description: "Sign In Verify Code")
        let delegateVerifyCode = SignInVerifyCodeDelegateSpy(expectation: expectationVerifyCode)
        
        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = "username"
        
        signInRequestProviderMock.expectedContext = contextMock
        let continuationToken = "<continuationToken>"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 4
        let signInResponseValidatorMock = MSALNativeAuthSignInResponseValidatorMock()
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)
        
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: nil, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.oobCode, scope: expectedScopes, password: nil, oobCode: "1234", includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)
        
        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        
        delegateVerifyCode.expectedUserAccountResult = userAccountResult
        let signInController = MSALNativeAuthSignInController(clientId: clientId,
                                                              signInRequestProvider: signInRequestProviderMock,
                                                              tokenRequestProvider: tokenRequestProviderMock,
                                                              cacheAccessor: cacheAccessorMock,
                                                              factory: authResultFactoryMock,
                                                              signInResponseValidator: signInResponseValidatorMock,
                                                              tokenResponseValidator: tokenResponseValidatorMock,
                                                              nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signInController: signInController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )
        
        // Correlation Id is validated internally against contextMock on both initiate and challenge in the
        // MSALNativeAuthSignInRequestProviderMock class - checkContext function
        let parameters = MSALNativeAuthSignInParameters(username: "username")
        parameters.password = "password"
        parameters.scopes = ["scope1", "scope2"]
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegatePasswordStart)
        
        wait(for: [expectationPasswordStart])
        
        // Correlation Id is validated internally against expectedTokenParams
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        delegatePasswordStart.newSignInCodeRequiredState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        wait(for: [expectationVerifyCode])
        
        // User account result is validated internally against expectedUserAccountResult in the
        // SignInVerifyCodeDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateVerifyCode.onSignInCompletedCalled)
    }
    
    // SignIn Code
    // Testing SignInInitiate -> SignInChallenge -> SignInToken with Code
    
    func testSignInCode_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationCodeStart = expectation(description: "Sign In Code Start")
        let delegateCodeStart = SignInCodeStartDelegateSpy(expectation: expectationCodeStart)
        let expectationVerifyCode = expectation(description: "Sign In Verify Code")
        let delegateVerifyCode = SignInVerifyCodeDelegateSpy(expectation: expectationVerifyCode)
        
        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = "username"
        signInRequestProviderMock.expectedContext = contextMock
        
        let continuationToken = "<continuationToken>"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 4
        delegateCodeStart.expectedSentTo = expectedSentTo
        delegateCodeStart.expectedChannelTargetType = expectedChannelTargetType
        delegateCodeStart.expectedCodeLength = expectedCodeLength
        
        let signInResponseValidatorMock = MSALNativeAuthSignInResponseValidatorMock()
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)
        
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: nil, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.oobCode, scope: expectedScopes, password: nil, oobCode: "1234", includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)
        
        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult
        
        delegateVerifyCode.expectedUserAccountResult = userAccountResult
        let signInController = MSALNativeAuthSignInController(clientId: clientId,
                                                              signInRequestProvider: signInRequestProviderMock,
                                                              tokenRequestProvider: tokenRequestProviderMock,
                                                              cacheAccessor: cacheAccessorMock,
                                                              factory: authResultFactoryMock,
                                                              signInResponseValidator: signInResponseValidatorMock,
                                                              tokenResponseValidator: tokenResponseValidatorMock,
                                                              nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signInController: signInController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )
        
        // Correlation Id is validated internally against contextMock on both initiate and challenge in the
        // MSALNativeAuthSignInRequestProviderMock class - checkContext function
        let parameters = MSALNativeAuthSignInParameters(username: "username")
        parameters.scopes = ["scope1", "scope2"]
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegateCodeStart)
        wait(for: [expectationCodeStart])
        
        // Correlation Id is validated internally against expectedTokenParams
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        delegateCodeStart.newSignInCodeRequiredState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        wait(for: [expectationVerifyCode])
        
        // User account result is validated internally against expectedUserAccountResult in the
        // SignInVerifyCodeDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateVerifyCode.onSignInCompletedCalled)
    }
    
    // PasswordReset
    // Testing PasswordResetStart -> PasswordResetChallenge -> PasswordResetContinue -> PasswordResetComplete -> PasswordResetSubmit -> PollCompletion
    
    func testResetPassword_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationPasswordResetStart = expectation(description: "Password Reset Start")
        let delegatePasswordResetStart = ResetPasswordStartDelegateSpy(expectation: expectationPasswordResetStart)
        let expectationPasswordResetVerifyCode = expectation(description: "Password Reset Verify Code")
        let delegatePasswordResetVerifyCode = ResetPasswordVerifyCodeDelegateSpy(expectation: expectationPasswordResetVerifyCode)
        let expectationPasswordResetRequired = expectation(description: "Password Reset Required")
        let delegatePasswordResetRequired = ResetPasswordRequiredDelegateSpy(expectation: expectationPasswordResetRequired)
        let expectationSignInAfterResetPassword = expectation(description: "Sign In After Reset Password")
        let delegateSignInAfterResetPassword = SignInAfterResetPasswordDelegateSpy(expectation: expectationSignInAfterResetPassword)

        let resetPasswordRequestProviderMock = MSALNativeAuthResetPasswordRequestProviderMock ()
        resetPasswordRequestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedStartRequestParameters = expectedResetPasswordStartParams
        resetPasswordRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedChallengeRequestParameters = expectedResetPasswordChallengeParams(token: "continuationToken")
        resetPasswordRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedContinueRequestParameters = expectedResetPasswordContinueParams(token: "continuationToken 2")
        resetPasswordRequestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedSubmitRequestParameters = expectedResetPasswordSubmitParams(token: "continuationToken")
        resetPasswordRequestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedPollCompletionParameters = expectedResetPasswordPollCompletionParameters(token: "continuationToken 3")
        
        let resetPasswordResponseValidator = MSALNativeAuthResetPasswordResponseValidatorMock()
        resetPasswordResponseValidator.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        resetPasswordResponseValidator.mockValidateResetPasswordChallengeFunc(.success("sentTo", MSALNativeAuthChannelType(value: "email"), 4, "continuationToken 2"))
        resetPasswordResponseValidator.mockValidateResetPasswordContinueFunc(.success(continuationToken: "continuationToken"))
        resetPasswordResponseValidator.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken 3", pollInterval: 0))
        resetPasswordResponseValidator.mockValidateResetPasswordPollCompletionFunc(.success(status: .succeeded, continuationToken: "continuationToken"))

        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"

        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, continuationToken: "continuationToken", grantType: .continuationToken, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"

        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)

        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)
        delegateSignInAfterResetPassword.expectedUserAccountResult = userAccountResult

        let signInAfterResetPasswordController = MSALNativeAuthSignInController(clientId: clientId,
                                                                                signInRequestProvider: MSALNativeAuthSignInRequestProviderMock(),
                                                                                tokenRequestProvider: tokenRequestProviderMock,
                                                                                cacheAccessor: cacheAccessorMock,
                                                                                factory: authResultFactoryMock,
                                                                                signInResponseValidator: MSALNativeAuthSignInResponseValidatorMock(),
                                                                                tokenResponseValidator: tokenResponseValidatorMock,
                                                                                nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)

        let resetPasswordController = MSALNativeAuthResetPasswordController(config: configuration,
                                                                            requestProvider: resetPasswordRequestProviderMock,
                                                                            responseValidator: resetPasswordResponseValidator, 
                                                                            signInController: signInAfterResetPasswordController)

        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(resetPasswordController: resetPasswordController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )
        
        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthResetPasswordRequestProviderMock class - checkParameters(params: MSALNativeAuthResetPasswordStartRequestProviderParameters)
        // and checkParameters(token: String, context: MSIDRequestContext) functions
        let parameters = MSALNativeAuthResetPasswordParameters(username: "username")
        parameters.correlationId = correlationId
        sut.resetPassword(parameters: parameters, delegate: delegatePasswordResetStart)
        
        wait(for: [expectationPasswordResetStart])
        
        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthResetPasswordRequestProviderMock class - checkParameters(_ params: MSALNativeAuthResetPasswordContinueRequestParameters) function
        delegatePasswordResetStart.newState?.submitCode(code: "1234", delegate: delegatePasswordResetVerifyCode)
        
        wait(for: [expectationPasswordResetVerifyCode])
        
        // Correlation Id is validated internally against expectedSubmitRequestParameters and expectedPollCompletionParameters
        // MSALNativeAuthResetPasswordRequestProviderMock class - checkParameters(_ params: MSALNativeAuthResetPasswordSubmitRequestParameters) function
        // and checkParameters(_ params: MSALNativeAuthResetPasswordPollCompletionRequestParameters) function
        delegatePasswordResetVerifyCode.newPasswordRequiredState?.submitPassword(password: "password", delegate: delegatePasswordResetRequired)
        
        wait(for: [expectationPasswordResetRequired])
        
        XCTAssertTrue(delegatePasswordResetRequired.onResetPasswordCompletedCalled)

        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        let parametersSingInAfterSignUp = MSALNativeAuthSignInAfterResetPasswordParameters()
        parametersSingInAfterSignUp.scopes = ["scope1", "scope2"]
        delegatePasswordResetRequired.signInAfterResetPasswordState?.signIn(parameters: parametersSingInAfterSignUp, delegate: delegateSignInAfterResetPassword)
        wait(for: [expectationSignInAfterResetPassword])

        // User account result is validated internally against expectedUserAccountResult in the
        // SignInAfterSignUpDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateSignInAfterResetPassword.onSignInCompletedCalled)
    }

    // MARK: - CorrelationId using parameters

    // SignUp using parameters Password
    // Testing SingUpStart -> SingUpChallenge -> SingUpContinue -> SignInToken with Password

    func testSignUpUsingParametersPassword_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationPasswordStart = expectation(description: "Sign Up Password Start")
        let delegatePasswordStart = SignUpPasswordStartDelegateSpy(expectation: expectationPasswordStart)
        let expectationVerifyCode = expectation(description: "Sign Up Verify Code")
        let delegateVerifyCode = SignUpVerifyCodeDelegateSpy(expectation: expectationVerifyCode)
        let expectationSignInAfterSingUp = expectation(description: "Sign In After Sign Up")
        let delegateSignInAfterSignUp = SignInAfterSignUpDelegateSpy(expectation: expectationSignInAfterSingUp)

        let signUpRequestProviderMock = MSALNativeAuthSignUpRequestProviderMock()
        signUpRequestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedStartRequestParameters = expectedSignUpStartPasswordParams
        signUpRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedChallengeRequestParameters = expectedSignUpChallengeParams()
        signUpRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedContinueRequestParameters = expectedSignUpContinueParams(token: "continuationToken 2")

        let signUpResponseValidatorMock = MSALNativeAuthSignUpResponseValidatorMock()
        signUpResponseValidatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        signUpResponseValidatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", MSALNativeAuthChannelType(value: "email"), 4, "continuationToken 2"))
        signUpResponseValidatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: "continuationToken"))

        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()

        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"

        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"

        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, continuationToken: "continuationToken", grantType: MSALNativeAuthGrantType.continuationToken, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)

        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)

        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        delegateSignInAfterSignUp.expectedUserAccountResult = userAccountResult
        let signInAfterSignUpController = MSALNativeAuthSignInController(clientId: clientId,
                                                                         signInRequestProvider: signInRequestProviderMock,
                                                                         tokenRequestProvider: tokenRequestProviderMock,
                                                                         cacheAccessor: cacheAccessorMock,
                                                                         factory: authResultFactoryMock,
                                                                         signInResponseValidator: MSALNativeAuthSignInResponseValidatorMock(),
                                                                         tokenResponseValidator: tokenResponseValidatorMock,
                                                                         nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let signUpController = MSALNativeAuthSignUpController(config: configuration,
                                                              requestProvider: signUpRequestProviderMock,
                                                              responseValidator: signUpResponseValidatorMock,
                                                              signInController: signInAfterSignUpController)

        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signUpController: signUpController)

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )

        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkStartParameters and checkChallengeParameters functions
        let parametersSignUp = MSALNativeAuthSignUpParameters(username: "username")
        parametersSignUp.password = "password"
        parametersSignUp.attributes = ["key": "value"]
        parametersSignUp.correlationId = correlationId
        sut.signUp(parameters: parametersSignUp, delegate: delegatePasswordStart)

        wait(for: [expectationPasswordStart])

        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkContinueParameters function
        delegatePasswordStart.newState?.submitCode(code: "1234", delegate: delegateVerifyCode)

        wait(for: [expectationVerifyCode])

        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        let parametersSingInAfterSignUp = MSALNativeAuthSignInAfterSignUpParameters()
        parametersSingInAfterSignUp.scopes = ["scope1", "scope2"]
        delegateVerifyCode.newSignInAfterSignUpState?.signIn(parameters: parametersSingInAfterSignUp,
                                                             delegate: delegateSignInAfterSignUp)

        wait(for: [expectationSignInAfterSingUp])

        // User account result is validated internally against expectedUserAccountResult in the
        // SignInAfterSignUpDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateSignInAfterSignUp.onSignInCompletedCalled)
    }

    // SignUp using parameters Code
    // Testing SingUpStart -> SingUpChallenge -> SingUpContinue -> SignInToken with Code

    func testSignUpUsingParametersCode_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationCodeStart = expectation(description: "Sign Up Code Start")
        let delegateCodeStart = SignUpCodeStartDelegateSpy(expectation: expectationCodeStart)
        let expectationVerifyCode = expectation(description: "Sign Up Verify Code")
        let delegateVerifyCode = SignUpVerifyCodeDelegateSpy(expectation: expectationVerifyCode)
        let expectationSignInAfterSingUp = expectation(description: "Sign In After Sign Up")
        let delegateSignInAfterSignUp = SignInAfterSignUpDelegateSpy(expectation: expectationSignInAfterSingUp)

        let signUpRequestProviderMock = MSALNativeAuthSignUpRequestProviderMock()
        signUpRequestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedStartRequestParameters = expectedSignUpStartCodeParams
        signUpRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedChallengeRequestParameters = expectedSignUpChallengeParams()
        signUpRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signUpRequestProviderMock.expectedContinueRequestParameters = expectedSignUpContinueParams(token: "continuationToken 2")

        let signUpResponseValidatorMock = MSALNativeAuthSignUpResponseValidatorMock()
        signUpResponseValidatorMock.mockValidateSignUpStartFunc(.success(continuationToken: "continuationToken"))
        signUpResponseValidatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", MSALNativeAuthChannelType(value: "email"), 4, "continuationToken 2"))
        signUpResponseValidatorMock.mockValidateSignUpContinueFunc(.success(continuationToken: "continuationToken"))

        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()

        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"

        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"

        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, continuationToken: "continuationToken", grantType: MSALNativeAuthGrantType.continuationToken, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)

        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)

        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        delegateSignInAfterSignUp.expectedUserAccountResult = userAccountResult
        let signInAfterSignUpController = MSALNativeAuthSignInController(clientId: clientId,
                                                                         signInRequestProvider: signInRequestProviderMock,
                                                                         tokenRequestProvider: tokenRequestProviderMock,
                                                                         cacheAccessor: cacheAccessorMock,
                                                                         factory: authResultFactoryMock,
                                                                         signInResponseValidator: MSALNativeAuthSignInResponseValidatorMock(),
                                                                         tokenResponseValidator: tokenResponseValidatorMock,
                                                                         nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let signUpController = MSALNativeAuthSignUpController(config: configuration,
                                                              requestProvider: signUpRequestProviderMock,
                                                              responseValidator: signUpResponseValidatorMock,
                                                              signInController: signInAfterSignUpController)

        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signUpController: signUpController)

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )

        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkStartParameters and checkChallengeParameters functions
        let parametersSignUp = MSALNativeAuthSignUpParameters(username: "username")
        parametersSignUp.attributes = ["key": "value"]
        parametersSignUp.correlationId = correlationId
        sut.signUp(parameters: parametersSignUp, delegate: delegateCodeStart)

        wait(for: [expectationCodeStart])

        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkContinueParameters function
        delegateCodeStart.newState?.submitCode(code: "1234", delegate: delegateVerifyCode)

        wait(for: [expectationVerifyCode])

        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        let parametersSignInAfterSignUp = MSALNativeAuthSignInAfterSignUpParameters()
        parametersSignInAfterSignUp.scopes = ["scope1", "scope2"]
        delegateVerifyCode.newSignInAfterSignUpState?.signIn(parameters: parametersSignInAfterSignUp,
                                                             delegate: delegateSignInAfterSignUp)
        wait(for: [expectationSignInAfterSingUp])

        // User account result is validated internally against expectedUserAccountResult in the
        // SignInAfterSignUpDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateSignInAfterSignUp.onSignInCompletedCalled)
    }

    // SignIn using parameters Password
    // Testing SignInInitiate -> SignInChallenge -> SignInToken with Password

    func testSignInUsingParametersPassword_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationPasswordStart = expectation(description: "Sign In Password Start")
        let delegatePasswordStart = SignInPasswordStartDelegateSpy(expectation: expectationPasswordStart)
        let expectationVerifyCode = expectation(description: "Sign In Verify Code")
        let delegateVerifyCode = SignInVerifyCodeDelegateSpy(expectation: expectationVerifyCode)

        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = "username"

        signInRequestProviderMock.expectedContext = contextMock
        let continuationToken = "<continuationToken>"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 4
        let signInResponseValidatorMock = MSALNativeAuthSignInResponseValidatorMock()
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)

        let expectedScopes = "scope1 scope2 openid profile offline_access"

        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"

        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: nil, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.oobCode, scope: expectedScopes, password: nil, oobCode: "1234", includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)

        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)

        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        delegateVerifyCode.expectedUserAccountResult = userAccountResult
        let signInController = MSALNativeAuthSignInController(clientId: clientId,
                                                              signInRequestProvider: signInRequestProviderMock,
                                                              tokenRequestProvider: tokenRequestProviderMock,
                                                              cacheAccessor: cacheAccessorMock,
                                                              factory: authResultFactoryMock,
                                                              signInResponseValidator: signInResponseValidatorMock,
                                                              tokenResponseValidator: tokenResponseValidatorMock,
                                                              nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signInController: signInController)

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )

        // Correlation Id is validated internally against contextMock on both initiate and challenge in the
        // MSALNativeAuthSignInRequestProviderMock class - checkContext function
        let parameters = MSALNativeAuthSignInParameters(username: "username")
        parameters.password = "password"
        parameters.scopes = ["scope1", "scope2"]
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegatePasswordStart)

        wait(for: [expectationPasswordStart])

        // Correlation Id is validated internally against expectedTokenParams
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        delegatePasswordStart.newSignInCodeRequiredState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        wait(for: [expectationVerifyCode])

        // User account result is validated internally against expectedUserAccountResult in the
        // SignInVerifyCodeDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateVerifyCode.onSignInCompletedCalled)
    }

    // SignIn using parameters Code
    // Testing SignInInitiate -> SignInChallenge -> SignInToken with Code

    func testSignInUsingParametersCode_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationCodeStart = expectation(description: "Sign In Code Start")
        let delegateCodeStart = SignInCodeStartDelegateSpy(expectation: expectationCodeStart)
        let expectationVerifyCode = expectation(description: "Sign In Verify Code")
        let delegateVerifyCode = SignInVerifyCodeDelegateSpy(expectation: expectationVerifyCode)

        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        signInRequestProviderMock.mockInitiateRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        signInRequestProviderMock.expectedUsername = "username"
        signInRequestProviderMock.expectedContext = contextMock

        let continuationToken = "<continuationToken>"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType(value: "email")
        let expectedCodeLength = 4
        delegateCodeStart.expectedSentTo = expectedSentTo
        delegateCodeStart.expectedChannelTargetType = expectedChannelTargetType
        delegateCodeStart.expectedCodeLength = expectedCodeLength

        let signInResponseValidatorMock = MSALNativeAuthSignInResponseValidatorMock()
        signInResponseValidatorMock.initiateValidatedResponse = .success(continuationToken: continuationToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(continuationToken: continuationToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)

        let expectedScopes = "scope1 scope2 openid profile offline_access"

        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"

        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: nil, continuationToken: continuationToken, grantType: MSALNativeAuthGrantType.oobCode, scope: expectedScopes, password: nil, oobCode: "1234", includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)

        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)

        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        delegateVerifyCode.expectedUserAccountResult = userAccountResult
        let signInController = MSALNativeAuthSignInController(clientId: clientId,
                                                              signInRequestProvider: signInRequestProviderMock,
                                                              tokenRequestProvider: tokenRequestProviderMock,
                                                              cacheAccessor: cacheAccessorMock,
                                                              factory: authResultFactoryMock,
                                                              signInResponseValidator: signInResponseValidatorMock,
                                                              tokenResponseValidator: tokenResponseValidatorMock,
                                                              nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signInController: signInController)

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )

        // Correlation Id is validated internally against contextMock on both initiate and challenge in the
        // MSALNativeAuthSignInRequestProviderMock class - checkContext function
        let parameters = MSALNativeAuthSignInParameters(username: "username")
        parameters.scopes = ["scope1", "scope2"]
        parameters.correlationId = correlationId
        sut.signIn(parameters: parameters, delegate: delegateCodeStart)
        wait(for: [expectationCodeStart])

        // Correlation Id is validated internally against expectedTokenParams
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        delegateCodeStart.newSignInCodeRequiredState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        wait(for: [expectationVerifyCode])

        // User account result is validated internally against expectedUserAccountResult in the
        // SignInVerifyCodeDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateVerifyCode.onSignInCompletedCalled)
    }

    // PasswordReset using parameters
    // Testing PasswordResetStart -> PasswordResetChallenge -> PasswordResetContinue -> PasswordResetComplete -> PasswordResetSubmit -> PollCompletion

    func testResetPasswordUsingParameters_correlationId_whenSetOnStart_itCascadesToAll() {
        let expectationPasswordResetStart = expectation(description: "Password Reset Start")
        let delegatePasswordResetStart = ResetPasswordStartDelegateSpy(expectation: expectationPasswordResetStart)
        let expectationPasswordResetVerifyCode = expectation(description: "Password Reset Verify Code")
        let delegatePasswordResetVerifyCode = ResetPasswordVerifyCodeDelegateSpy(expectation: expectationPasswordResetVerifyCode)
        let expectationPasswordResetRequired = expectation(description: "Password Reset Required")
        let delegatePasswordResetRequired = ResetPasswordRequiredDelegateSpy(expectation: expectationPasswordResetRequired)
        let expectationSignInAfterResetPassword = expectation(description: "Sign In After Reset Password")
        let delegateSignInAfterResetPassword = SignInAfterResetPasswordDelegateSpy(expectation: expectationSignInAfterResetPassword)

        let resetPasswordRequestProviderMock = MSALNativeAuthResetPasswordRequestProviderMock ()
        resetPasswordRequestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedStartRequestParameters = expectedResetPasswordStartParams
        resetPasswordRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedChallengeRequestParameters = expectedResetPasswordChallengeParams(token: "continuationToken")
        resetPasswordRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedContinueRequestParameters = expectedResetPasswordContinueParams(token: "continuationToken 2")
        resetPasswordRequestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedSubmitRequestParameters = expectedResetPasswordSubmitParams(token: "continuationToken")
        resetPasswordRequestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedPollCompletionParameters = expectedResetPasswordPollCompletionParameters(token: "continuationToken 3")

        let resetPasswordResponseValidator = MSALNativeAuthResetPasswordResponseValidatorMock()
        resetPasswordResponseValidator.mockValidateResetPasswordStartFunc(.success(continuationToken: "continuationToken"))
        resetPasswordResponseValidator.mockValidateResetPasswordChallengeFunc(.success("sentTo", MSALNativeAuthChannelType(value: "email"), 4, "continuationToken 2"))
        resetPasswordResponseValidator.mockValidateResetPasswordContinueFunc(.success(continuationToken: "continuationToken"))
        resetPasswordResponseValidator.mockValidateResetPasswordSubmitFunc(.success(continuationToken: "continuationToken 3", pollInterval: 0))
        resetPasswordResponseValidator.mockValidateResetPasswordPollCompletionFunc(.success(status: .succeeded, continuationToken: "continuationToken"))

        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"

        let tokenResult = MSIDTokenResult()
        tokenResult.rawIdToken = "idToken"
        let cacheAccessorMock = MSALNativeAuthCacheAccessorMock()
        cacheAccessorMock.expectedMSIDTokenResult = tokenResult

        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, continuationToken: "continuationToken", grantType: .continuationToken, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil, claimsRequestJson: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())

        let tokenResponse = MSALNativeAuthCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"

        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)

        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                rawIdToken: MSALNativeAuthUserAccountResultStub.rawIdToken,
                                                                configuration: MSALNativeAuthConfigStubs.configuration,
                                                                cacheAccessor: MSALNativeAuthCacheAccessorMock())
        authResultFactoryMock.mockMakeUserAccountResult(userAccountResult)
        delegateSignInAfterResetPassword.expectedUserAccountResult = userAccountResult

        let signInAfterResetPasswordController = MSALNativeAuthSignInController(clientId: clientId,
                                                                                signInRequestProvider: MSALNativeAuthSignInRequestProviderMock(),
                                                                                tokenRequestProvider: tokenRequestProviderMock,
                                                                                cacheAccessor: cacheAccessorMock,
                                                                                factory: authResultFactoryMock,
                                                                                signInResponseValidator: MSALNativeAuthSignInResponseValidatorMock(),
                                                                                tokenResponseValidator: tokenResponseValidatorMock,
                                                                                nativeAuthConfig: MSALNativeAuthConfigStubs.configuration)

        let resetPasswordController = MSALNativeAuthResetPasswordController(config: configuration,
                                                                            requestProvider: resetPasswordRequestProviderMock,
                                                                            responseValidator: resetPasswordResponseValidator,
                                                                            signInController: signInAfterResetPasswordController)

        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(resetPasswordController: resetPasswordController)

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            cacheAccessorFactory: cacheAccessorFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            configuration: MSALPublicClientApplicationConfig(
                clientId: "",
                redirectUri: "",
                authority: nil
            )
        )

        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthResetPasswordRequestProviderMock class - checkParameters(params: MSALNativeAuthResetPasswordStartRequestProviderParameters)
        // and checkParameters(token: String, context: MSIDRequestContext) functions
        let parametersResetPassword = MSALNativeAuthResetPasswordParameters(username: "username")
        parametersResetPassword.correlationId = correlationId
        sut.resetPassword(parameters: parametersResetPassword, delegate: delegatePasswordResetStart)

        wait(for: [expectationPasswordResetStart])

        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthResetPasswordRequestProviderMock class - checkParameters(_ params: MSALNativeAuthResetPasswordContinueRequestParameters) function
        delegatePasswordResetStart.newState?.submitCode(code: "1234", delegate: delegatePasswordResetVerifyCode)

        wait(for: [expectationPasswordResetVerifyCode])

        // Correlation Id is validated internally against expectedSubmitRequestParameters and expectedPollCompletionParameters
        // MSALNativeAuthResetPasswordRequestProviderMock class - checkParameters(_ params: MSALNativeAuthResetPasswordSubmitRequestParameters) function
        // and checkParameters(_ params: MSALNativeAuthResetPasswordPollCompletionRequestParameters) function
        delegatePasswordResetVerifyCode.newPasswordRequiredState?.submitPassword(password: "password", delegate: delegatePasswordResetRequired)

        wait(for: [expectationPasswordResetRequired])

        XCTAssertTrue(delegatePasswordResetRequired.onResetPasswordCompletedCalled)

        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        let parametersSingInAfterResetPassword = MSALNativeAuthSignInAfterResetPasswordParameters()
        parametersSingInAfterResetPassword.scopes = ["scope1", "scope2"]
        delegatePasswordResetRequired.signInAfterResetPasswordState?.signIn(parameters: parametersSingInAfterResetPassword,
                                                                            delegate: delegateSignInAfterResetPassword)
        wait(for: [expectationSignInAfterResetPassword])

        // User account result is validated internally against expectedUserAccountResult in the
        // SignInAfterSignUpDelegateSpy class - onSignInCompleted function
        XCTAssertTrue(delegateSignInAfterResetPassword.onSignInCompletedCalled)
    }

    // MARK: - Helper functions

    private var expectedSignUpStartPasswordParams: MSALNativeAuthSignUpStartRequestProviderParameters {
        .init(
            username: "username",
            password: "password",
            attributes: ["key": "value"],
            context: contextMock
        )
    }
    
    private var expectedSignUpStartCodeParams: MSALNativeAuthSignUpStartRequestProviderParameters {
        .init(
            username: "username",
            password: nil,
            attributes: ["key": "value"],
            context: contextMock
        )
    }
    
    private func expectedSignUpChallengeParams(token: String = "continuationToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }
    
    private func expectedSignUpContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "continuationToken",
        password: String? = nil,
        oobCode: String? = "1234",
        attributes: [String: Any]? = nil
    ) -> MSALNativeAuthSignUpContinueRequestProviderParams {
        .init(
            grantType: grantType,
            continuationToken: token,
            password: password,
            oobCode: oobCode,
            attributes: attributes,
            context: contextMock
        )
    }
    
    private var expectedResetPasswordStartParams: MSALNativeAuthResetPasswordStartRequestProviderParameters {
        .init(
            username: "username",
            context: contextMock
        )
    }
    
    private func expectedResetPasswordChallengeParams(token: String = "continuationToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }
    
    private func expectedResetPasswordContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "continuationToken",
        oobCode: String? = "1234"
    ) -> MSALNativeAuthResetPasswordContinueRequestParameters {
        .init(
            context: contextMock,
            continuationToken: token,
            grantType: grantType,
            oobCode: oobCode
        )
    }
    
    private func expectedResetPasswordSubmitParams(
        token: String = "continuationToken",
        password: String = "password"
    ) -> MSALNativeAuthResetPasswordSubmitRequestParameters {
        .init(
            context: contextMock,
            continuationToken: token,
            newPassword: password)
    }

    private func expectedResetPasswordPollCompletionParameters(
        token: String = "continuationToken"
    ) -> MSALNativeAuthResetPasswordPollCompletionRequestParameters {
        .init(
            context: contextMock,
            continuationToken: token)
    }
}
