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

internal struct MSALNativeAuthMFAXml: Codable, Sendable {
    let name: String
    var text: String = ""
    var attributes: [String: String] = [:]
    var children: [MSALNativeAuthMFAXml] = []

    func child(_ name: String) throws -> MSALNativeAuthMFAXml {
        let matches = children.filter { $0.name == name }
        guard matches.count == 1, let value = matches.first else {
            throw MSALNativeAuthMFAFailure.invalidResponse
        }
        return value
    }

    func value(_ name: String) throws -> String {
        let node = try child(name)
        guard node.children.isEmpty else { throw MSALNativeAuthMFAFailure.invalidResponse }
        return node.text
    }

    func optionalValue(_ name: String) throws -> String? {
        guard children.contains(where: { $0.name == name }) else { return nil }
        return try value(name)
    }

    var encoded: String {
        let attributes = attributes.sorted { $0.key < $1.key }.map {
            " \($0.key)=\"\(Self.escape($0.value))\""
        }.joined()
        return "<\(name)\(attributes)>\(Self.escape(text))\(children.map(\.encoded).joined())</\(name)>"
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func parse(_ data: Data) throws -> MSALNativeAuthMFAXml {
        guard data.count <= 1_048_576,
              let text = String(data: data, encoding: .utf8),
              !text.localizedCaseInsensitiveContains("<!DOCTYPE"),
              !text.localizedCaseInsensitiveContains("<!ENTITY") else {
            throw MSALNativeAuthMFAFailure.invalidResponse
        }
        let delegate = MSALNativeAuthMFAXmlParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.invalid, delegate.stack.isEmpty, let root = delegate.root else {
            throw MSALNativeAuthMFAFailure.invalidResponse
        }
        return root
    }
}
