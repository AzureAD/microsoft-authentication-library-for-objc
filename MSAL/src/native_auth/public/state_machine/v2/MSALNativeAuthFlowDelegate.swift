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

/// Single unified delegate for all Native Auth V2 (server-driven) flows.
///
/// One delegate serves sign up, sign in and reset password. The SDK drives the flow and
/// reports back through these callbacks; the app reacts and continues the flow by
/// calling methods on the provided ``MSALNativeAuthFlowState``.
///
/// All callbacks are invoked on the main actor.
public protocol MSALNativeAuthFlowDelegate: AnyObject {

    /// The server requires the user to perform an action before the flow can continue.
    /// - Parameters:
    ///   - action: The action the server is requesting.
    ///   - flowState: Opaque handle used to continue the flow.
    @MainActor func onActionRequired(action: MSALNativeAuthAction, flowState: MSALNativeAuthFlowState)

    /// The flow completed successfully and the user now has tokens.
    /// - Parameter result: The authenticated user account result.
    @MainActor func onFlowCompleted(result: MSALNativeAuthUserAccountResult)

    /// The flow encountered an error.
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - flowState: Opaque handle used to retry/continue the flow, when the error is recoverable.
    @MainActor func onFlowError(error: MSALNativeAuthFlowError, flowState: MSALNativeAuthFlowState?)

    /// The server requires the flow to continue in a web browser (e.g. an unsupported scenario).
    /// - Parameters:
    ///   - url: The URL to open in a browser.
    ///   - flowState: Opaque handle used to continue the flow.
    @MainActor func onBrowserRequired(url: URL, flowState: MSALNativeAuthFlowState)
}

/// Default implementation makes ``onBrowserRequired(url:flowState:)`` optional.
public extension MSALNativeAuthFlowDelegate {

    @MainActor func onBrowserRequired(url: URL, flowState: MSALNativeAuthFlowState) {
        onFlowError(
            error: MSALNativeAuthFlowError(
                kind: .browserRequired,
                errorDescription: "The flow requires a web browser, but onBrowserRequired(url:flowState:) is not implemented."
            ),
            flowState: flowState
        )
    }
}
