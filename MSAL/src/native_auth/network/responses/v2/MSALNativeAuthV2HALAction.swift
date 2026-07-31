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

/// The `action` a Native Auth V2 (HAL) interaction response instructs the SDK to perform next.
///
/// The validator maps the raw `action` string carried by ``MSALNativeAuthHALResponse`` onto one of
/// these values to decide the next step of the flow.
struct MSALNativeAuthV2HALAction: RawRepresentable, Hashable {
    let rawValue: String
}

extension MSALNativeAuthV2HALAction {
    static let challenge = Self(rawValue: "challenge")
}

extension MSALNativeAuthV2HALAction {
    static let verify = Self(rawValue: "verify")
}

extension MSALNativeAuthV2HALAction {
    static let enroll = Self(rawValue: "enroll")
}

extension MSALNativeAuthV2HALAction {
    static let register = Self(rawValue: "register")
}

extension MSALNativeAuthV2HALAction {
    static let activate = Self(rawValue: "activate")
}

extension MSALNativeAuthV2HALAction {
    static let collectAttributes = Self(rawValue: "collectAttributes")
}

extension MSALNativeAuthV2HALAction {
    static let update = Self(rawValue: "update")
}

extension MSALNativeAuthV2HALAction {
    static let poll = Self(rawValue: "poll")
}
