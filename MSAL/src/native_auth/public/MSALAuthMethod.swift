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

/**
 * MSALAuthMethod represents a user's authentication methods.
 */
@objc
public class MSALAuthMethod: NSObject {

    /// Authentication method identifier
    public let id: String

    /// Authentication method challenge type (oob, etc.)
    public let challengeType: String

    /// Authentication method channel target (email, etc.)
    public let channelTargetType: MSALNativeAuthChannelType

    /// Authentication method login hint (e.g. u**@**so.com)
    public let loginHint: String?

    init(id: String, challengeType: String, channelTargetType: MSALNativeAuthChannelType, loginHint: String?) {
        self.id = id
        self.challengeType = challengeType
        self.channelTargetType = channelTargetType
        self.loginHint = loginHint
    }
}
