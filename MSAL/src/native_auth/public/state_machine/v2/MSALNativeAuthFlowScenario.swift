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

/// Identifies which Native Auth V2 (server-driven) flow a ``MSALNativeAuthFlowDelegate`` callback
/// belongs to.
///
/// Because V2 uses a single unified delegate for sign in, sign up and password reset, every delegate
/// callback also reports the `scenario` that triggered it so the app can react appropriately without
/// tracking the originating flow itself.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objc
public enum MSALNativeAuthFlowScenario: Int {

    /// The scenario could not be determined. This is the default value and should not normally be
    /// reported to the app; it acts as a safe placeholder until a concrete flow scenario is resolved.
    case unknown

    /// The callback originated from a sign in flow.
    case signIn

    /// The callback originated from a sign up flow.
    case signUp

    /// The callback originated from a password reset flow.
    case passwordReset
}
