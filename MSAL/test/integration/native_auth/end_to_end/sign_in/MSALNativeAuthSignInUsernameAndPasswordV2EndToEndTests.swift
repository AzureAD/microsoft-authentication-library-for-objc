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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import XCTest
import MSAL

final class MSALNativeAuthSignInUsernameAndPasswordV2EndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        throw XCTSkip("SignIn V2 requires a test slice. Disable this test until api is in prod.")
    }

    // Hero Scenario 1.2.1. Sign in - Use email and password to get token
    @MainActor
    func test_signInUsingPasswordWithKnownUsernameResultsInSuccess() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId),
              let username = retrieveUsernameForSignInUsernameAndPassword(),
              let password = await retrievePasswordForSignInUsername()
        else {
            XCTFail("Missing information")
            return
        }

        let flowCompletedExp = expectation(description: "sign in flow completed")
        let delegate = SignInV2DelegateSpy(expectation: flowCompletedExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.password = password
        parameters.correlationId = correlationId
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [flowCompletedExp])

        XCTAssertTrue(delegate.onFlowCompletedCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertNotNil(delegate.result?.idToken)
//        XCTAssertEqual(delegate.result?.account.username, username) // TODO: preferred_username is wrong in v2 id token
    }

    // Hero Scenario 1.2.2. Sign in - User is not registered with given email
    @MainActor
    func test_signInUsingPasswordWithUnknownUsernameResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId) else {
            XCTFail("Missing information")
            return
        }

        let flowErrorExp = expectation(description: "sign in flow error")
        let delegate = SignInV2DelegateSpy(expectation: flowErrorExp)

        let parameters = MSALNativeAuthSignInParameters(username: UUID().uuidString + "@contoso.com")
        parameters.password = "testpass"
        parameters.correlationId = correlationId
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [flowErrorExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.error?.isUserNotFound, true)
    }

    // Hero Scenario 1.2.3. Sign in - Password is incorrect
    @MainActor
    func test_signInWithKnownUsernameInvalidPasswordResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId),
              let username = retrieveUsernameForSignInUsernameAndPassword()
        else {
            XCTFail("Missing information")
            return
        }

        let flowErrorExp = expectation(description: "sign in flow error")
        let delegate = SignInV2DelegateSpy(expectation: flowErrorExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.password = "An Invalid Password"
        parameters.correlationId = correlationId
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [flowErrorExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.error?.isInvalidCredentials, true)
    }

    // User Case 1.2.4. Sign In - User signs in with account A, while data for account A already exists in SDK persistence
    @MainActor
    func test_signInWithSameAccountSigned() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId),
              let username = retrieveUsernameForSignInUsernameAndPassword(),
              let password = await retrievePasswordForSignInUsername()
        else {
            XCTFail("Missing information")
            return
        }

        let firstFlowCompletedExp = expectation(description: "first sign in flow completed")
        let firstDelegate = SignInV2DelegateSpy(expectation: firstFlowCompletedExp)

        let firstParameters = MSALNativeAuthSignInParameters(username: username)
        firstParameters.password = password
        firstParameters.correlationId = correlationId
        sut.signInV2(parameters: firstParameters, delegate: firstDelegate)

        await fulfillment(of: [firstFlowCompletedExp])

        XCTAssertTrue(firstDelegate.onFlowCompletedCalled)
        XCTAssertEqual(firstDelegate.scenario, .signIn)
        XCTAssertNotNil(firstDelegate.result?.idToken)
