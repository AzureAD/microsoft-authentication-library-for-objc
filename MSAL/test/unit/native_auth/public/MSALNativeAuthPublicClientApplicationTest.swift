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
    private var sut: MSALNativeAuthPublicClientApplication!
    private var correlationId: UUID = UUID()

    private let clientId = "clientId"
    private let authorityURL = URL(string: "https://microsoft.com")
    
    private var authority: MSALCIAMAuthority!
    private var configuration : MSALNativeAuthConfiguration!
    private var contextMock: MSALNativeAuthRequestContext!
    
    override func setUp() {
        super.setUp()

        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactoryMock,
            inputValidator: MSALNativeAuthInputValidator(),
            internalChallengeTypes: []
        )
        
        authority = try! MSALCIAMAuthority(url: authorityURL!)
        configuration = try! MSALNativeAuthConfiguration(clientId: clientId, authority: authority!, challengeTypes: [.oob, .password])
        contextMock = .init(correlationId: .init(uuidString: correlationId.uuidString)!)
    }

    func testInit_whenPassingB2CAuthority_itShouldThrowError() throws {
        let b2cAuthority = try MSALB2CAuthority(url: .init(string: "https://login.contoso.com")!)
        let configuration = MSALPublicClientApplicationConfig(clientId: DEFAULT_TEST_CLIENT_ID, redirectUri: nil, authority: b2cAuthority)

        XCTAssertThrowsError(try MSALNativeAuthPublicClientApplication(configuration: configuration, challengeTypes: [.password]))
    }

    func testInit_whenPassingNilRedirectUri_itShouldNotThrowError() {
        XCTAssertNoThrow(try MSALNativeAuthPublicClientApplication(clientId: "genericClient", tenantSubdomain: "genericTenenat", challengeTypes: [.OOB]))
    }

    // MARK: - Delegates

    // Sign Up with password

    func testSignUpPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        sut.signUpUsingPassword(username: "", password: "", delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUpPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        sut.signUpUsingPassword(username: "correct", password: "", delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidPassword)
    }

    func testSignUpPassword_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "sign-up public interface telemetry")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp1)

        let expectedResult: SignUpPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUpUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp1, exp2])

        XCTAssertEqual(delegate.newState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func testSignUpPassword_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "sign-up public interface telemetry")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        
        let expectedResult: SignUpPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUpUsingPassword(username: "correct", password: "correct", delegate: delegate)
        
        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignUpCodeRequired")
        )
    }

    func testSignUpPassword_delegate_whenSendAttributes_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpPasswordStartDelegateSpy(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpPasswordStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUpUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.attributeNames, expectedInvalidAttributes)
    }

    func testSignUpPassword_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpPasswordStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUpUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription, 
            MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignUpAttributesInvalid")
        )
    }

    // Sign Up with code

    func testSignUp_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-up public interface")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)
        sut.signUp(username: "", delegate: delegate)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testSignUp_delegate_whenValidDataIsPassed_shouldReturnCodeRequired() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUp(username: "correct", delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.newState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func testSignUp_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        let expectedResult: SignUpStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.signUpController, username: "", flowToken: "flowToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUp(username: "correct", delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignUpCodeRequired")
        )
    }

    func testSignUp_delegate_whenSendAttributes_shouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpCodeStartDelegateSpy(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUp(username: "correct", delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.attributeNames, expectedInvalidAttributes)
    }

    func testSignUp_delegate_whenSendAttributes_butDelegateMethodIsNotImplemented_itShouldReturnAttributesInvalid() {
        let exp = expectation(description: "sign-up public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignUpStartDelegateOptionalMethodsNotImplemented(expectation: exp)
        let expectedInvalidAttributes = ["attribute"]

        let expectedResult: SignUpStartResult = .attributesInvalid(expectedInvalidAttributes)
        controllerFactoryMock.signUpController.startResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signUp(username: "correct", delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignUpAttributesInvalid")
        )
    }

    // Sign in with password

    func testSignInPassword_delegate_whenInvalidUsernameUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername))
        sut.signInUsingPassword(username: "", password: "", delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }
    
    func testSignInPassword_delegate_whenInvalidPasswordUsed_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInPasswordStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidPassword))
        sut.signInUsingPassword(username: "correct", password: "", delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignInPassword_delegate_whenValidUserAndPasswordAreUsed_shouldReturnSuccess() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1, expectedUserAccountResult: MSALNativeAuthUserAccountResultStub.result)

        controllerFactoryMock.signInController.signInPasswordStartResult = .init(.init(.completed(MSALNativeAuthUserAccountResultStub.result), telemetryUpdate: { _ in
            exp2.fulfill()
        }))
        sut.signInUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInPassword_delegate_whenSuccessIsReturnedButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignInCompleted"))
        let delegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInPasswordStartResult = .completed(MSALNativeAuthUserAccountResultStub.result)

        controllerFactoryMock.signInController.signInPasswordStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signInUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    func testSignInPassword_delegate_whenCodeIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInPasswordStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = .email

        let expectedResult: SignInPasswordStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        
        controllerFactoryMock.signInController.signInPasswordStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signInUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignInPassword_delegate_whenCodeIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInPasswordStartError(type: .generalError, message: MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignInCodeRequired"))
        let delegate = SignInPasswordStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInPasswordStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInPasswordStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signInUsingPassword(username: "correct", password: "correct", delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // Sign in with code

    func testSignIn_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let expectation = expectation(description: "sign-in public interface")
        let delegate = SignInCodeStartDelegateSpy(expectation: expectation, expectedError: .init(type: .invalidUsername))
        sut.signIn(username: "", delegate: delegate)
        wait(for: [expectation], timeout: 1)
    }

    func testSignIn_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = SignInCodeStartDelegateSpy(expectation: exp1)
        delegate.expectedSentTo = "sentTo"
        delegate.expectedCodeLength = 1
        delegate.expectedChannelTargetType = .email

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        sut.signIn(username: "correct", delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)
    }

    func testSignIn_delegate_whenValidUserIsUsedButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignInCodeRequired"))
        let delegate = SignInCodeStartDelegateOptionalMethodNotImplemented(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .codeRequired(
            newState: SignInCodeRequiredState(scopes: [], controller: controllerFactoryMock.signInController, flowToken: "", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signIn(username: "correct", delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    func testSignIn_delegate_whenPasswordIsRequiredAndUserHasImplementedOptionalDelegate_shouldReturnPasswordRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let delegate = SignInCodeStartDelegateWithPasswordRequiredSpy(expectation: exp1)

        let expectedState = SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, flowToken: "flowToken", correlationId: correlationId)
        let expectedResult: SignInStartResult = .passwordRequired(newState: expectedState)

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signIn(username: "correct", delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)

        XCTAssertEqual(delegate.passwordRequiredState?.flowToken, expectedState.flowToken)
    }

    func testSignIn_delegate_whenPasswordIsRequiredButUserHasNotImplementedOptionalDelegate_shouldReturnError() {
        let exp = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")

        let expectedError = SignInStartError(type: .generalError, message: MSALNativeAuthErrorMessage.requiredDelegateMethod("onSignInPasswordRequired"))
        let delegate = SignInCodeStartDelegateSpy(expectation: exp, expectedError: expectedError)

        let expectedResult: SignInStartResult = .passwordRequired(
            newState: SignInPasswordRequiredState(scopes: [], username: "", controller: controllerFactoryMock.signInController, flowToken: "", correlationId: correlationId)
        )

        controllerFactoryMock.signInController.signInStartResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.signIn(username: "correct", delegate: delegate)

        wait(for: [exp, exp2], timeout: 1)
    }

    // ResetPassword

    func testResetPassword_delegate_whenInvalidUser_shouldReturnCorrectError() {
        let exp = expectation(description: "sign-in public interface")
        let delegate = ResetPasswordStartDelegateSpy(expectation: exp)
        sut.resetPassword(username: "", delegate: delegate)
        wait(for: [exp])
        XCTAssertEqual(delegate.error?.type, .invalidUsername)
    }

    func testResetPassword_delegate_whenValidUserIsUsed_shouldReturnCodeRequired() {
        let exp1 = expectation(description: "sign-in public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = ResetPasswordStartDelegateSpy(expectation: exp1)

        let expectedResult: ResetPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.resetPasswordController, flowToken: "flowToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )

        controllerFactoryMock.resetPasswordController.resetPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })
        sut.resetPassword(username: "correct", delegate: delegate)

        wait(for: [exp1, exp2], timeout: 1)

        XCTAssertEqual(delegate.newState?.flowToken, "flowToken")
        XCTAssertEqual(delegate.sentTo, "sentTo")
        XCTAssertEqual(delegate.channelTargetType, .email)
        XCTAssertEqual(delegate.codeLength, 1)
    }

    func testResetPassword_delegate_butDelegateMethodIsNotImplemented_shouldReturnError() {
        let exp = expectation(description: "reset-password public interface")
        let exp2 = expectation(description: "expectation Telemetry")
        let delegate = ResetPasswordStartDelegateOptionalMethodsNotImplemented(expectation: exp)

        let expectedResult: ResetPasswordStartResult = .codeRequired(
            newState: .init(controller: controllerFactoryMock.resetPasswordController, flowToken: "flowToken", correlationId: correlationId),
            sentTo: "sentTo",
            channelTargetType: .email,
            codeLength: 1
        )
        controllerFactoryMock.resetPasswordController.resetPasswordResult = .init(expectedResult, telemetryUpdate: { _ in
            exp2.fulfill()
        })

        sut.resetPassword(username: "correct", delegate: delegate)

        wait(for: [exp, exp2])

        XCTAssertEqual(delegate.error?.type, .generalError)
        XCTAssertEqual(
            delegate.error?.errorDescription,
            MSALNativeAuthErrorMessage.requiredDelegateMethod("onResetPasswordCodeRequired")
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
        signUpRequestProviderMock.expectedContinueRequestParameters = expectedSignUpContinueParams(token: "signUpToken 2")
        
        let signUpResponseValidatorMock = MSALNativeAuthSignUpResponseValidatorMock()
        signUpResponseValidatorMock.mockValidateSignUpStartFunc((.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""])))
        signUpResponseValidatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken 2"))
        signUpResponseValidatorMock.mockValidateSignUpContinueFunc(.success("signInSLT"))
        
        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        
        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSIDCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, credentialToken: nil, signInSLT: "signInSLT", grantType: MSALNativeAuthGrantType.slt, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                authTokens: MSALNativeAuthTokens(accessToken: nil,
                                                                                                 refreshToken: nil,
                                                                                                 rawIdToken: nil),
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
                                                                         tokenResponseValidator: tokenResponseValidatorMock)
        let signUpController = MSALNativeAuthSignUpController(config: configuration,
                                                              requestProvider: signUpRequestProviderMock,
                                                              responseValidator: signUpResponseValidatorMock,
                                                              signInController: signInAfterSignUpController)
        
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signUpController: signUpController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            inputValidator: MSALNativeAuthInputValidator(),
            internalChallengeTypes: []
        )
        
        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkStartParameters and checkChallengeParameters functions
        sut.signUpUsingPassword(username: "username", password: "password", attributes: ["key": "value"], correlationId: correlationId, delegate: delegatePasswordStart)
        
        wait(for: [expectationPasswordStart])
        
        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkContinueParameters function
        delegatePasswordStart.newState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        
        wait(for: [expectationVerifyCode])
        
        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        delegateVerifyCode.newSignInAfterSignUpState?.signIn(scopes: ["scope1", "scope2"], delegate: delegateSignInAfterSignUp)
        
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
        signUpRequestProviderMock.expectedContinueRequestParameters = expectedSignUpContinueParams(token: "signUpToken 2")
        
        let signUpResponseValidatorMock = MSALNativeAuthSignUpResponseValidatorMock()
        signUpResponseValidatorMock.mockValidateSignUpStartFunc((.verificationRequired(signUpToken: "signUpToken", unverifiedAttributes: [""])))
        signUpResponseValidatorMock.mockValidateSignUpChallengeFunc(.codeRequired("sentTo", .email, 4, "signUpToken 2"))
        signUpResponseValidatorMock.mockValidateSignUpContinueFunc(.success("signInSLT"))
        
        let signInRequestProviderMock = MSALNativeAuthSignInRequestProviderMock()
        
        let expectedUsername = "username"
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSIDCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: expectedUsername, credentialToken: nil, signInSLT: "signInSLT", grantType: MSALNativeAuthGrantType.slt, scope: expectedScopes, password: nil, oobCode: nil, includeChallengeType: true, refreshToken: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                authTokens: MSALNativeAuthTokens(accessToken: nil,
                                                                                                 refreshToken: nil,
                                                                                                 rawIdToken: nil),
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
                                                                         tokenResponseValidator: tokenResponseValidatorMock)
        let signUpController = MSALNativeAuthSignUpController(config: configuration,
                                                              requestProvider: signUpRequestProviderMock,
                                                              responseValidator: signUpResponseValidatorMock,
                                                              signInController: signInAfterSignUpController)
        
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signUpController: signUpController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            inputValidator: MSALNativeAuthInputValidator(),
            internalChallengeTypes: []
        )
        
        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkStartParameters and checkChallengeParameters functions
        sut.signUp(username: "username", attributes: ["key": "value"], correlationId: correlationId, delegate: delegateCodeStart)
        
        wait(for: [expectationCodeStart])
        
        // Correlation Id is validated internally against expectedContinueRequestParameters in the
        // MSALNativeAuthSignUpRequestProviderMock class - checkContinueParameters function
        delegateCodeStart.newState?.submitCode(code: "1234", delegate: delegateVerifyCode)
        
        wait(for: [expectationVerifyCode])
        
        // Correlation Id is validated internally against expectedTokenParams in the
        // MSALNativeAuthTokenRequestProviderMock class - checkContext function
        delegateVerifyCode.newSignInAfterSignUpState?.signIn(scopes: ["scope1", "scope2"], delegate: delegateSignInAfterSignUp)
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
        let credentialToken = "<credentialToken>"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4
        let signInResponseValidatorMock = MSALNativeAuthSignInResponseValidatorMock()
        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)
        
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSIDCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: nil, credentialToken: credentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.oobCode, scope: expectedScopes, password: nil, oobCode: "1234", includeChallengeType: true, refreshToken: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                authTokens: MSALNativeAuthTokens(accessToken: nil,
                                                                                                 refreshToken: nil,
                                                                                                 rawIdToken: nil),
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
                                                                         tokenResponseValidator: tokenResponseValidatorMock)
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signInController: signInController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            inputValidator: MSALNativeAuthInputValidator(),
            internalChallengeTypes: []
        )
        
        // Correlation Id is validated internally against contextMock on both initiate and challenge in the
        // MSALNativeAuthSignInRequestProviderMock class - checkContext function
        sut.signInUsingPassword(username: "username", password: "password", scopes: ["scope1", "scope2"], correlationId: correlationId, delegate: delegatePasswordStart)
        
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
        
        let credentialToken = "<credentialToken>"
        let expectedSentTo = "sentTo"
        let expectedChannelTargetType = MSALNativeAuthChannelType.email
        let expectedCodeLength = 4
        delegateCodeStart.expectedSentTo = expectedSentTo
        delegateCodeStart.expectedChannelTargetType = expectedChannelTargetType
        delegateCodeStart.expectedCodeLength = expectedCodeLength
        
        let signInResponseValidatorMock = MSALNativeAuthSignInResponseValidatorMock()
        signInResponseValidatorMock.initiateValidatedResponse = .success(credentialToken: credentialToken)
        signInResponseValidatorMock.challengeValidatedResponse = .codeRequired(credentialToken: credentialToken, sentTo: expectedSentTo, channelType: expectedChannelTargetType, codeLength: expectedCodeLength)
        
        let expectedScopes = "scope1 scope2 openid profile offline_access"
        
        let tokenResponse = MSIDCIAMTokenResponse()
        tokenResponse.accessToken = "accessToken"
        tokenResponse.scope = "openid profile email"
        tokenResponse.idToken = "idToken"
        tokenResponse.refreshToken = "refreshToken"
        
        let tokenRequestProviderMock = MSALNativeAuthTokenRequestProviderMock()
        tokenRequestProviderMock.expectedTokenParams = MSALNativeAuthTokenRequestParameters(context: contextMock, username: nil, credentialToken: credentialToken, signInSLT: nil, grantType: MSALNativeAuthGrantType.oobCode, scope: expectedScopes, password: nil, oobCode: "1234", includeChallengeType: true, refreshToken: nil)
        tokenRequestProviderMock.expectedContext = contextMock
        tokenRequestProviderMock.mockRequestTokenFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        
        let tokenResponseValidatorMock = MSALNativeAuthTokenResponseValidatorMock()
        tokenResponseValidatorMock.tokenValidatedResponse = .success(tokenResponse)
        
        let authResultFactoryMock = MSALNativeAuthResultFactoryMock()
        let userAccountResult = MSALNativeAuthUserAccountResult(account: MSALNativeAuthUserAccountResultStub.account,
                                                                authTokens: MSALNativeAuthTokens(accessToken: nil,
                                                                                                 refreshToken: nil,
                                                                                                 rawIdToken: nil),
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
                                                                         tokenResponseValidator: tokenResponseValidatorMock)
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(signInController: signInController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            inputValidator: MSALNativeAuthInputValidator(),
            internalChallengeTypes: []
        )
        
        // Correlation Id is validated internally against contextMock on both initiate and challenge in the
        // MSALNativeAuthSignInRequestProviderMock class - checkContext function
        sut.signIn(username: "username", scopes: ["scope1", "scope2"], correlationId: correlationId, delegate: delegateCodeStart)
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
        
        let resetPasswordRequestProviderMock = MSALNativeAuthResetPasswordRequestProviderMock ()
        resetPasswordRequestProviderMock.mockStartRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedStartRequestParameters = expectedResetPasswordStartParams
        resetPasswordRequestProviderMock.mockChallengeRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedChallengeRequestParameters = expectedResetPasswordChallengeParams(token: "passwordResetToken")
        resetPasswordRequestProviderMock.mockContinueRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedContinueRequestParameters = expectedResetPasswordContinueParams(token: "passwordResetToken 2")
        resetPasswordRequestProviderMock.mockSubmitRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedSubmitRequestParameters = expectedResetPasswordSubmitParams(token: "passwordSubmitToken")
        resetPasswordRequestProviderMock.mockPollCompletionRequestFunc(MSALNativeAuthHTTPRequestMock.prepareMockRequest())
        resetPasswordRequestProviderMock.expectedPollCompletionParameters = expectedResetPasswordPollCompletionParameters(token: "passwordResetToken 3")
        
        let resetPasswordResponseValidator = MSALNativeAuthResetPasswordResponseValidatorMock()
        resetPasswordResponseValidator.mockValidateResetPasswordStartFunc(.success(passwordResetToken: "passwordResetToken"))
        resetPasswordResponseValidator.mockValidateResetPasswordChallengeFunc(.success("sentTo", .email, 4, "passwordResetToken 2"))
        resetPasswordResponseValidator.mockValidateResetPasswordContinueFunc(.success(passwordSubmitToken: "passwordSubmitToken"))
        resetPasswordResponseValidator.mockValidateResetPasswordSubmitFunc(.success(passwordResetToken: "passwordResetToken 3", pollInterval: 0))
        resetPasswordResponseValidator.mockValidateResetPasswordPollCompletionFunc(.success(status: .succeeded))
        
        let resetPasswordController = MSALNativeAuthResetPasswordController(config: configuration,
                                                                            requestProvider: resetPasswordRequestProviderMock,
                                                                            responseValidator: resetPasswordResponseValidator)
        
        let controllerFactory = MSALNativeAuthControllerProtocolFactoryMock(resetPasswordController: resetPasswordController)
        
        sut = MSALNativeAuthPublicClientApplication(
            controllerFactory: controllerFactory,
            inputValidator: MSALNativeAuthInputValidator(),
            internalChallengeTypes: []
        )
        
        // Correlation Id is validated internally against expectedStartRequestParameters and expectedChallengeRequestParameters in the
        // MSALNativeAuthResetPasswordRequestProviderMock class - checkParameters(params: MSALNativeAuthResetPasswordStartRequestProviderParameters)
        // and checkParameters(token: String, context: MSIDRequestContext) functions
        sut.resetPassword(username: "username", correlationId: correlationId, delegate: delegatePasswordResetStart)
        
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
    }
    
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
    
    private func expectedSignUpChallengeParams(token: String = "signUpToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }
    
    private func expectedSignUpContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "signUpToken",
        password: String? = nil,
        oobCode: String? = "1234",
        attributes: [String: Any]? = nil
    ) -> MSALNativeAuthSignUpContinueRequestProviderParams {
        .init(
            grantType: grantType,
            signUpToken: token,
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
    
    private func expectedResetPasswordChallengeParams(token: String = "passwordResetToken") -> (token: String, context: MSIDRequestContext) {
        return (token: token, context: contextMock)
    }
    
    private func expectedResetPasswordContinueParams(
        grantType: MSALNativeAuthGrantType = .oobCode,
        token: String = "passwordResetToken",
        oobCode: String? = "1234"
    ) -> MSALNativeAuthResetPasswordContinueRequestParameters {
        .init(
            context: contextMock,
            passwordResetToken: token,
            grantType: grantType,
            oobCode: oobCode
        )
    }
    
    private func expectedResetPasswordSubmitParams(
        token: String = "passwordSubmitToken",
        password: String = "password"
    ) -> MSALNativeAuthResetPasswordSubmitRequestParameters {
        .init(
            context: contextMock,
            passwordSubmitToken: token,
            newPassword: password)
    }

    private func expectedResetPasswordPollCompletionParameters(
        token: String = "passwordResetToken"
    ) -> MSALNativeAuthResetPasswordPollCompletionRequestParameters {
        .init(
            context: contextMock,
            passwordResetToken: token)
    }
}
