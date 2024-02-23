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

protocol MSALNativeAuthSignInControlling {

    typealias SignInControllerResponse = MSALNativeAuthControllerTelemetryWrapper<SignInStartResult>
    typealias SignInAfterPreviousFlowControllerResponse =
        MSALNativeAuthControllerTelemetryWrapper<Result<MSALNativeAuthUserAccountResult, MSALNativeAuthError>>
    typealias SignInSubmitCodeControllerResponse = MSALNativeAuthControllerTelemetryWrapper<SignInVerifyCodeResult>
    typealias SignInSubmitPasswordControllerResponse = MSALNativeAuthControllerTelemetryWrapper<SignInPasswordRequiredResult>
    typealias SignInResendCodeControllerResponse = MSALNativeAuthControllerTelemetryWrapper<SignInResendCodeResult>

    func signIn(params: MSALNativeAuthSignInParameters) async -> SignInControllerResponse

    func signIn(
        username: String,
        continuationToken: String?,
        scopes: [String]?,
        context: MSALNativeAuthRequestContext
    ) async -> SignInAfterPreviousFlowControllerResponse

    func submitCode(
        _ code: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInSubmitCodeControllerResponse

    func submitPassword(
        _ password: String,
        username: String,
        continuationToken: String,
        context: MSALNativeAuthRequestContext,
        scopes: [String]
    ) async -> SignInSubmitPasswordControllerResponse

    func resendCode(continuationToken: String, context: MSALNativeAuthRequestContext, scopes: [String]) async -> SignInResendCodeControllerResponse
}
