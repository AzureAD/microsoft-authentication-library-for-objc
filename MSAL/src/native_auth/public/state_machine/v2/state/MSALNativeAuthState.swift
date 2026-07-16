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

/// Base type for states the server can request during a Native Auth V2 (server-driven) flow.
///
/// In V2 the server drives the flow: at each step the SDK reports a concrete
/// ``MSALNativeAuthState`` subclass through its dedicated ``MSALNativeAuthFlowDelegate`` callback
/// (e.g. ``MSALNativeAuthFlowDelegate/onCodeRequired(state:)``). The app then continues the flow by
/// calling the method(s) exposed on that concrete state — each state exposes only the
/// continuations valid for its step, so invalid calls are impossible.
///
/// This is an abstract base class — the SDK always hands back one of its concrete subclasses to the
/// matching state-specific delegate callback, so apps never need to downcast the state.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthState: NSObject {

    /// The originating flow scenario for this state, set by the SDK when the state is created.
    /// Reported alongside this state's delegate callbacks so the app can tell which flow produced
    /// it. Internal detail — not part of the public API surface.
    var scenario: MSALNativeAuthFlowScenario = .unknown

    /// The flow engine that continues the server-driven flow from this state, injected by the SDK
    /// when the state is created. Internal detail — not part of the public API surface. `nil` only for
    /// states an app constructs directly (which cannot advance a flow).
    var engine: MSALNativeAuthFlowState?

    /// Forwards a continuation operation to the flow engine. If the state has no engine (e.g. it was
    /// constructed directly by the app rather than handed back by the SDK), the delegate is notified
    /// with a general error instead of silently doing nothing.
    func run(
        delegate: MSALNativeAuthFlowDelegate,
        operation: @escaping (MSALNativeAuthV2FlowControlling, MSALNativeAuthFlowState) async -> MSALNativeAuthV2FlowControllerResponse
    ) {
        guard let engine = engine else {
            Task { @MainActor in
                delegate.onFlowError(
                    error: MSALNativeAuthFlowError(
                        type: .generalError,
                        errorDescription: "This state cannot be used to continue the flow."
                    ),
                    scenario: self.scenario
                )
            }
            return
        }
        engine.run(delegate: delegate, operation: operation)
    }
}
