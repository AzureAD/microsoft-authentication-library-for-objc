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

/// Class that defines the basic structure of a Native Auth error
@objcMembers
public class MSALNativeAuthError: NSObject, LocalizedError {
    /// Describes why an error occurred and provides more information about the error.
    public var errorDescription: String? { message }

    /// Correlation ID used for the request
    public let correlationId: UUID

    /// Error codes returned along with the error
    public let errorCodes: [Int]

    /// Error uri that can be followed to get more information about the error returned by the server
    public let errorUri: String?

    private let message: String?

    init(message: String? = nil, correlationId: UUID, errorCodes: [Int] = [], errorUri: String? = nil) {
        self.message = message
        self.correlationId = correlationId
        self.errorCodes = errorCodes
        self.errorUri = errorUri
    }
}
