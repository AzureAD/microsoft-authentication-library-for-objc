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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

enum MSALNativeAuthSignUpStartValidatedResponse: Equatable {
    case verificationRequired(signUpToken: String)
    case redirect
    case error(MSALNativeAuthSignUpStartOauth2ErrorCode)
    case unexpectedError
}

enum MSALNativeAuthSignUpChallengeValidatedResponse: Equatable {
    case successOOB(_ sentTo: String, _ channelType: MSALNativeAuthChannelType, _ codeLength: Int, _ signUpChallengeToken: String)
    case successPassword(_ signUpChallengeToken: String)
    case redirect
    case error(MSALNativeAuthSignUpChallengeOauth2ErrorCode)
    case unexpectedError
}

enum MSALNativeAuthSignUpContinueValidatedResponse: Equatable {
    case success(_ signInSLT: String)
    /// error that represents invalidOOB, invalidPassword and invalidAttributes, depending on which State the input comes from
    case invalidUserInput(_ error: MSALNativeAuthSignUpContinueOauth2ErrorCode, _ signUpToken: String)
    case credentialRequired(_ signUpToken: String)
    case attributesRequired(_ signUpToken: String)
    case error(MSALNativeAuthSignUpContinueOauth2ErrorCode)
    case unexpectedError
}
