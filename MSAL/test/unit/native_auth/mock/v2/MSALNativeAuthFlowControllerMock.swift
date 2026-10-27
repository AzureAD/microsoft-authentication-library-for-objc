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
@testable import MSAL

class MSALNativeAuthFlowControllerMock: MSALNativeAuthFlowControlling {

    var correlationId = UUID()
    var resetPasswordResponse: MSALNativeAuthFlowControllerResponse?
    var signUpResponse: MSALNativeAuthFlowControllerResponse?
    var signInResponse: MSALNativeAuthFlowControllerResponse?
    var submitCodeResponse: MSALNativeAuthFlowControllerResponse?
    var submitPasswordResponse: MSALNativeAuthFlowControllerResponse?
    var submitNewPasswordResponse: MSALNativeAuthFlowControllerResponse?
    var signInAfterResetPasswordResponse: MSALNativeAuthFlowControllerResponse?
    var signInAfterSignUpResponse: MSALNativeAuthFlowControllerResponse?
    var submitAttributesResponse: MSALNativeAuthFlowControllerResponse?
    var selectAuthMethodResponse: MSALNativeAuthFlowControllerResponse?
    private(set) var selectedAuthMethod: MSALAuthMethod?
    private(set) var selectedAuthenticationFactor: MSALNativeAuthAuthenticationFactor?
    var enrollAuthMethodResponse: MSALNativeAuthFlowControllerResponse?
    private(set) var enrolledAuthMethod: MSALAuthMethod?
    private(set) var offeredEnrollmentMethods: [MSALNativeAuthV2EnrollmentMethod]?
    private(set) var selectedVerificationContact: String?
    private(set) var selectedAuthMethodState: MSALNativeAuthFlowInternalState?
    var submitMFAChallengeResponse: MSALNativeAuthFlowControllerResponse?
    private(set) var submittedMFAChallenge: String?
    private(set) var submittedMFAChallengeState: MSALNativeAuthFlowInternalState?
    var submitStrongAuthChallengeResponse: MSALNativeAuthFlowControllerResponse?
    private(set) var submittedStrongAuthChallenge: String?
    private(set) var submittedStrongAuthChallengeState: MSALNativeAuthFlowInternalState?
    var resendCodeResponse: MSALNativeAuthFlowControllerResponse?
    var resendChallengeResponse: MSALNativeAuthFlowControllerResponse?
    private(set) var resendChallengeCalled = false
    private(set) var resendChallengeChannel: MSALNativeAuthChannelType?
    private(set) var resendChallengePurpose: MSALNativeAuthChallengePurpose?
    private(set) var resendChallengeState: MSALNativeAuthFlowInternalState?

    private(set) var signUpCalled = false
    private(set) var signInCalled = false
    private(set) var resetPasswordCalled = false

    private func notImplementedResponse() -> MSALNativeAuthFlowControllerResponse {
        return MSALNativeAuthFlowControllerResponse(
            .error(error: MSALNativeAuthFlowError(type: .notImplemented)),
            correlationId: correlationId
        )
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParameters) async -> MSALNativeAuthFlowControllerResponse {
        resetPasswordCalled = true
        return resetPasswordResponse ?? notImplementedResponse()
    }

    func signUp(parameters: MSALNativeAuthSignUpParametersV2) async -> MSALNativeAuthFlowControllerResponse {
        signUpCalled = true
        return signUpResponse ?? notImplementedResponse()
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthFlowControllerResponse {
        signInCalled = true
        return signInResponse ?? notImplementedResponse()
    }

    func submitCode(_ code: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return submitCodeResponse ?? notImplementedResponse()
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return submitPasswordResponse ?? notImplementedResponse()
    }

    func submitNewPassword(_ password: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return submitNewPasswordResponse ?? notImplementedResponse()
    }

    func signInAfterResetPassword(
        scopes: [String]?,
        claimsRequestJson: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        return signInAfterResetPasswordResponse ?? notImplementedResponse()
    }

    func signInAfterSignUp(
        scopes: [String]?,
        claimsRequestJson: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        return signInAfterSignUpResponse ?? notImplementedResponse()
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return submitAttributesResponse ?? notImplementedResponse()
    }

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        authenticationFactor: MSALNativeAuthAuthenticationFactor,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        selectedAuthMethod = method
        selectedAuthenticationFactor = authenticationFactor
        selectedAuthMethodState = state
        return selectAuthMethodResponse ?? notImplementedResponse()
    }

    func enrollAuthMethod(
        _ method: MSALAuthMethod,
        offeredMethods: [MSALNativeAuthV2EnrollmentMethod],
        verificationContact: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        enrolledAuthMethod = method
        offeredEnrollmentMethods = offeredMethods
        selectedVerificationContact = verificationContact
        selectedAuthMethodState = state
        return enrollAuthMethodResponse ?? notImplementedResponse()
    }

    func submitMFAChallenge(_ challenge: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        submittedMFAChallenge = challenge
        submittedMFAChallengeState = state
        return submitMFAChallengeResponse ?? notImplementedResponse()
    }

    func submitStrongAuthChallenge(_ challenge: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        submittedStrongAuthChallenge = challenge
        submittedStrongAuthChallengeState = state
        return submitStrongAuthChallengeResponse ?? notImplementedResponse()
    }

    func resendCode(state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return resendCodeResponse ?? notImplementedResponse()
    }

    func resendChallenge(
        channelType: MSALNativeAuthChannelType,
        purpose: MSALNativeAuthChallengePurpose,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        resendChallengeCalled = true
        resendChallengeChannel = channelType
        resendChallengePurpose = purpose
        resendChallengeState = state
        return resendChallengeResponse ?? notImplementedResponse()
    }
}