//        XCTAssertEqual(firstDelegate.result?.account.username, username) // TODO: preferred_username is wrong in v2 id token. Work item: https://identitydivision.visualstudio.com/Engineering/_workitems/edit/3733810

        let secondFlowCompletedExp = expectation(description: "second sign in flow completed")
        let secondDelegate = SignInV2DelegateSpy(expectation: secondFlowCompletedExp)

        let secondParameters = MSALNativeAuthSignInParameters(username: username)
        secondParameters.password = password
        secondParameters.correlationId = correlationId
        sut.signInV2(parameters: secondParameters, delegate: secondDelegate)

        await fulfillment(of: [secondFlowCompletedExp])

        XCTAssertTrue(secondDelegate.onFlowCompletedCalled)
        XCTAssertEqual(secondDelegate.scenario, .signIn)
        XCTAssertNotNil(secondDelegate.result?.idToken)
//        XCTAssertEqual(secondDelegate.result?.account.username, username) // TODO: preferred_username is wrong in v2 id token
    }

    // User Case 1.2.5. Sign In - User signs in with account B, while data for account A already exists in SDK persistence
    @MainActor
    func test_signInWithDifferentAccountSigned() async throws {
        let secondUsername = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId),
              let username = retrieveUsernameForSignInUsernameAndPassword(),
              let password = await retrievePasswordForSignInUsername()
        else {
            XCTFail("Missing information")
            return
        }

        let firstFlowCompletedExp = expectation(description: "first sign in flow completed")
        let firstDelegate = SignInV2DelegateSpy(expectation: firstFlowCompletedExp)

        let firstParameters = MSALNativeAuthSignInParameters(username: username)
        firstParameters.password = password
        firstParameters.correlationId = correlationId
        sut.signInV2(parameters: firstParameters, delegate: firstDelegate)

        await fulfillment(of: [firstFlowCompletedExp])

        XCTAssertTrue(firstDelegate.onFlowCompletedCalled)
        XCTAssertEqual(firstDelegate.scenario, .signIn)
        XCTAssertNotNil(firstDelegate.result?.idToken)
//        XCTAssertEqual(firstDelegate.result?.account.username, username) // TODO: preferred_username is wrong in v2 id token

        let codeRequiredExp = expectation(description: "code required")
        let secondDelegate = SignInV2DelegateSpy(expectation: codeRequiredExp)

        markEmailCheckpoint()

        let secondParameters = MSALNativeAuthSignInParameters(username: secondUsername)
        secondParameters.correlationId = correlationId
        sut.signInV2(parameters: secondParameters, delegate: secondDelegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(secondDelegate.error)

        guard secondDelegate.onCodeRequiredCalled,
              let codeRequiredState = secondDelegate.codeRequiredState
        else {
            XCTFail("onCodeRequired not called")
            return
        }

        guard let code = await retrieveCodeFor(email: secondUsername) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let secondFlowCompletedExp = expectation(description: "second sign in flow completed")
        secondDelegate.reset(expectation: secondFlowCompletedExp)
        codeRequiredState.submitCode(code, delegate: secondDelegate)

        await fulfillment(of: [secondFlowCompletedExp])
        try skipIfEmailOTPThrottled(secondDelegate.error)

        XCTAssertTrue(secondDelegate.onFlowCompletedCalled)
        XCTAssertEqual(secondDelegate.scenario, .signIn)
        XCTAssertNotNil(secondDelegate.result?.idToken)
        XCTAssertEqual(secondDelegate.result?.account.username, secondUsername)
    }

    // User Case 1.2.7. Sign In - User email is registered with email OTP auth method, which is supported by the developer
    @MainActor
    func test_signInWithOTPSufficientChallengeResultsInSuccess() async throws {
        let username = try emailOTPUsernameForCurrentTest()

        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId),
              let password = await retrievePasswordForSignInUsername()
        else {
            XCTFail("Missing information")
            return
        }

        let codeRequiredExp = expectation(description: "code required")
        let delegate = SignInV2DelegateSpy(expectation: codeRequiredExp)

        markEmailCheckpoint()

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.password = password
        parameters.correlationId = correlationId
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [codeRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onCodeRequiredCalled,
              let codeRequiredState = delegate.codeRequiredState
        else {
            XCTFail("onCodeRequired not called")
            return
        }

        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.channelTargetType?.isEmailType, true)
        XCTAssertFalse(delegate.sentTo?.isEmpty ?? true)
        XCTAssertGreaterThan(delegate.codeLength, 0)

        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return
        }

        let flowCompletedExp = expectation(description: "sign in flow completed")
        delegate.reset(expectation: flowCompletedExp)
        codeRequiredState.submitCode(code, delegate: delegate)

        await fulfillment(of: [flowCompletedExp])
        try skipIfEmailOTPThrottled(delegate.error)

        XCTAssertTrue(delegate.onFlowCompletedCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertNotNil(delegate.result?.idToken)
        XCTAssertEqual(delegate.result?.account.username, username)
    }

    // Sign in - Password is incorrect (sent over MSALNativeAuthPasswordRequiredState)
    @MainActor
    func test_signInAndSendingIncorrectPasswordResultsInError() async throws {
        guard let sut = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId),
              let username = retrieveUsernameForSignInUsernameAndPassword()
        else {
            XCTFail("Missing information")
            return
        }

        let passwordRequiredExp = expectation(description: "password required")
        let delegate = SignInV2DelegateSpy(expectation: passwordRequiredExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.correlationId = correlationId
        sut.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [passwordRequiredExp])

        guard delegate.onPasswordRequiredCalled,
              let passwordRequiredState = delegate.passwordRequiredState
        else {
            XCTFail("onPasswordRequired not called")
            return
        }

        XCTAssertEqual(delegate.scenario, .signIn)

        let flowErrorExp = expectation(description: "sign in flow error")
        delegate.reset(expectation: flowErrorExp)
        passwordRequiredState.submitPassword("An Invalid Password", delegate: delegate)

        await fulfillment(of: [flowErrorExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.error?.isInvalidPassword, true)
    }
}

