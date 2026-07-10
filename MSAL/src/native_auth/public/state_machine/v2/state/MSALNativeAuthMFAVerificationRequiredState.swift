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

/// The server sent an MFA challenge; the user must enter the verification code.
/// Continue with ``submitChallenge(_:delegate:)``.
@objcMembers
public class MSALNativeAuthMFAVerificationRequiredState: MSALNativeAuthState {

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

    /// Submit the MFA challenge response.
    public func submitChallenge(_ challenge: String, delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitChallenge(challenge, continuation: continuation!)
        }
    }

    public override var description: String {
        return "mfaVerificationRequired (sentTo: \(sentTo), length: \(codeLength))"
    }
}
