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
import MSAL

final class MSALNativeAuthSignInWithMFAV2EndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        throw XCTSkip("SignIn V2 requires a test slice. Disable this test until api is in prod.")
    }

    @MainActor
    func test_signInUsingPasswordWithMFASubmitWrongChallengeResendChallengeThen_completeSuccessfully() async throws {
        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
              let password = await retrievePasswordForSignInUsername(),
              let application = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId)
        else {
            XCTFail("Missing information")
            return
        }

        let mfaRequiredExp = expectation(description: "MFA required")
        let delegate = SignInWithMFAV2DelegateSpy(expectation: mfaRequiredExp)

        guard let mfaRequiredState = await signInUsingPassword(
            application: application,
            username: username,
            password: password,
            delegate: delegate,
            expectation: mfaRequiredExp
        ) else {
            return
        }

        guard let verificationRequiredState = try await selectEmailAuthMethod(
            state: mfaRequiredState,
            delegate: delegate
        ) else {
            return
        }

        let invalidChallengeExp = expectation(description: "invalid MFA challenge")
        delegate.reset(expectation: invalidChallengeExp)
        verificationRequiredState.submitChallenge("wrong_code", delegate: delegate)

        await fulfillment(of: [invalidChallengeExp])

        XCTAssertTrue(delegate.onFlowErrorCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(delegate.error?.isInvalidCode, true)

        guard let newVerificationRequiredState = try await selectEmailAuthMethod(
            state: mfaRequiredState,
            delegate: delegate
        ) else {
            return
        }

        try await completeSignInWithMFAFlow(
            state: newVerificationRequiredState,
            username: username,
            delegate: delegate
        )
    }

    @MainActor
    func test_signInUsingPasswordWithMFAGetAuthMethodsAutomatically_thenCompleteSuccessfully() async throws {
        guard let username = retrieveUsernameForSignInUsernamePasswordAndMFA(),
              let password = await retrievePasswordForSignInUsername(),
              let application = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId)
        else {
            XCTFail("Missing information")
            return
        }

        let mfaRequiredExp = expectation(description: "MFA required")
        let delegate = SignInWithMFAV2DelegateSpy(expectation: mfaRequiredExp)

        guard let mfaRequiredState = await signInUsingPassword(
            application: application,
            username: username,
            password: password,
            delegate: delegate,
            expectation: mfaRequiredExp
        ) else {
            return
        }

        guard let verificationRequiredState = try await selectEmailAuthMethod(
            state: mfaRequiredState,
            delegate: delegate
        ) else {
            return
        }

        try await completeSignInWithMFAFlow(
            state: verificationRequiredState,
            username: username,
            delegate: delegate
        )
    }

    @MainActor
    func test_signInAuthenticationContextClaim_mfaFlowIsTriggeredAndAccessTokenContainsClaims() async throws {
        throw XCTSkip("SignIn V2 doesn't support claims yet.")

        guard let username = retrieveUsernameForSignInUsernameAndPassword(),
              let password = await retrievePasswordForSignInUsername(),
              let application = initialisePublicClientApplication(customAuthorityURLFormat: .tenantSubdomainTenantId)
        else {
            XCTFail("Missing information")
            return
        }

        let authenticationContextId = "c4"
        let authenticationContextRequestClaimJson = "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"\(authenticationContextId)\"}}}"
        let authenticationContextATClaimJson = "\"acrs\":[\"\(authenticationContextId)"

        let mfaRequiredExp = expectation(description: "MFA required")
        let delegate = SignInWithMFAV2DelegateSpy(expectation: mfaRequiredExp)

        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.password = password
        parameters.claimsRequest = MSALClaimsRequest(
            jsonString: authenticationContextRequestClaimJson,
            error: nil
        )
        parameters.correlationId = correlationId
        application.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [mfaRequiredExp])

        guard delegate.onMFARequiredCalled,
              let mfaRequiredState = delegate.mfaRequiredState
        else {
            XCTFail("onMFARequired not called")
            return
        }

        XCTAssertEqual(delegate.scenario, .signIn)

        guard let verificationRequiredState = try await selectEmailAuthMethod(
            state: mfaRequiredState,
            delegate: delegate
        ) else {
            return
        }

        guard let result = try await completeSignInWithMFAFlow(
            state: verificationRequiredState,
            username: username,
            delegate: delegate
        ) else {
            return
        }

        let getAccessTokenExp = expectation(description: "get access token")
        let credentialsDelegate = CredentialsDelegateSpy(expectation: getAccessTokenExp)
        result.getAccessToken(
            parameters: MSALNativeAuthGetAccessTokenParameters(),
            delegate: credentialsDelegate
        )

        await fulfillment(of: [getAccessTokenExp])

        XCTAssertTrue(credentialsDelegate.onAccessTokenRetrieveCompletedCalled)

        guard let accessToken = credentialsDelegate.result?.accessToken,
              let accessTokenBody = accessTokenBody(accessToken)
        else {
            XCTFail("Invalid access token received")
            return
        }

        XCTAssertTrue(accessTokenBody.contains(authenticationContextATClaimJson))
    }

    @MainActor
    private func signInUsingPassword(
        application: MSALNativeAuthPublicClientApplication,
        username: String,
        password: String,
        delegate: SignInWithMFAV2DelegateSpy,
        expectation: XCTestExpectation
    ) async -> MSALNativeAuthMFARequiredState? {
        let parameters = MSALNativeAuthSignInParameters(username: username)
        parameters.password = password
        parameters.correlationId = correlationId
        application.signInV2(parameters: parameters, delegate: delegate)

        await fulfillment(of: [expectation])

        guard delegate.onMFARequiredCalled,
              let mfaRequiredState = delegate.mfaRequiredState
        else {
            XCTFail("onMFARequired not called")
            return nil
        }

        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertFalse(mfaRequiredState.authMethods.isEmpty)

        return mfaRequiredState
    }

    @MainActor
    private func selectEmailAuthMethod(
        state: MSALNativeAuthMFARequiredState,
        delegate: SignInWithMFAV2DelegateSpy
    ) async throws -> MSALNativeAuthMFAVerificationRequiredState? {
        guard let emailAuthMethod = state.authMethods.first(where: { $0.channelTargetType.isEmailType }) else {
            XCTFail("No email auth method found")
            return nil
        }

        let verificationRequiredExp = expectation(description: "MFA verification required")
        delegate.reset(expectation: verificationRequiredExp)

        markEmailCheckpoint()
        state.selectAuthMethod(emailAuthMethod, delegate: delegate)

        await fulfillment(of: [verificationRequiredExp])
        try skipIfEmailOTPThrottled(delegate.error)

        guard delegate.onMFAVerificationRequiredCalled,
              let verificationRequiredState = delegate.mfaVerificationRequiredState
        else {
            XCTFail("onMFAVerificationRequired not called")
            return nil
        }

        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertEqual(verificationRequiredState.channel.isEmailType, true)
        XCTAssertFalse(verificationRequiredState.sentTo.isEmpty)
        XCTAssertGreaterThan(verificationRequiredState.codeLength, 0)

        return verificationRequiredState
    }

    @MainActor
    @discardableResult
    private func completeSignInWithMFAFlow(
        state: MSALNativeAuthMFAVerificationRequiredState,
        username: String,
        delegate: SignInWithMFAV2DelegateSpy
    ) async throws -> MSALNativeAuthUserAccountResult? {
        guard let code = await retrieveCodeFor(email: username) else {
            XCTFail("OTP code could not be retrieved")
            return nil
        }

        let flowCompletedExp = expectation(description: "sign in flow completed")
        delegate.reset(expectation: flowCompletedExp)
        state.submitChallenge(code, delegate: delegate)

        await fulfillment(of: [flowCompletedExp])
        try skipIfEmailOTPThrottled(delegate.error)

        XCTAssertTrue(delegate.onFlowCompletedCalled)
        XCTAssertEqual(delegate.scenario, .signIn)
        XCTAssertNotNil(delegate.result?.idToken)
//        XCTAssertEqual(delegate.result?.account.username, username) // TODO: preferred_username is wrong in v2 id token

        return delegate.result
    }

    private func accessTokenBody(_ accessToken: String) -> String? {
        let parts = accessToken.components(separatedBy: ".")
        guard parts.count == 3 else {
            return nil
        }

        var body = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = (4 - body.count % 4) % 4
        body.append(String(repeating: "=", count: paddingLength))

        guard let data = Data(base64Encoded: body) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

@MainActor
private final class SignInWithMFAV2DelegateSpy: NSObject,
    MSALNativeAuthMFARequiredDelegate,
    MSALNativeAuthMFAVerificationRequiredDelegate {

    private var expectation: XCTestExpectation

    private(set) var onMFARequiredCalled = false
    private(set) var onMFAVerificationRequiredCalled = false
    private(set) var onFlowCompletedCalled = false
    private(set) var onFlowErrorCalled = false

    private(set) var mfaRequiredState: MSALNativeAuthMFARequiredState?
    private(set) var mfaVerificationRequiredState: MSALNativeAuthMFAVerificationRequiredState?
    private(set) var result: MSALNativeAuthUserAccountResult?
    private(set) var error: MSALNativeAuthFlowError?
    private(set) var scenario: MSALNativeAuthFlowScenario?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
        super.init()
    }

    func reset(expectation: XCTestExpectation) {
        self.expectation = expectation
        onMFARequiredCalled = false
        onMFAVerificationRequiredCalled = false
        onFlowCompletedCalled = false
        onFlowErrorCalled = false
        mfaRequiredState = nil
        mfaVerificationRequiredState = nil
        result = nil
        error = nil
        scenario = nil
    }

    func onMFARequired(state: MSALNativeAuthMFARequiredState, scenario: MSALNativeAuthFlowScenario) {
        onMFARequiredCalled = true
        mfaRequiredState = state
        self.scenario = scenario

        expectation.fulfill()
    }

    func onMFAVerificationRequired(
        state: MSALNativeAuthMFAVerificationRequiredState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        onMFAVerificationRequiredCalled = true
        mfaVerificationRequiredState = state
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
