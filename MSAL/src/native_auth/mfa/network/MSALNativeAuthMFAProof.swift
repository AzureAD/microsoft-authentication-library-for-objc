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
import CryptoKit

internal enum MSALNativeAuthMFAProof {
    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func validation(secret: String, counter: UInt64) throws -> String {
        guard !secret.isEmpty else { throw MSALNativeAuthMFAFailure.missingSecretKey }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
        let input = Array(secret.uppercased().utf8)
        guard !input.isEmpty, input.count <= 1024 else { throw MSALNativeAuthMFAFailure.invalidResponse }
        var key = Data()
        var buffer: UInt32 = 0
        var bits = 0
        var padding = false
        for character in input {
            if character == 61 {
                padding = true
                continue
            }
            guard !padding, let index = alphabet.firstIndex(of: character) else {
                throw MSALNativeAuthMFAFailure.invalidResponse
            }
            buffer = (buffer << 5) | UInt32(index)
            bits += 5
            if bits >= 8 {
                bits -= 8
                key.append(UInt8((buffer >> bits) & 255))
            }
            buffer &= (1 << bits) - 1
        }
        guard !key.isEmpty, buffer == 0 else { throw MSALNativeAuthMFAFailure.invalidResponse }
        let message = Data((0..<8).reversed().map { UInt8((counter >> ($0 * 8)) & 255) })
        let digest = HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    static func token(_ data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) throws -> String {
        guard !data.isEmpty, data.count <= 4096 else {
            throw MSALNativeAuthMFAFailure.invalidDeviceToken
        }
        let prefix = environment == .sandbox ? "sb-apns2-" : "apns2-"
        return prefix + data.map { String(format: "%02x", $0) }.joined()
    }
}
