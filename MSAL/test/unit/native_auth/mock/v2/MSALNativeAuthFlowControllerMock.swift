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
    var submitAttributesResponse: MSALNativeAuthFlowControllerResponse?
    var selectAuthMethodResponse: MSALNativeAuthFlowControllerResponse?
    var submitChallengeResponse: MSALNativeAuthFlowControllerResponse?
    var resendCodeResponse: MSALNativeAuthFlowControllerResponse?

    private func notImplementedResponse() -> MSALNativeAuthFlowControllerResponse {
        return MSALNativeAuthFlowControllerResponse(
            .error(error: MSALNativeAuthFlowError(type: .notImplemented), newState: nil),
            correlationId: correlationId
        )
    }

    func resetPassword(parameters: MSALNativeAuthResetPasswordParameters) async -> MSALNativeAuthFlowControllerResponse {
        return resetPasswordResponse ?? notImplementedResponse()
    }

    func signUp(parameters: MSALNativeAuthSignUpParameters) async -> MSALNativeAuthFlowControllerResponse {
        return signUpResponse ?? notImplementedResponse()
    }

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthFlowControllerResponse {
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

    func submitAttributes(_ attributes: [String: Any], state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return submitAttributesResponse ?? notImplementedResponse()
    }

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        state: MSALNativeAuthFlowInternalState
    ) async -> MSALNativeAuthFlowControllerResponse {
        return selectAuthMethodResponse ?? notImplementedResponse()
    }

    func submitChallenge(_ challenge: String, state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return submitChallengeResponse ?? notImplementedResponse()
    }

    func resendCode(state: MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse {
        return resendCodeResponse ?? notImplementedResponse()
    }
}
