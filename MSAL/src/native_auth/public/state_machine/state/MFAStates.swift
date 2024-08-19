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

///  An object of this type is created whenever a user needs to make a specific request to send the MFA challenge.
@objcMembers
public class AwaitingMFAState: MSALNativeAuthBaseState {

    /// Requests the server to send the challenge to the default authentication method.
    /// - Parameter delegate: Delegate that receives callbacks for the operation.
    public func sendChallenge(delegate: MFASendChallengeDelegate) {
        // TODO: remove this dummy logic once business logic will be available
        DispatchQueue.main.async {
            delegate.onMFASendChallengeVerificationRequired?(newState: 
                                                                MFARequiredState(
                                                                    continuationToken: "CT",
                                                                    correlationId: UUID()
                                                                ),
                                                             sentTo: "co****@***.com",
                                                             channelTargetType: MSALNativeAuthChannelType(value: "email"),
                                                             codeLength: 8
            )
        }
    }
}

@objcMembers
public class MFARequiredState: MSALNativeAuthBaseState {

    /// Requests the server to send the challenge to the specified auth method or the default one.
    /// - Parameters:
    ///   - authMethod: Optional. The authentication method you want to use for sending the challenge
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func sendChallenge(authMethod: MSALAuthMethod? = nil, delegate: MFASendChallengeDelegate) {
        // TODO: remove this dummy logic once business logic will be available
        DispatchQueue.main.async {
            let state = MFARequiredState(continuationToken: "CT", correlationId: UUID())
            delegate.onMFASendChallengeVerificationRequired?(newState: state, sentTo: "co****@***.com", channelTargetType: MSALNativeAuthChannelType(value: "email"), codeLength: 8)
        }
    }

    /// Requests the available MFA authentication methods.
    /// - Parameter delegate: Delegate that receives callbacks for the operation.
    public func getAuthMethods(delegate: MFAGetAuthMethodsDelegate) {
        // TODO: remove this dummy logic once business logic will be available
        DispatchQueue.main.async {
            let authMethod = MSALAuthMethod(id: "1", challengeType: "oob", loginHint: "co****@***.com", channelTargetType: MSALNativeAuthChannelType(value: "email"))
            let state = MFARequiredState(continuationToken: "CT", correlationId: UUID())
            delegate.onMFAGetAuthMethodsSelectionRequired?(authMethods: [authMethod], newState: state)
        }
    }

    /// Submits the MFA challenge to the server for verification.
    /// - Parameters:
    ///   - challenge: Verification challenge that the user supplies.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitChallenge(challenge: String, delegate: MFASubmitChallengeDelegate) {
        // TODO: remove this dummy logic once business logic will be available
        DispatchQueue.main.async {
            delegate.onMFASubmitChallengeError(error: MFASubmitChallengeError(type: .invalidChallenge, correlationId: UUID()), newState: nil)
        }
    }
}
