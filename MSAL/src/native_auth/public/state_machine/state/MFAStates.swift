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

/// Base class for MFA state
@objcMembers public class MFABaseState: MSALNativeAuthBaseState {
    let controller: MSALNativeAuthMFAControlling
    let scopes: [String]
    let claimsRequestJson: String?

    init(
        controller: MSALNativeAuthMFAControlling,
        scopes: [String],
        claimsRequestJson: String?,
        continuationToken: String,
        correlationId: UUID) {
        self.controller = controller
        self.scopes = scopes
        self.claimsRequestJson = claimsRequestJson
        super.init(continuationToken: continuationToken, correlationId: correlationId)
    }

    func baseRequestChallenge(authMethod: MSALAuthMethod, delegate: MFARequestChallengeDelegate) {
        Task {
            let controllerResponse = await requestChallengeInternal(authMethod: authMethod)
            let delegateDispatcher = MFARequestChallengeDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)
            switch controllerResponse.result {
            case .verificationRequired(let sentTo, let channelTargetType, let codeLength, let newState):
                await delegateDispatcher.dispatchVerificationRequired(
                    newState: newState,
                    sentTo: sentTo,
                    channelTargetType: channelTargetType,
                    codeLength: codeLength,
                    correlationId: controllerResponse.correlationId
                )
            case .selectionRequired(let authMethods, let newState):
                await delegateDispatcher.dispatchSelectionRequired(
                    authMethods: authMethods,
                    newState: newState,
                    correlationId: controllerResponse.correlationId
                )
            case .error(let error, let newState):
                await delegate.onMFARequestChallengeError(error: error, newState: newState)
            }
        }
    }
}

///  An object of this type is created whenever a user needs to make a specific request to send the MFA challenge.
@objcMembers
public class AwaitingMFAState: MFABaseState {

    /// Requests the server to send the challenge to the default authentication method.
    /// - Parameter authMethod: The authentication method you want to use for sending the challenge
    /// - Parameter delegate: Delegate that receives callbacks for the operation.
    public func requestChallenge(authMethod: MSALAuthMethod, delegate: MFARequestChallengeDelegate) {
        baseRequestChallenge(authMethod: authMethod, delegate: delegate)
    }
}

@objcMembers
public class MFARequiredState: MFABaseState {

    let inputValidator: MSALNativeAuthInputValidating

    init(
        inputValidator: MSALNativeAuthInputValidating = MSALNativeAuthInputValidator(),
        controller: MSALNativeAuthMFAControlling,
        scopes: [String],
        claimsRequestJson: String?,
        continuationToken: String,
        correlationId: UUID) {
        self.inputValidator = inputValidator
        super.init(
            controller: controller,
            scopes: scopes,
            claimsRequestJson: claimsRequestJson,
            continuationToken: continuationToken,
            correlationId: correlationId
        )
    }

    /// Requests the server to send the challenge to the specified auth method or the default one.
    /// - Parameters:
    ///   - authMethod: The authentication method you want to use for sending the challenge
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func requestChallenge(authMethod: MSALAuthMethod, delegate: MFARequestChallengeDelegate) {
        baseRequestChallenge(authMethod: authMethod, delegate: delegate)
    }

    /// Submits the MFA challenge to the server for verification.
    /// - Parameters:
    ///   - challenge: Verification challenge that the user supplies.
    ///   - delegate: Delegate that receives callbacks for the operation.
    public func submitChallenge(challenge: String, delegate: MFASubmitChallengeDelegate) {
        Task {
            let controllerResponse = await submitChallengeInternal(challenge: challenge)
            let delegateDispatcher = MFASubmitChallengeDelegateDispatcher(delegate: delegate, telemetryUpdate: controllerResponse.telemetryUpdate)
            switch controllerResponse.result {
            case .completed(let result):
                await delegateDispatcher.dispatchSignInCompleted(result: result, correlationId: controllerResponse.correlationId)
            case .error(let error, let newState):
                await delegate.onMFASubmitChallengeError(error: error, newState: newState)
            }
        }
    }
}
