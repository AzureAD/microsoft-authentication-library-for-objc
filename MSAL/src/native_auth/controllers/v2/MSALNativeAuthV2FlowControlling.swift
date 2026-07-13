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

/// Drives the Native Auth V2 (server-driven, HAL) flows.
///
/// A single unified controller backs every V2 flow. Each method performs one step
/// (or, for entry methods, the initial sequence of steps that the server can complete
/// without app interaction) and returns a ``MSALNativeAuthV2FlowControllerResponse``.
protocol MSALNativeAuthV2FlowControlling {

    // MARK: - Entry points

    func resetPassword(parameters: MSALNativeAuthResetPasswordParametersV2) async -> MSALNativeAuthV2FlowControllerResponse

    func signUp(parameters: MSALNativeAuthSignUpParametersV2) async -> MSALNativeAuthV2FlowControllerResponse

    func signIn(parameters: MSALNativeAuthSignInParameters) async -> MSALNativeAuthV2FlowControllerResponse

    // MARK: - Continuation

    func submitCode(_ code: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse

    func submitPassword(_ password: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse

    func submitNewPassword(_ password: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse

    func submitAttributes(
        _ attributes: [String: Any],
        continuation: MSALNativeAuthV2ContinuationState
    ) async -> MSALNativeAuthV2FlowControllerResponse

    func selectAuthMethod(
        _ method: MSALAuthMethod,
        verificationContact: String?,
        continuation: MSALNativeAuthV2ContinuationState
    ) async -> MSALNativeAuthV2FlowControllerResponse

    func submitChallenge(_ challenge: String, continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse

    func resendCode(continuation: MSALNativeAuthV2ContinuationState) async -> MSALNativeAuthV2FlowControllerResponse
}
