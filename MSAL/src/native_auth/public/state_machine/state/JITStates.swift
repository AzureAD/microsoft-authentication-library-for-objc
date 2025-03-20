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

///  An object of this type is created whenever a user needs to register a new strong authentication method.
@objcMembers
public class RegisterStrongAuthState: MSALNativeAuthBaseState {

    /// Requests the server to send the challenge to the default authentication method.
    /// - Warning: ⚠️  this API is experimental. It may be changed in the future without notice. Do not use in production applications.
    /// - Parameters:
    ///  - parameters: Parameters used to challenge an authentication method
    ///  - delegate: Delegate that receives callbacks for the operation.
    func challengeAuthMethod(parameters: MSALNativeAuthChallengeAuthMethodParameters, delegate: RegisterStrongAuthChallengeDelegate) {
        let newState = RegisterStrongAuthVerificationRequiredState(continuationToken: "continuationToken", correlationId: UUID())
        let result = MSALNativeAuthRegisterStrongAuthVerificationRequiredResult(
            newState: newState,
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        Task {
            await delegate.onRegisterStrongAuthVerificationRequired?(result: result)
        }
    }
}

@objcMembers
public class RegisterStrongAuthVerificationRequiredState: MSALNativeAuthBaseState {

    /// Submits the challenge to verify the authentication method selected.
    /// - Warning: ⚠️  this API is experimental. It may be changed in the future without notice. Do not use in production applications.
    /// - Parameters:
    ///  - challenge: Verification challenge that the user supplies.
    ///  - delegate: Delegate that receives callbacks for the operation.
    func submitChallenge(challenge: String, delegate: RegisterStrongAuthSubmitChallengeDelegate) {
        delegate.onRegisterStrongAuthSubmitChallengeError(error: RegisterStrongAuthSubmitChallengeError(type: .invalidChallenge, correlationId: UUID()), newState: nil)
    }

    /// Requests the server to send the challenge to the default authentication method.
    /// - Warning: ⚠️  this API is experimental. It may be changed in the future without notice. Do not use in production applications.
    /// - Parameters:
    ///  - parameters: Parameters used to challenge an authentication method
    ///  - delegate: Delegate that receives callbacks for the operation.
    func challengeAuthMethod(parameters: MSALNativeAuthChallengeAuthMethodParameters, delegate: RegisterStrongAuthChallengeDelegate) {
        let newState = RegisterStrongAuthVerificationRequiredState(continuationToken: "continuationToken", correlationId: UUID())
        let result = MSALNativeAuthRegisterStrongAuthVerificationRequiredResult(
            newState: newState,
            sentTo: "sentTo",
            channelTargetType: MSALNativeAuthChannelType(value: "email"),
            codeLength: 8
        )
        Task {
            await delegate.onRegisterStrongAuthVerificationRequired?(result: result)
        }
    }
}
