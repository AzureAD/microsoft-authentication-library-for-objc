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

/// Identifies which V2 flow a ``MSALNativeAuthFlowInternalState`` belongs to.
extension MSALNativeAuthFlowScenario {

    /// The server-driven flows the SDK follows when resolving `authorize-challenge` links.
    static let authorizeChallengeFlows: [MSALNativeAuthFlowScenario] = [.signUp, .signIn, .passwordReset, .unknown]

    /// The `authorize-challenge` link relation this flow follows.
    var link: String {
        switch self {
        case .signUp:
            return "sign_up"
        case .signIn:
            return "sign_in"
        case .passwordReset:
            return "reset_password"
        case .unknown:
            return "unknown"
        }
    }
}

/// Result produced by the unified V2 controller for a single step of a flow.
enum MSALNativeAuthFlowResult {
    case actionRequired(action: MSALNativeAuthAction, newState: MSALNativeAuthFlowInternalState)
    case completed(MSALNativeAuthUserAccountResult)
    case error(error: MSALNativeAuthFlowError, newState: MSALNativeAuthFlowInternalState?)
    case browserRequired(url: URL, newState: MSALNativeAuthFlowInternalState)
}
