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

/// HAL-free result of a `beginEnrollment` call.
///
/// Callers use this typed response instead of parsing raw HAL resources.
/// The HAL-specific link/resource context is managed internally by the server layer.
internal enum EnrollmentBeginResponse
{
    /// Enrollment completed in one step (e.g., password).
    case completed(any MSALCredentialMethodProtocol)

    /// A verification challenge was sent (e.g., OTP to phone).
    case challengeRequired(EnrollmentChallengeInfo)

    /// Server returned WebAuthn creation options for passkey registration.
    case passkeyCreationRequired(PasskeyCreationInfo)
}

/// Information about a verification challenge sent during enrollment.
internal struct EnrollmentChallengeInfo
{
    let sentTo: String?
    let channelType: String?
    let codeLength: Int?
    let continuationToken: String
}

/// Information needed to invoke the platform authenticator for passkey creation.
internal struct PasskeyCreationInfo
{
    let publicKey: [String: Any]
    let continuationToken: String
}
