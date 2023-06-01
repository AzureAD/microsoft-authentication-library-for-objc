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

enum MSALNativeAuthErrorMessage {
    static let invalidClient = "Invalid Client ID"
    static let invalidScope = "Invalid scope"
    static let unsupportedChallengeType = "Unsupported challenge type"
    static let unsupportedAuthMethod = "Authentication method not supported"
    static let expiredToken = "Flow token has expired. Please start the flow again"
    static let passwordTooWeak = "Password too weak"
    static let passwordTooShort = "Password too short"
    static let passwordTooLong = "Password too long"
    static let passwordRecentlyUsed = "Password recently used"
    static let passwordBanned = "Password banned"
    static let delegateNotImplemented = "MSALNativeAuth has called an optional delegate method that has not been implemented"
    static let useSignInCode = "Use signInUsingCode instead"
    static let unsupportedMFA = "MFA currently not supported. Use the browser instead"
}
