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

/// The result of a credential method registration attempt.
///
/// Registration may complete immediately or require a verification challenge (e.g., OOB code).
public enum MSALCredentialMethodRegistrationResult
{
    /// Registration completed successfully.
    case completed(any MSALCredentialMethodProtocol)

    /// A verification challenge is required to complete registration.
    /// Use the provided `MSALCredentialMethodChallengeState` to submit the code or resend.
    case challengeRequired(MSALCredentialMethodChallengeState)
}

/// Represents the state of a pending challenge during credential registration.
///
/// Use `submitChallenge(code:)` to verify or `resendChallenge()` to request a new code.
public class MSALCredentialMethodChallengeState
{
    /// The channel the code was sent to (e.g., email address or phone number hint).
    public let sentTo: String?

    /// The channel type (e.g., "email", "phone").
    public let channelType: String?

    /// The number of digits in the expected code.
    public let codeLength: Int?

    // MARK: - Internal

    private let continuationToken: String
    private weak var client: MSALNativeCredentialMethodsClient?
    private let correlationId: UUID

    internal init(
        sentTo: String?,
        channelType: String?,
        codeLength: Int?,
        continuationToken: String,
        client: MSALNativeCredentialMethodsClient,
        correlationId: UUID
    )
    {
        self.sentTo = sentTo
        self.channelType = channelType
        self.codeLength = codeLength
        self.continuationToken = continuationToken
        self.client = client
        self.correlationId = correlationId
    }

    /// Submit the verification code to complete registration.
    ///
    /// - Parameter code: The verification code received by the user.
    /// - Returns: A `Result` containing the registered credential method or an error.
    public func submitChallenge(code: String) async -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>
    {
        guard let client = client else
        {
            let error = MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Client was deallocated.",
                correlationId: correlationId
            )
            return .failure(error)
        }

        return await client.submitRegistrationChallenge(
            code: code,
            continuationToken: continuationToken,
            correlationId: correlationId
        )
    }

    /// Request a new verification code.
    ///
    /// - Returns: A new `MSALCredentialMethodChallengeState` with updated delivery info, or an error.
    public func resendChallenge() async -> Result<MSALCredentialMethodChallengeState, MSALNativeCredentialManagementError>
    {
        guard let client = client else
        {
            let error = MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Client was deallocated.",
                correlationId: correlationId
            )
            return .failure(error)
        }

        return await client.resendRegistrationChallenge(
            continuationToken: continuationToken,
            correlationId: correlationId
        )
    }
}
