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
@objcMembers
public class MSALNativeAuthState: NSObject {
}
