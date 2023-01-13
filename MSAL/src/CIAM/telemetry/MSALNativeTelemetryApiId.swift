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

enum MSALNativeTelemetryApiId: Int {
    // TODO: Untill we know exactly how to define them,
    // to prevent any clashes with existing id's
    // I've added a number that is unlikely to be used
    case MSALNativeTelemetrySignUp = 75001
    case MSALNativeTelemetrySignIn = 75002
    case MSALNativeTelemetryRefreshToken = 75003
    case MSALNativeTelemetryResetPasswordStart = 75004
    case MSALNativeTelemetryResetPasswordComplete = 75005
    case MSALNativeTelemetryResendCode = 75006
    case MSALNativeTelemetryVerifyCode = 75007
    case MSALNativeTelemetrySignOut = 75008
}
