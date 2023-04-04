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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

@objc
public class SignUpCodeSentState: MSALNativeAuthBaseState {
    public func resendCode(delegate: SignUpStartDelegate, correlationId: UUID? = nil) {
        delegate.onCodeSent(state: self, displayName: "email")
    }

    public func submitCode(code: String, delegate: SignUpVerifyCodeDelegate, correlationId: UUID? = nil) {
        delegate.completed()
    }
}

@objc
public class SignUpPasswordRequiredState: MSALNativeAuthBaseState {
    public func submitPassword(password: String, delegate: SignUpPasswordRequiredDelegate, correlationId: UUID? = nil) {

    }
}

@objc
public class SignUpAttributeRequiredState: MSALNativeAuthBaseState {
    public func submitAttributes(
        attributes: [String: Any],
        delegate: SignUpAttributeRequiredDelegate,
        correlationId: UUID? = nil) {

    }
}
