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

}
