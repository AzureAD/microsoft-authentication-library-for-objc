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

enum MockAPIError: Error {
    case invalidServerResponse
    case invalidURL
    case invalidRequest
}

enum MockAPIEndpoint: String {
    case signInInitiate = "SignInInitiate"
    case signInChallenge = "SignInChallenge"
    case signInToken = "SignInToken"
    case signUpStart = "SignUpStart"
    case signUpChallenge = "SignUpChallenge"
    case signUpContinue = "SignUpContinue"
    case resetPasswordStart = "SSPRStart"
    case resetPasswordChallenge = "SSPRChallenge"
    case resetPasswordContinue = "SSPRContinue"
    case resetPasswordSubmit = "SSPRSubmit"
    case resetPasswordPollCompletion = "SSPRPoll"
}

enum MockAPIResponse: String {
    case invalidRequest = "InvalidRequest"
    case invalidToken = "InvalidToken"
    case invalidClient = "InvalidClient"
    case invalidGrant = "InvalidGrant"
    case invalidScope = "InvalidScope"
    case expiredToken = "ExpiredToken"
    case invalidPurposeToken = "InvalidPurposeToken"
    case unsupportedAuthMethod = "UnsupportedAuthMethod"
    case userAlreadyExists = "UserAlreadyExists"
    case userNotFound = "UserNotFound"
    case explicityUserNotFound = "ExplicityUserNotFound"
    case slowDown = "SlowDown"
    case invalidPassword = "InvalidPassword"
    case invalidOOBValue = "InvalidOOBValue"
    case passwordTooWeak = "PasswordTooWeak"
    case passwordTooShort = "PasswordTooShort"
    case passwordTooLong = "PasswordTooLong"
    case passwordRecentlyUsed = "PasswordRecentlyUsed"
    case passwordBanned = "PasswordBanned"
    case authorizationPending = "AuthorizationPending"
    case challengeTypePassword = "ChallengeTypePassword"
    case challengeTypeOOB = "ChallengeTypeOOB"
    case unsupportedChallengeType = "UnsupportedChallengeType"
    case challengeTypeRedirect = "ChallengeTypeRedirect"
    case credentialRequired = "CredentialRequired"
    case initiateSuccess = "InitiateSuccess"
    case tokenSuccess = "TokenSuccess"
    case attributesRequired = "AttributesRequired"
    case invalidAttributes = "InvalidAttributes"
    case verificationRequired = "VerificationRequired"
    case attributeValidationFailed = "AttributeValidationFailed"
    case invalidSignUpToken = "InvalidSignupToken"
    case explicitInvalidOOBValue = "ExplicitInvalidOOBValue"
    case invalidPasswordResetToken = "InvalidPasswordResetToken"
    case ssprStartSuccess = "SSPRStartSuccess"
    case ssprContinueSuccess = "SSPRContinueSuccess"
    case ssprSubmitSuccess = "SSPRSubmitSuccess"
    case ssprPollSuccess = "SSPRPollSuccess"
    case ssprPollInProgress = "SSPRPollInProgress"
    case ssprPollFailed = "SSPRPollFailed"
    case ssprPollNotStarted = "SSPRPollNotStarted"
    case signUpContinueSuccess = "SignUpContinueSuccess"
    case invalidUsername = "InvalidUsername"
}

// MARK: request body

struct ClearQueueRequestBody: Encodable {
    var correlationId: UUID
}

struct AddResponsesRequestBody: Encodable {
    var endpoint: String
    var responseList: [String]
    var correlationId: UUID
}
