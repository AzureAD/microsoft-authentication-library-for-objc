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
@_implementationOnly import MSAL_Private

class MSALNativeAuthV2ResponseParserMock: MSALNativeAuthV2ResponseParsing {

    var authorizeChallengeResponses: [MSALNativeAuthV2AuthorizeChallengeParsedResponse] = []
    var interactionResponses: [MSALNativeAuthV2InteractionParsedResponse] = []
    var tokenResponses: [MSALNativeAuthV2TokenParsedResponse] = []

    private(set) var parseAuthorizeChallengeCallCount = 0
    private(set) var parseInteractionCallCount = 0
    private(set) var parseTokenCallCount = 0

    func parseAuthorizeChallenge(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>,
        flowScenario: MSALNativeAuthFlowScenario
    ) -> MSALNativeAuthV2AuthorizeChallengeParsedResponse {
        defer { parseAuthorizeChallengeCallCount += 1 }
        if parseAuthorizeChallengeCallCount < authorizeChallengeResponses.count {
            return authorizeChallengeResponses[parseAuthorizeChallengeCallCount]
        }
        return .error(MSALNativeAuthFlowError(type: .generalError))
    }

    func parseInteraction(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthHALResponse, Error>
    ) -> MSALNativeAuthV2InteractionParsedResponse {
        defer { parseInteractionCallCount += 1 }
        if parseInteractionCallCount < interactionResponses.count {
            return interactionResponses[parseInteractionCallCount]
        }
        return .error(MSALNativeAuthFlowError(type: .generalError))
    }

    func parseToken(
        context: MSIDRequestContext,
        _ result: Result<MSALNativeAuthCIAMTokenResponse, Error>
    ) -> MSALNativeAuthV2TokenParsedResponse {
        defer { parseTokenCallCount += 1 }
        if parseTokenCallCount < tokenResponses.count {
            return tokenResponses[parseTokenCallCount]
        }
        // Default: pass the real token-request outcome through, so happy-path tests need no setup.
        switch result {
        case .success(let tokenResponse):
            return .success(tokenResponse)
        case .failure(let error):
            return .error(MSALNativeAuthFlowError(type: .generalError, errorDescription: (error as NSError).localizedDescription))
        }
    }
}
