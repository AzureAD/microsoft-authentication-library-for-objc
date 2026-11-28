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

import Foundation

internal struct MSALNativeAuthMFAPendingEnrollment: Codable, Sendable {
    let id: UUID
    let inputDigest: String
    let token: String
    var activation: MSALNativeAuthSASActivationResult?
    var validation: MSALNativeAuthSASValidationResult?
    var validationEndpoint: URL?
    var confirming = false

    enum CodingKeys: String, CodingKey {
        case id, inputDigest, token, activation, validation, validationEndpoint, confirming
    }
}

// Decode earlier persisted XML without requiring a live SAS client.
extension MSALNativeAuthMFAPendingEnrollment {
    private enum LegacyResponseKey: String, CodingKey { case name }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        inputDigest = try values.decode(String.self, forKey: .inputDigest)
        token = try values.decode(String.self, forKey: .token)
        confirming = try values.decode(Bool.self, forKey: .confirming)
        validationEndpoint = try values.decodeIfPresent(URL.self, forKey: .validationEndpoint)
        if values.contains(.activation), try !values.decodeNil(forKey: .activation) {
            let nested = try values.superDecoder(forKey: .activation)
            if try nested.container(keyedBy: LegacyResponseKey.self).contains(.name) {
                activation = try MSALNativeAuthSASActivationResult(legacyXML: MSALNativeAuthMFAXml(from: nested))
            } else {
                activation = try MSALNativeAuthSASActivationResult(from: nested)
            }
        }
        if values.contains(.validation), try !values.decodeNil(forKey: .validation) {
            let nested = try values.superDecoder(forKey: .validation)
            if try nested.container(keyedBy: LegacyResponseKey.self).contains(.name) {
                validation = try MSALNativeAuthSASValidationResult(legacyXML: MSALNativeAuthMFAXml(from: nested))
            } else {
                validation = try MSALNativeAuthSASValidationResult(from: nested)
            }
        }
    }
}
