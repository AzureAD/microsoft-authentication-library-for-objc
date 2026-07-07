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

/// Identifies which V2 flow a ``MSALNativeAuthFlowState`` belongs to.
enum MSALNativeAuthV2FlowType {
    case signUp
    case signIn
    case resetPassword
}

/// Internal continuation context carried by a ``MSALNativeAuthFlowState``.
///
/// Holds the opaque server `continuation_token` and the resolved `_links` hrefs
/// the SDK must follow to advance the server-driven flow.
struct MSALNativeAuthV2ContinuationState {
    let flowType: MSALNativeAuthV2FlowType
    let continuationToken: String
    /// Resolved `_links` keyed by relation (e.g. "verify", "resend", "update", "poll", "continue",
    /// "challenge", "enroll", "activate", "submitAttributes"). Per-method links are keyed "method:<id>".
    let links: [String: URL]
    let username: String?
    let sentToHint: String?
    let codeLength: Int?
    /// Auth methods offered for MFA / strong-auth (JIT) selection.
    let authMethods: [MSALAuthMethod]
    /// Scopes (caller-requested merged with the default OIDC scopes) to request on the final
    /// `/token` exchange. Threaded through every step so completion mirrors the V1 sign-in flow.
    let scopes: [String]

    init(
        flowType: MSALNativeAuthV2FlowType,
        continuationToken: String,
        links: [String: URL],
        username: String?,
        sentToHint: String? = nil,
        codeLength: Int? = nil,
        authMethods: [MSALAuthMethod] = [],
        scopes: [String] = []
    ) {
        self.flowType = flowType
        self.continuationToken = continuationToken
        self.links = links
        self.username = username
        self.sentToHint = sentToHint
        self.codeLength = codeLength
        self.authMethods = authMethods
        self.scopes = scopes
    }

    func link(_ relation: String) -> URL? {
        return links[relation]
    }

    /// The challenge / enroll link associated with a specific auth method.
    func methodLink(for methodId: String) -> URL? {
        return links["method:\(methodId)"]
    }
}

/// Result produced by the unified V2 controller for a single step of a flow.
enum MSALNativeAuthV2FlowResult {
    case actionRequired(action: MSALNativeAuthAction, newState: MSALNativeAuthFlowState)
    case completed(MSALNativeAuthUserAccountResult)
    case error(error: MSALNativeAuthFlowError, newState: MSALNativeAuthFlowState?)
    case browserRequired(url: URL, newState: MSALNativeAuthFlowState)
}

/// Wraps the controller result with the correlation id and an optional telemetry update closure.
struct MSALNativeAuthV2FlowControllerResponse {
    let result: MSALNativeAuthV2FlowResult
    let correlationId: UUID
    let telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)?

    init(
        _ result: MSALNativeAuthV2FlowResult,
        correlationId: UUID,
        telemetryUpdate: ((Result<Void, MSALNativeAuthError>) -> Void)? = nil
    ) {
        self.result = result
        self.correlationId = correlationId
        self.telemetryUpdate = telemetryUpdate
    }
}

/// Routes a controller response to the appropriate ``MSALNativeAuthFlowDelegate`` callback.
struct MSALNativeAuthFlowResponseDispatcher {

    func dispatch(_ response: MSALNativeAuthV2FlowControllerResponse, delegate: MSALNativeAuthFlowDelegate) async {
        switch response.result {
        case .actionRequired(let action, let newState):
            await delegate.onActionRequired(action: action, flowState: newState)
            response.telemetryUpdate?(.success(()))
        case .completed(let result):
            await delegate.onFlowCompleted(result: result)
            response.telemetryUpdate?(.success(()))
        case .error(let error, let newState):
            await delegate.onFlowError(error: error, flowState: newState)
        case .browserRequired(let url, let newState):
            if let onBrowserRequired = delegate.onBrowserRequired {
                await onBrowserRequired(url, newState)
                response.telemetryUpdate?(.success(()))
            } else {
                let error = MSALNativeAuthFlowError(
                    kind: .browserRequired,
                    errorDescription: "The flow requires a web browser, but onBrowserRequired(url:flowState:) is not implemented.",
                    correlationId: response.correlationId
                )
                response.telemetryUpdate?(.failure(MSALNativeAuthError(message: error.errorDescription, correlationId: response.correlationId)))
                await delegate.onFlowError(error: error, flowState: newState)
            }
        }
    }
}
