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

/// The server sent a JIT challenge; the user must enter the verification code.
/// Continue with ``submitChallenge(_:delegate:)``.
@objcMembers
public class MSALNativeAuthStrongAuthVerificationRequiredState: MSALNativeAuthState {

    /// A masked destination the code was sent to (e.g. a partially obfuscated email).
    public let sentTo: String

    /// The channel the code was sent through.
    public let channel: MSALNativeAuthChannelType

    /// The expected length of the code.
    public let codeLength: Int

    public init(sentTo: String, channel: MSALNativeAuthChannelType, codeLength: Int) {
        self.sentTo = sentTo
        self.channel = channel
        self.codeLength = codeLength
        super.init()
    }

    /// Submit the strong-auth (JIT) challenge response.
    public func submitChallenge(_ challenge: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitChallenge(challenge, continuation: continuation!)
        }
    }

    public override var description: String {
        return "strongAuthVerificationRequired (sentTo: \(sentTo), length: \(codeLength))"
    }
}

/// Per-state delegate for the ``MSALNativeAuthStrongAuthVerificationRequiredState`` step of a Native Auth V2 flow.
///
/// Conform to this protocol (in addition to the terminal callbacks inherited from
/// ``MSALNativeAuthFlowDelegate``) to handle this state. Conforming is opt-in per state, but the
/// callback is required once you conform.
@objc
public protocol MSALNativeAuthStrongAuthVerificationRequiredDelegate: MSALNativeAuthFlowDelegate {

    /// The server sent a JIT challenge; the user must enter the verification code.
    /// Continue with ``MSALNativeAuthStrongAuthVerificationRequiredState/submitChallenge(_:delegate:)``.
    /// - Parameters:
    ///   - state: The strong-auth verification state (destination, channel, expected length).
    ///   - scenario: The flow that produced this callback.
    /// - Note: If the app's delegate does not conform to this protocol, then
    ///   ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
    @MainActor func onStrongAuthVerificationRequired(state: MSALNativeAuthStrongAuthVerificationRequiredState, scenario: MSALNativeAuthFlowScenario)
}
