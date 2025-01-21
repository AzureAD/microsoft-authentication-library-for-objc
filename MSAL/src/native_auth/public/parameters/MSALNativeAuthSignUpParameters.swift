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

/// Encapsulates the parameters passed to the signUp method of MSALNativeAuthPublicClientApplication
@objcMembers
public class MSALNativeAuthSignUpParameters: NSObject {

    /// username of the account to sign up.
    public var username: String

    /// password of the account to sign up.
    public var password: String?

    /// user attributes to be used during account creation.
    public var attributes: [String: Any]?

    /// UUID to correlate this request with the server for debugging.
    public var correlationId: UUID?

    public init(username: String,
                password: String? = nil,
                attributes: [String: Any]? = nil,
                correlationId: UUID? = nil) {
        self.username = username
        self.password = password
        self.attributes = attributes
        self.correlationId = correlationId
    }
}
