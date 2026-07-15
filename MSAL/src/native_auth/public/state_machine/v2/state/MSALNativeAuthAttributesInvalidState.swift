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

/// The server reports that some attributes were invalid and must be corrected.
/// Continue with ``submitAttributes(_:delegate:)``.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthAttributesInvalidState: MSALNativeAuthState {

    /// The names of the attributes that were invalid.
    public let attributeNames: [String]

    public init(attributeNames: [String]) {
        self.attributeNames = attributeNames
        super.init()
    }

    /// Resubmit the corrected user attributes.
    public func submitAttributes(_ attributes: [String: Any], delegate: MSALNativeAuthFlowDelegate) {
        Task { @MainActor in
            delegate.onFlowError(
                error: MSALNativeAuthFlowError(type: .notImplemented, correlationId: UUID()),
                scenario: self.scenario
            )
        }
    }

    public override var description: String {
        return "attributesInvalid (\(attributeNames.joined(separator: ", ")))"
    }
}

/// Per-state delegate for the ``MSALNativeAuthAttributesInvalidState`` step of a Native Auth V2 flow.
///
/// Conform to this protocol (in addition to the terminal callbacks inherited from
/// ``MSALNativeAuthFlowDelegate``) to handle this state. Conforming is opt-in per state, but the
/// callback is required once you conform.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objc
public protocol MSALNativeAuthAttributesInvalidDelegate: MSALNativeAuthFlowDelegate {

    /// The server reports that some attributes were invalid and must be corrected.
    /// Continue with ``MSALNativeAuthAttributesInvalidState/submitAttributes(_:delegate:)``.
    /// - Parameters:
    ///   - state: The invalid-attributes state.
    ///   - scenario: The flow that produced this callback.
    /// - Note: If the app's delegate does not conform to this protocol, then
    ///   ``MSALNativeAuthFlowDelegate/onFlowError(error:scenario:)`` is called with error type `notImplemented`.
    @MainActor func onAttributesInvalid(state: MSALNativeAuthAttributesInvalidState, scenario: MSALNativeAuthFlowScenario)
}
