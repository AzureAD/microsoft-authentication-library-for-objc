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
    case success(continuationToken: String)
    case attributeValidationFailed(error: MSALNativeAuthSignUpStartResponseError, invalidAttributes: [String])
    case redirect
    case error(MSALNativeAuthSignUpStartResponseError)
    // TODO: Special errors handled separately. Remove after refactor validated error handling
    case invalidUsername(MSALNativeAuthSignUpStartResponseError)
    case unauthorizedClient(MSALNativeAuthSignUpStartResponseError)
    case unexpectedError(MSALNativeAuthSignUpStartResponseError?)
}

enum MSALNativeAuthSignUpChallengeValidatedResponse: Equatable {
    case codeRequired(_ sentTo: String, _ channelType: MSALNativeAuthChannelType, _ codeLength: Int, _ signUpChallengeToken: String)
    case passwordRequired(_ signUpChallengeToken: String)
    case redirect
    case error(MSALNativeAuthSignUpChallengeResponseError)
    case unexpectedError(MSALNativeAuthSignUpChallengeResponseError?)
}

enum MSALNativeAuthSignUpContinueValidatedResponse: Equatable {
    case success(continuationToken: String?)
    /// error that represents invalidOOB or invalidPassword, depending on which State the input comes from.
    case invalidUserInput(_ error: MSALNativeAuthSignUpContinueResponseError)
    case credentialRequired(continuationToken: String, error: MSALNativeAuthSignUpContinueResponseError)
    case attributesRequired(
        continuationToken: String,
        requiredAttributes: [MSALNativeAuthRequiredAttribute],
        error: MSALNativeAuthSignUpContinueResponseError
    )
    case attributeValidationFailed(error: MSALNativeAuthSignUpContinueResponseError, invalidAttributes: [String])
    case error(MSALNativeAuthSignUpContinueResponseError)
    case unexpectedError(MSALNativeAuthSignUpContinueResponseError?)
}
