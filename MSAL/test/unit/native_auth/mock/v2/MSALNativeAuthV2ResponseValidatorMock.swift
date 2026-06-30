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
@testable import MSAL

class MSALNativeAuthV2ResponseValidatorMock: MSALNativeAuthV2ResponseValidating {

    var authorizeChallengeResponses: [MSALNativeAuthV2AuthorizeChallengeValidatedResponse] = []
    var interactionResponses: [MSALNativeAuthV2InteractionValidatedResponse] = []
    var tokenResponse: MSALNativeAuthV2TokenValidatedResponse = .error(MSALNativeAuthFlowError(kind: .generalError))

    private(set) var validateAuthorizeChallengeCallCount = 0
    private(set) var validateInteractionCallCount = 0
    private(set) var validateTokenCallCount = 0

    func validateAuthorizeChallenge(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2AuthorizeChallengeValidatedResponse {
        defer { validateAuthorizeChallengeCallCount += 1 }
        if validateAuthorizeChallengeCallCount < authorizeChallengeResponses.count {
            return authorizeChallengeResponses[validateAuthorizeChallengeCallCount]
        }
        return .error(MSALNativeAuthFlowError(kind: .generalError))
    }

    func validateInteraction(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2InteractionValidatedResponse {
        defer { validateInteractionCallCount += 1 }
        if validateInteractionCallCount < interactionResponses.count {
            return interactionResponses[validateInteractionCallCount]
        }
        return .error(MSALNativeAuthFlowError(kind: .generalError))
    }

    func validateToken(_ result: Result<MSALNativeAuthHALResponse, Error>) -> MSALNativeAuthV2TokenValidatedResponse {
        validateTokenCallCount += 1
        return tokenResponse
    }
}
