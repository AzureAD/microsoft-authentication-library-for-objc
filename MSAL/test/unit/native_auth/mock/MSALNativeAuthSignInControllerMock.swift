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

@testable import MSAL
import XCTest

class MSALNativeAuthSignInControllerMock: MSALNativeAuthSignInControlling, MSALNativeAuthMFAControlling {

    private(set) var username: String?
    private(set) var continuationToken: String?
    private(set) var telemetryId: MSALNativeAuthTelemetryApiId?
    private(set) var claimsRequestJson: String?
    var expectation: XCTestExpectation?

    var signInStartResult: MSALNativeAuthSignInControlling.SignInControllerResponse!
    var continuationTokenResult: SignInAfterPreviousFlowControllerResponse!
    var submitCodeResult: SignInSubmitCodeControllerResponse!
    var submitPasswordResult: SignInSubmitPasswordControllerResponse!
    var resendCodeResult: SignInResendCodeControllerResponse!

    var requestChallengeResponse: MFARequestChallengeControllerResponse!
    var getAuthMethodsResponse: MFAGetAuthMethodsControllerResponse!
    var submitChallengeResponse: MFASubmitChallengeControllerResponse!

    func signIn(params: MSAL.MSALNativeAuthInternalSignInParameters) async -> MSALNativeAuthSignInControlling.SignInControllerResponse {
        return signInStartResult
    }

    func signIn(
        username: String,
        continuationToken: String?,
        scopes: [String]?,
        claimsRequestJson: String?,
        telemetryId: MSAL.MSALNativeAuthTelemetryApiId,
        context: MSAL.MSALNativeAuthRequestContext
    ) async -> SignInAfterPreviousFlowControllerResponse {
        self.username = username
        self.continuationToken = continuationToken
        self.telemetryId = telemetryId
        self.claimsRequestJson = claimsRequestJson
        expectation?.fulfill()

        return continuationTokenResult
    }

    func submitCode(_ code: String, continuationToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String], claimsRequestJson: String?) async -> SignInSubmitCodeControllerResponse {
        return submitCodeResult
    }

    func submitPassword(_ password: String, username: String, continuationToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String], claimsRequestJson: String?) async -> SignInSubmitPasswordControllerResponse {
        return submitPasswordResult
    }

    func resendCode(continuationToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String], claimsRequestJson: String?) async -> SignInResendCodeControllerResponse {
        return resendCodeResult
    }
    
    func requestChallenge(continuationToken: String, authMethod: MSAL.MSALAuthMethod?, context: MSAL.MSALNativeAuthRequestContext, scopes: [String], claimsRequestJson: String?) async -> MFARequestChallengeControllerResponse {
        return requestChallengeResponse
    }
    
    func getAuthMethods(continuationToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String], claimsRequestJson: String?) async -> MFAGetAuthMethodsControllerResponse {
        return getAuthMethodsResponse
    }
    
    func submitChallenge(challenge: String, continuationToken: String, context: MSAL.MSALNativeAuthRequestContext, scopes: [String], claimsRequestJson: String?) async -> MFASubmitChallengeControllerResponse {
        return submitChallengeResponse
    }
}
