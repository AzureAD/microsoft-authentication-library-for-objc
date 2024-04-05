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

// swiftlint:disable line_length
enum MSALNativeAuthErrorMessage {
    static let invalidScope = "Invalid scope"
    static let delegateNotImplemented = "MSALNativeAuth has called the delegate method %@ that has not been implemented"
    static let unsupportedMFA = "MFA currently not supported. Use the browser instead"
    static let browserRequired = "Browser required. Use acquireTokenInteractively instead"
    static let userDoesNotHavePassword = "User does not have password associated with account"
    static let userNotFound = "User does not exist"
    static let attributeValidationFailedSignUpStart = "Check the invalid attributes and start the sign-up process again. Invalid attributes: %@"
    static let attributeValidationFailed = "Invalid attributes: %@"
    static let signInNotAvailable = "Sign In is not available at this point, please use the standalone sign in methods"
    static let codeRequiredForPasswordUserLog = "This user does not have a password associated with their account. SDK will call `delegate.onSignInCodeRequired()` and the entered password will be ignored"
    static let userAlreadyExists = "User already exists"
    static let invalidPassword = "Invalid password"
    static let invalidCredentials = "Invalid credentials"
    static let invalidUsername = "Invalid username"
    static let generalError = "General error"
    static let invalidCode = "Invalid code"
    static let refreshTokenExpired = "Refresh token is expired"
    static let redirectUriNotSetWarning = "WARNING ⚠️: redirectUri not set during MSAL Native Auth initialization. Production apps must correctly configure a redirect URI and call acquireToken in response to all browserRequired errors. See https://learn.microsoft.com/entra/identity-platform/redirect-uris-ios"
    static let unexpectedResponseBody = "Unexpected response body received"
    static let unexpectedChallengeType = "Unexpected challenge type"
}

// swiftlint:enable line_length
