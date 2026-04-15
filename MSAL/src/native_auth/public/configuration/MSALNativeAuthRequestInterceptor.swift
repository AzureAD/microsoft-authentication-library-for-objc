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

public typealias MSALNativeAuthRequestInterceptorAddHeaderCompletionBlock = @convention(block) ([String : String]?) -> Void

@objc public protocol MSALNativeAuthRequestInterceptor: NSObjectProtocol {
    
    /// Called before each native auth network request, allowing you to inject custom HTTP header fields.
    ///
    /// - Important: `completionBlock` **must always be called**, regardless of whether additional headers are needed.
    ///   - If no additional headers are required, call `completionBlock(nil)`.
    ///   - If additional headers are needed, inspect `requestUrl` to determine the request path and
    ///     call `completionBlock` with a `[String: String]` dictionary of headers to inject.
    ///
    /// - Note: All custom header field names must start with the `"x-"` prefix.
    ///   The prefixes `"x-ms-"`, `"x-client-"`, `"x-broker-"`, and `"x-app-"` are reserved and must not be used.
    ///
    /// - Parameters:
    ///   - requestUrl: The URL of the outgoing request. Use this to conditionally apply headers per endpoint.
    ///   - completionBlock: Must be called with a header dictionary, or `nil` if no extra headers are needed.
    func addAdditionalHeaderFields(_ requestUrl: URL?, completionBlock: @escaping MSALNativeAuthRequestInterceptorAddHeaderCompletionBlock)
}

