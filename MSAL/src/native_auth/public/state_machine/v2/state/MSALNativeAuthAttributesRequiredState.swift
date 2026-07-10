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

/// The server requires additional user attributes.
/// Continue with ``submitAttributes(_:delegate:)``.
@objcMembers
public class MSALNativeAuthAttributesRequiredState: MSALNativeAuthState {

    /// The attributes the server requires.
    public let attributes: [MSALNativeAuthRequiredAttribute]

    public init(attributes: [MSALNativeAuthRequiredAttribute]) {
        self.attributes = attributes
        super.init()
    }

    /// Submit user attributes (sign up).
    public func submitAttributes(_ attributes: [String: Any], delegate: MSALNativeAuthFlowDelegate) {
        run(delegate: delegate) { [continuation] controller in
            await controller.submitAttributes(attributes, continuation: continuation!)
        }
    }

    public override var description: String {
        return "attributesRequired (\(attributes.map { $0.name }.joined(separator: ", ")))"
    }
}
