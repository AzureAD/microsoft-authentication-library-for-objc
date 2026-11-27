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

internal struct MSALNativeAuthMFACredentialPolicy {
    let requiresNumberMatching: Bool

    init(encoded: String) throws {
        if encoded.isEmpty {
            requiresNumberMatching = false
            return
        }
        guard encoded.utf8.count <= 4096, let data = Data(base64Encoded: encoded), !data.isEmpty else {
            throw MSALNativeAuthMFAFailure.unsupportedPolicy
        }
        let fields = try Self.fields(Array(data))
        // UserCredentialPolicy fields: phone (2), companion (4), platform (5).
        guard Set(fields.keys).isSubset(of: [2, 4, 5]), let phone = fields[2] else {
            throw MSALNativeAuthMFAFailure.unsupportedPolicy
        }
        let phoneValues = try Self.scalarFields(phone, allowed: Set(1...8))
        // Only PUSH/ANY mode with disabled context/app-lock requirements and enabled policy state is supported.
        guard (phoneValues[1] ?? 0) <= 1,
              [1, 2].contains(phoneValues[2] ?? 0),
              (phoneValues[3] ?? 0) == 0, (phoneValues[4] ?? 0) == 0,
              (phoneValues[6] ?? 0) == 0, (phoneValues[7] ?? 0) <= 2,
              (phoneValues[8] ?? 0) == 0 else {
            throw MSALNativeAuthMFAFailure.unsupportedPolicy
        }
        var requiresNumber = try Self.numberMatching(phoneValues[5] ?? 0)
        if let companion = fields[4] {
            // Support only explicit number-matching/availability settings, not other companion capabilities.
            let values = try Self.scalarFields(companion, allowed: [5, 7])
            guard (values[7] ?? 0) <= 2 else { throw MSALNativeAuthMFAFailure.unsupportedPolicy }
            let companionRequiresNumber = try Self.numberMatching(values[5] ?? 0)
            requiresNumber = requiresNumber || companionRequiresNumber
        }
        if let platform = fields[5] {
            let values = try Self.scalarFields(platform, allowed: [1])
            guard (values[1] ?? 0) == 0 else { throw MSALNativeAuthMFAFailure.unsupportedPolicy }
        }
        requiresNumberMatching = requiresNumber
    }

    private enum Field {
        case scalar(UInt64)
        case message([UInt8])
    }

    private static func numberMatching(_ value: UInt64) throws -> Bool {
        switch value {
        case 0: return false
        case 2: return true
        default: throw MSALNativeAuthMFAFailure.unsupportedPolicy
        }
    }

    private static func scalarFields(_ field: Field, allowed: Set<Int>) throws -> [Int: UInt64] {
        guard case .message(let bytes) = field else { throw MSALNativeAuthMFAFailure.unsupportedPolicy }
        let fields = try Self.fields(bytes)
        guard Set(fields.keys).isSubset(of: allowed) else { throw MSALNativeAuthMFAFailure.unsupportedPolicy }
        var values: [Int: UInt64] = [:]
        for (key, field) in fields {
            guard case .scalar(let value) = field else { throw MSALNativeAuthMFAFailure.unsupportedPolicy }
            values[key] = value
        }
        return values
    }

    // Bounded protobuf subset of UserCredentialPolicy. Unknown fields/wire types fail closed.
    private static func fields(_ bytes: [UInt8]) throws -> [Int: Field] {
        var offset = 0
        var fields: [Int: Field] = [:]
        while offset < bytes.count {
            let tag = try varint(bytes, offset: &offset)
            guard tag >> 3 > 0, tag >> 3 <= 536_870_911 else {
                throw MSALNativeAuthMFAFailure.unsupportedPolicy
            }
            let number = Int(tag >> 3)
            guard fields[number] == nil, fields.count < 16 else {
                throw MSALNativeAuthMFAFailure.unsupportedPolicy
            }
            switch tag & 7 {
            case 0:
                fields[number] = .scalar(try varint(bytes, offset: &offset))
            case 2:
                let length = try varint(bytes, offset: &offset)
                guard length <= UInt64(bytes.count - offset) else {
                    throw MSALNativeAuthMFAFailure.unsupportedPolicy
                }
                let end = offset + Int(length)
                fields[number] = .message(Array(bytes[offset..<end]))
                offset = end
            default:
                throw MSALNativeAuthMFAFailure.unsupportedPolicy
            }
        }
        return fields
    }

    private static func varint(_ bytes: [UInt8], offset: inout Int) throws -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<10 {
            guard offset < bytes.count else { throw MSALNativeAuthMFAFailure.unsupportedPolicy }
            let byte = bytes[offset]
            offset += 1
            guard index < 9 || byte <= 1 else { throw MSALNativeAuthMFAFailure.unsupportedPolicy }
            value |= UInt64(byte & 0x7f) << (index * 7)
            if byte & 0x80 == 0 { return value }
        }
        throw MSALNativeAuthMFAFailure.unsupportedPolicy
    }
}
