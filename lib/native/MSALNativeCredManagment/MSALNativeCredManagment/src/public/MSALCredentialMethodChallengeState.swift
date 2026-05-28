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

/// The channel type through which a challenge was sent.
@objc public enum MSALCredentialMethodChallengeChannel: Int {
    /// Challenge sent via email.
    case email = 0
    /// Challenge sent via SMS/phone.
    case phone = 1
    /// Challenge requires authenticator app.
    case authenticatorApp = 2
    /// Unknown or unspecified channel.
    case unknown = 99
}

/// Represents the state of a credential method registration that requires challenge verification.
///
/// When registering a new credential method, the server may require the user to verify ownership
/// (e.g., enter an OTP sent to the new email/phone). This state object provides the context
/// and methods to complete or resend the challenge.
@objcMembers
public class MSALCredentialMethodChallengeState: NSObject {

    /// The channel through which the challenge was sent.
    public let challengeChannel: MSALCredentialMethodChallengeChannel

    /// A display hint for the challenge target (e.g., masked email or phone number).
    public let sentTo: String?

    /// The length of the expected code, if applicable.
    public let codeLength: Int

    internal let continuationToken: String
    internal weak var client: MSALNativeCredentialMethodsClient?

    internal init(
        challengeChannel: MSALCredentialMethodChallengeChannel,
        sentTo: String?,
        codeLength: Int,
        continuationToken: String,
        client: MSALNativeCredentialMethodsClient?
    )
    {
        self.challengeChannel = challengeChannel
        self.sentTo = sentTo
        self.codeLength = codeLength
        self.continuationToken = continuationToken
        self.client = client
        super.init()
    }

    /// Submit the challenge code to complete credential method registration.
    ///
    /// - Parameters:
    ///   - code: The verification code entered by the user.
    ///   - delegate: Receives the registration result or error.
    public func submitChallenge(
        code: String,
        delegate: MSALCredentialMethodRegisterDelegate
    )
    {
        guard let client = client else
        {
            let error = MSALNativeCredentialManagementError(
                type: .sessionExpired,
                message: "Client reference has been released. Please restart the registration flow."
            )
            DispatchQueue.main.async
            {
                delegate.onCredentialMethodRegistrationError(error: error)
            }
            return
        }
        client.submitRegistrationChallenge(
            code: code,
            continuationToken: continuationToken,
            delegate: delegate
        )
    }

    /// Request the server to resend the challenge code.
    ///
    /// - Parameter delegate: Receives a new challenge state or error.
    public func resendChallenge(
        delegate: MSALCredentialMethodRegisterDelegate
    )
    {
        guard let client = client else
        {
            let error = MSALNativeCredentialManagementError(
                type: .sessionExpired,
                message: "Client reference has been released. Please restart the registration flow."
            )
            DispatchQueue.main.async
            {
                delegate.onCredentialMethodRegistrationError(error: error)
            }
            return
        }
        client.resendRegistrationChallenge(
            continuationToken: continuationToken,
            delegate: delegate
        )
    }
}
