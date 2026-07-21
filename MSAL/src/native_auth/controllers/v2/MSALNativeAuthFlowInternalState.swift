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

/// Internal state that continues a Native Auth V2 (server-driven) flow.
///
/// The SDK creates one internal state per flow and hands it to each concrete ``MSALNativeAuthState`` it
/// produces (via the dispatcher). The concrete state's public continuation methods (e.g.
/// `submitCode(_:delegate:)`) forward to ``run(delegate:operation:)``, which invokes the matching
/// controller operation and routes the resulting response back through the dispatcher.
///
/// This type carries no public API surface — apps interact only with the concrete
/// ``MSALNativeAuthState`` subclasses.
class MSALNativeAuthFlowInternalState {

    let continuation: MSALNativeAuthFlowContinuationState
    private let controller: MSALNativeAuthFlowControlling
    private let dispatcher = MSALNativeAuthFlowResponseDispatcher()

    init(continuation: MSALNativeAuthFlowContinuationState, controller: MSALNativeAuthFlowControlling) {
        self.continuation = continuation
        self.controller = controller
    }

    /// Runs a controller operation and routes its response to the delegate.
    /// Passes itself as the value the controller reads (`internalState.continuation`).
    func run(
        delegate: MSALNativeAuthFlowDelegate,
        operation: @escaping (MSALNativeAuthFlowControlling, MSALNativeAuthFlowInternalState) async -> MSALNativeAuthFlowControllerResponse
    ) {
        Task {
            let response = await operation(controller, self)
            await dispatcher.dispatch(response, delegate: delegate)
        }
    }
}
