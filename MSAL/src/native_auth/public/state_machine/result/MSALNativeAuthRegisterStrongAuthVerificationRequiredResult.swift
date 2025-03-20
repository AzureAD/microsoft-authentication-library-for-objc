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

public class MSALNativeAuthRegisterStrongAuthVerificationRequiredResult: NSObject {

    private let internalNewState: RegisterStrongAuthVerificationRequiredState
    private let internalSentTo: String
    private let internalChannelTargetType: MSALNativeAuthChannelType
    private let internalCodeLength: Int

    init(
        newState: RegisterStrongAuthVerificationRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    ) {
        self.internalNewState = newState
        self.internalSentTo = sentTo
        self.internalChannelTargetType = channelTargetType
        self.internalCodeLength = codeLength
    }
    
    /// An object representing the new state of the flow with follow on methods.
    @objc public var newState: RegisterStrongAuthVerificationRequiredState {
        internalNewState
    }

    /// The email/phone number that the code was sent to.
    @objc public var sentTo: String {
        internalSentTo
    }

    /// The channel (email/phone) the code was sent through.
    @objc public var channelTargetType: MSALNativeAuthChannelType {
        internalChannelTargetType
    }
    
    /// The length of the code required.
    @objc public var codeLength: Int {
        internalCodeLength
    }
}
