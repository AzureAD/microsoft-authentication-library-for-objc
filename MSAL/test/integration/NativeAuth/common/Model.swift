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
    case SignInInitiate
    case SignInChallenge
    case SignInToken
    case SignUpStart
    case SignUpChallenge
    case SignUpContinue
    case SSPRStart
    case SSPRChallenge
    case SSPRContinue
    case SSPRSubmit
    case SSPRPoll
}

enum MockAPIResponse: String {
    case InvalidRequest
    case InvalidToken
    case InvalidClient
    case InvalidGrant
    case InvalidScope
    case ExpiredToken
    case InvalidPurposeToken
    case AuthNotSupported
    case UserAlreadyExists
    case UserNotFound
    case SlowDown
    case InvalidPassword
    case InvalidOOBValue
    case PasswordTooWeak
    case PasswordTooShort
    case PasswordTooLong
    case PasswordRecentlyUsed
    case PasswordBanned
    case AuthorizationPending
    case ChallengeTypePassword
    case ChallengeTypeOOB
    case UnsupportedChallengeType
    case ChallengeTypeRedirect
    case CredentialRequired
    case InitiateSuccess
    case TokenSuccess
    case AttributesRequired
    case VerificationRequired
    case ValidationFailed
    case SSPRStartSuccess
    case SSPRContinueSuccess
    case SSPRSubmitSuccess
    case SSPRPollSuccess
    case SSPRPollInProgress
    case SSPRPollFailed
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
