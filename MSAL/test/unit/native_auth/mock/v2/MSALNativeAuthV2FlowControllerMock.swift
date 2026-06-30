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

class MSALNativeAuthV2FlowControllerMock: MSALNativeAuthV2FlowControlling {

    var correlationId = UUID()
    var resetPasswordResponse: MSALNativeAuthV2FlowControllerResponse?
    var signUpResponse: MSALNativeAuthV2FlowControllerResponse?
    var signInResponse: MSALNativeAuthV2FlowControllerResponse?
    var submitCodeResponse: MSALNativeAuthV2FlowControllerResponse?
    var submitPasswordResponse: MSALNativeAuthV2FlowControllerResponse?
    var submitNewPasswordResponse: MSALNativeAuthV2FlowControllerResponse?
    var submitAttributesResponse: MSALNativeAuthV2FlowControllerResponse?
    var selectAuthMethodResponse: MSALNativeAuthV2FlowControllerResponse?
    var submitChallengeResponse: MSALNativeAuthV2FlowControllerResponse?
    var resendCodeResponse: MSALNativeAuthV2FlowControllerResponse?

    private func notImplementedResponse() -> MSALNativeAuthV2FlowControllerResponse {
        return MSALNativeAuthV2FlowControllerResponse(
            .error(error: MSALNativeAuthFlowError(kind: .notImplemented), newState: nil),
            correlationId: correlationId
        )
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        return resetPasswordResponse ?? notImplementedResponse()
    }

    func signUp(parameters: MSALNativeAuthSignUpParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        return signUpResponse ?? notImplementedResponse()
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthV2FlowControllerResponse {
        return signInResponse ?? notImplementedResponse()
    }

    func submitCode(_ code: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return submitCodeResponse ?? notImplementedResponse()
    }

    func submitPassword(_ password: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return submitPasswordResponse ?? notImplementedResponse()
    }

    func submitNewPassword(_ password: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return submitNewPasswordResponse ?? notImplementedResponse()
    }

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return submitAttributesResponse ?? notImplementedResponse()
    }

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        state: MSALNativeAuthFlowState
    ) async -> MSALNativeAuthV2FlowControllerResponse {
        return selectAuthMethodResponse ?? notImplementedResponse()
    }

    func submitChallenge(_ challenge: String, state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return submitChallengeResponse ?? notImplementedResponse()
    }

    func resendCode(state: MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse {
        return resendCodeResponse ?? notImplementedResponse()
    }
}
