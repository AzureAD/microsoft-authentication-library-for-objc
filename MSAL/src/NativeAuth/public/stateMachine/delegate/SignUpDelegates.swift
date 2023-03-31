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
public protocol SignUpStartDelegate {
    func flowInterrupted(reason: SignUpStartFlowInterruptionReason)
    func onError(error: SignUpError)
    func onOOBSent(flow: SignUpOOBSentState, displayName: String)
}

@objc
public protocol SignUpVerifyCodeDelegate {
    func flowInterrupted(reason: BaseFlowInterruptionReason)
    func onError(error: VerifyCodeError, state: SignUpOOBSentState)
    func completed()
    func passwordRequired(state: SignUpPasswordRequiredState)
    func attributesRequired(state: SignUpAttributeRequiredState)
}

@objc
public protocol SignUpPasswordRequiredDelegate {
    func flowInterrupted(reason: BaseFlowInterruptionReason)
    func onError(error: PasswordRequiredError, state: SignUpPasswordRequiredState)
    func completed()
    func attributesRequired(flow: SignUpAttributeRequiredState)
}

@objc
public protocol SignUpAttributeRequiredDelegate {
    func flowInterrupted(reason: BaseFlowInterruptionReason)
    func onError(error: AttributeRequiredError, state: SignUpAttributeRequiredState)
    func completed()
}
