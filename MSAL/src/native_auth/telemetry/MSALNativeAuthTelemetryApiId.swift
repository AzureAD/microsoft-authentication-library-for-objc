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

enum MSALNativeAuthTelemetryApiId: Int {
    // TODO: Resolve the below comment about the correct definitions of these constants:
    // Until we know exactly how to define them,
    // to prevent any clashes with existing id's
    // a number that is unlikely to be used has been added
    case telemetryApiIdSignUp = 75001
    case telemetryApiIdToken = 75002
    case telemetryApiIdRefreshToken = 75003
    case telemetryApiIdResendCode = 75006
    case telemetryApiIdVerifyCode = 75007
    case telemetryApiIdSignOut = 75008
    case telemetryApiIdResetPassword = 75009
    case telemetryApiIdSignInWithPasswordStart = 74001
    case telemetryApiIdSignInWithCodeStart = 74002
    case telemetryApiIdSignInAfterSignUp = 740014
    case telemetryApiIdSignInAfterPasswordReset = 740015
    case telemetryApiIdSignInSubmitCode = 74003
    case telemetryApiIdSignInResendCode = 74004
    case telemetryApiIdSignInSubmitPassword = 74005
    case telemetryApiIdResetPasswordStart = 74011
    case telemetryApiIdResetPasswordResendCode = 74012
    case telemetryApiIdResetPasswordSubmitCode = 74013
    case telemetryApiIdResetPasswordSubmit = 75028
    case telemetryApiIdSignUpPasswordStart = 75019
    case telemetryApiIdSignUpPasswordChallenge = 75015
    case telemetryApiIdSignUpCodeStart = 75010
    case telemetryApiIdSignUpResendCode = 75011
    case telemetryApiIdSignUpSubmitCode = 75012
    case telemetryApiIdSignUpSubmitPassword = 75013
    case telemetryApiIdSignUpSubmitAttributes = 75014
    case telemetryApiIdMFARequestChallenge = 75016
    case telemetryApiIdMFAGetAuthMethods = 75017
    case telemetryApiIdMFASubmitChallenge = 75018
    case telemetryApiIdJITIntrospect = 75029
    case telemetryApiIdJITChallenge = 75030
    case telemetryApiIdJITContinue = 75031
    case telemetryApiISignInAfterJIT = 75032
    // Native Auth V2 (server-driven HAL) network requests.
    case telemetryApiIdV2AuthorizeChallenge = 76001
    case telemetryApiIdV2Token = 76002
    case telemetryApiIdV2SignIn = 76003
    case telemetryApiIdV2SignUp = 76004
    case telemetryApiIdV2ResetPassword = 76005
    case telemetryApiIdV2Hal = 76006
    // Native Auth V2 (server-driven HAL) controller operations.
    case telemetryApiIdV2SignUpStart = 76007
    case telemetryApiIdV2SignInWithPasswordStart = 76008
    case telemetryApiIdV2SignInWithCodeStart = 76009
    case telemetryApiIdV2ResetPasswordStart = 76010
    case telemetryApiIdV2SignUpSubmitCode = 76011
    case telemetryApiIdV2SignInSubmitCode = 76012
    case telemetryApiIdV2ResetPasswordSubmitCode = 76013
    case telemetryApiIdV2SignInSubmitPassword = 76014
    case telemetryApiIdV2ResetPasswordSubmit = 76015
    case telemetryApiIdV2SignUpSubmitAttributes = 76016
    case telemetryApiIdV2JITChallenge = 76017
    case telemetryApiIdV2MFAGetAuthMethods = 76018
    case telemetryApiIdV2MFASubmitChallenge = 76019
    case telemetryApiIdV2ResetPasswordResendCode = 76020
}
