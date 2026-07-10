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

    /// Opaque continuation context for the current step (server continuation token + resolved links).
    /// Injected by the SDK before the state is handed to the app.
    var continuation: MSALNativeAuthV2ContinuationState!

    /// The internal controller that performs the network operations for this flow.
    /// Injected by the SDK before the state is handed to the app.
    var controller: MSALNativeAuthV2FlowControlling!

    /// The originating flow scenario carried by this state's continuation context. Used internally
    /// to stamp the correct ``MSALNativeAuthFlowScenario`` on responses produced from this state.
    var scenario: MSALNativeAuthFlowScenario {
        continuation?.scenario ?? .unknown
    }

    /// Injects the continuation context and controller that let this state advance the flow.
    func inject(continuation: MSALNativeAuthV2ContinuationState, controller: MSALNativeAuthV2FlowControlling) {
        self.continuation = continuation
        self.controller = controller
    }

    /// Spawns the controller operation and routes the resulting response back to the delegate.
    func run(
        delegate: MSALNativeAuthFlowDelegate,
        operation: @escaping (MSALNativeAuthV2FlowControlling) async -> MSALNativeAuthV2FlowControllerResponse
    ) {
        let controller = self.controller
        Task {
            guard let controller else { return }
            let response = await operation(controller)
            let dispatcher = MSALNativeAuthFlowResponseDispatcher()
            await dispatcher.dispatch(response, delegate: delegate)
        }
    }
}
