// ------------------------------------------------------------------------------
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
//
// ------------------------------------------------------------------------------

/// A pending sign-in request and its account display information.
public final class MSALNativeAuthMfaSdkAuthSession: Sendable {
    public let guid: String

    public let accountName: String
    public let username: String

    /// Legacy phase-one field. The service implementation leaves this empty; the user reads the number on the sign-in page.
    public let firstEntropyNumber: String

    /// Whether approval requires the number displayed on the sign-in page. This never exposes the expected number.
    public let requiresNumberMatching: Bool

    internal init(
        guid: String, accountName: String, username: String, firstEntropyNumber: String,
        requiresNumberMatching: Bool = true
    ) {
        self.guid = guid
        self.accountName = accountName
        self.username = username
        self.firstEntropyNumber = firstEntropyNumber
        self.requiresNumberMatching = requiresNumberMatching
    }
}
