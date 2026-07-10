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

/// The server requires the user to verify a one-time code.
/// Continue with ``submitCode(_:delegate:)`` or request a new code with ``resendCode(delegate:)``.
@objcMembers
public class MSALNativeAuthCodeRequiredState: MSALNativeAuthState {

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

    /// Submit a one-time verification code.
    public func submitCode(_ code: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitCode(code, continuation: continuation!)
        }
    }

    /// Request the server to resend the one-time code.
    public func resendCode(delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.resendCode(continuation: continuation!)
        }
    }

    public override var description: String {
        return "codeRequired (sentTo: \(sentTo), length: \(codeLength))"
    }
}

/// Per-state delegate for the ``MSALNativeAuthCodeRequiredState`` step of a Native Auth V2 flow.
///
/// Conform to this protocol (in addition to the terminal callbacks inherited from
/// ``MSALNativeAuthFlowDelegate``) to handle this state. Conforming is opt-in per state, but the
/// callback is required once you conform.
@objc
public protocol MSALNativeAuthCodeRequiredDelegate: MSALNativeAuthFlowDelegate {

    /// The server requires the user to verify a one-time code.
    /// Continue with ``MSALNativeAuthCodeRequiredState/submitCode(_:delegate:)`` (or request a new
    /// code with ``MSALNativeAuthCodeRequiredState/resendCode(delegate:)``).
    /// - Parameters:
    ///   - state: The code-required state (destination, channel, expected length) that
    ///     also exposes the continuation methods.
    ///   - scenario: The flow that produced this callback.
    /// - Note: If the app's delegate does not conform to this protocol, then
    ///   ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
    @MainActor func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario)
}