@MainActor
private final class SignInV2DelegateSpy: NSObject,
    MSALNativeAuthCodeRequiredDelegate,
    MSALNativeAuthPasswordRequiredDelegate {

    private var expectation: XCTestExpectation

    private(set) var onCodeRequiredCalled = false
    private(set) var onPasswordRequiredCalled = false
    private(set) var onFlowCompletedCalled = false
    private(set) var onFlowErrorCalled = false

    private(set) var codeRequiredState: MSALNativeAuthCodeRequiredState?
    private(set) var passwordRequiredState: MSALNativeAuthPasswordRequiredState?
    private(set) var result: MSALNativeAuthUserAccountResult?
    private(set) var error: MSALNativeAuthFlowError?
    private(set) var scenario: MSALNativeAuthFlowScenario?
    private(set) var sentTo: String?
    private(set) var channelTargetType: MSALNativeAuthChannelType?
    private(set) var codeLength = 0

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
        super.init()
    }

    func reset(expectation: XCTestExpectation) {
        self.expectation = expectation
        onCodeRequiredCalled = false
        onPasswordRequiredCalled = false
        onFlowCompletedCalled = false
        onFlowErrorCalled = false
        codeRequiredState = nil
        passwordRequiredState = nil
        result = nil
        error = nil
        scenario = nil
        sentTo = nil
        channelTargetType = nil
        codeLength = 0
    }

    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario) {
        onCodeRequiredCalled = true
        codeRequiredState = state
        sentTo = state.sentTo
        channelTargetType = state.channel
        codeLength = state.codeLength
        self.scenario = scenario
        expectation.fulfill()
    }

    func onPasswordRequired(state: MSALNativeAuthPasswordRequiredState, scenario: MSALNativeAuthFlowScenario) {
        onPasswordRequiredCalled = true
        passwordRequiredState = state
        self.scenario = scenario
        expectation.fulfill()
    }

    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        onFlowCompletedCalled = true
        self.result = result
        self.scenario = scenario
        expectation.fulfill()
    }

    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        onFlowErrorCalled = true
        self.error = error
        self.scenario = scenario
        expectation.fulfill()
    }
}
