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
@_implementationOnly import MSAL_Private

/// We're extending the MSID token response class only because native auth token response can return redirect
/// This class does not implement MSALNativeAuthBaseSuccessResponse because we parse the token response differently than other responses.
class MSALNativeAuthCIAMTokenResponse: MSIDCIAMTokenResponse {

    var redirectReason: String?
    var challengeType: MSALNativeAuthInternalChallengeType?

    private let redirectReasonKey = "redirect_reason"
    private let challengeTypeKey = "challenge_type"

    required init(jsonDictionary json: [AnyHashable: Any]) throws {
        try super.init(jsonDictionary: json)
        redirectReason = json[redirectReasonKey] as? String
        challengeType = MSALNativeAuthInternalChallengeType(rawValue: json[challengeTypeKey] as? String ?? "")
    }

    // empty init override needed to simplify testing
    override init() {
        super.init()
    }

}
