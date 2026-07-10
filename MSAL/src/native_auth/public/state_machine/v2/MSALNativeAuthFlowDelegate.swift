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

/// Shared base delegate for all Native Auth V2 (server-driven) flows.
///
/// Unlike V1 — which exposes a different delegate protocol per step — V2 uses one
/// family of delegates for sign up, sign in and reset password. The SDK drives the flow and
/// reports back through these callbacks; the app reacts and continues the flow by
/// calling methods directly on the ``MSALNativeAuthState`` it is handed.
///
/// This base protocol declares only the two terminal callbacks (``onFlowCompleted(result:scenario:)``
/// and ``onFlowError(error:scenario:)``) that every flow reports. Each server-driven state is
/// delivered through its own per-state delegate protocol (e.g. ``MSALNativeAuthCodeRequiredDelegate``)
/// that extends this base and adds a single strongly-typed, required callback. The app conforms to
/// the per-state protocols for the states it wants to handle; if it does not conform to a state's
/// protocol, ``onFlowError(error:scenario:)`` is called with error type `notImplemented`.
///
/// All callbacks are invoked on the main actor.
@objc
public protocol MSALNativeAuthFlowDelegate {

    /// The flow completed successfully and the user now has tokens.
    /// - Parameters:
    ///   - result: The authenticated user account result.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario)

    /// The flow encountered an error.
    /// - Parameters:
    ///   - error: The error that occurred. The app decides whether it can retry by
    ///     inspecting the error (e.g. `error.isInvalidCode` / `error.isInvalidPassword`) and calling
    ///     the appropriate method again on the state it is currently handling.
    ///   - scenario: The flow (sign in / sign up / password reset) that produced this callback.
    @MainActor func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario)
}
