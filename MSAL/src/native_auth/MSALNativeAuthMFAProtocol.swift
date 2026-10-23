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

internal struct MSALNativeAuthMFAActivation: Equatable, Sendable {
    let code: String
    let endpoint: URL

    init(code: String, url: String) throws {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, code.utf8.count <= 1024,
              !code.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw MSALNativeAuthMFAServiceError.invalidActivationInput
        }
        self.code = code
        let base = try MSALNativeAuthMFAEndpoint.validate(url.trimmingCharacters(in: .whitespacesAndNewlines))
        self.endpoint = base.lastPathComponent.lowercased() == "pfpaws.asmx"
            ? base : base.appendingPathComponent("PfPaWs.asmx")
    }

    init(qrCode: String) throws {
        guard qrCode.utf8.count <= 8192,
              let parts = URLComponents(string: qrCode),
              parts.user == nil, parts.password == nil, parts.fragment == nil,
              let items = parts.queryItems else {
            throw MSALNativeAuthMFAServiceError.invalidActivationInput
        }
        let isLegacyActivation = parts.host?.lowercased() == "activate_account"
        let accountTypes = items.filter { $0.name == "accountType" }
        let isHTTPSActivation = parts.scheme?.lowercased() == "https"
            && parts.host?.lowercased() == "login.microsoftonline.com"
            && (parts.port == nil || parts.port == 443)
            && parts.path == "/authenticatorApp/activateAccount"
            && accountTypes.count == 1
            && accountTypes.first?.value == "mfa"
        guard isLegacyActivation || isHTTPSActivation else {
            throw MSALNativeAuthMFAServiceError.invalidActivationInput
        }
        let codes = items.filter { $0.name == "code" }
        let urls = items.filter { $0.name == "url" }
        guard codes.count == 1, urls.count == 1,
              let code = codes.first?.value, let url = urls.first?.value else {
            throw MSALNativeAuthMFAServiceError.invalidActivationInput
        }
        try self.init(code: code, url: url)
    }
}

internal enum MSALNativeAuthMFAEndpoint {
    enum Policy: Sendable {
        case activation
        case phoneApp

        func validate(_ url: URL) throws {
            switch self {
            case .activation:
                _ = try MSALNativeAuthMFAEndpoint.validate(url.absoluteString)
            case .phoneApp:
                _ = try MSALNativeAuthMFAEndpoint.phoneApp(url.absoluteString)
            }
        }
    }

    static func validate(_ value: String, allowsLegacyService: Bool = false) throws -> URL {
        try validate(value, allowsLegacyService: allowsLegacyService, allowsQuery: false)
    }

    private static func validate(_ value: String, allowsLegacyService: Bool, allowsQuery: Bool) throws -> URL {
        guard value.utf8.count <= 4096,
              let parts = URLComponents(string: value),
              parts.scheme?.lowercased() == "https",
              parts.user == nil, parts.password == nil, parts.fragment == nil,
              (allowsQuery || parts.query == nil), parts.port == nil || parts.port == 443,
              let host = parts.host?.lowercased(),
              (["microsoft.com", "microsoft.us", "microsoft.cn"] + (allowsLegacyService ? ["phonefactor.net"] : [])).contains(where: {
                  host == $0 || host.hasSuffix("." + $0)
              }),
              let url = parts.url else {
            throw MSALNativeAuthMFAServiceError.untrustedEndpoint
        }
        return url
    }

    static func notification(_ value: String) throws -> URL {
        guard value.utf8.count <= 4096 else {
            throw MSALNativeAuthMFAServiceError.untrustedEndpoint
        }
        let absolute = value.contains("://") ? value : "https://" + value
        guard let parts = URLComponents(string: absolute) else {
            throw MSALNativeAuthMFAServiceError.untrustedEndpoint
        }
        if parts.percentEncodedPath.isEmpty, parts.query == nil, parts.fragment == nil {
            return try phoneApp(absolute + "/pad")
        }
        return try phoneApp(absolute)
    }

    static func phoneApp(_ value: String) throws -> URL {
        guard value.utf8.count <= 4096, !value.contains("\\"),
              !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              let parts = URLComponents(string: value),
              parts.url?.absoluteString == value,
              let host = parts.host, !host.contains("%"),
              ["/pad", "/mac/MobileAppCommunicator.svc", "/mac/MobileAppCommunicator.svc/"].contains(parts.percentEncodedPath) else {
            throw MSALNativeAuthMFAServiceError.untrustedEndpoint
        }
        let isMAC = parts.percentEncodedPath != "/pad"
        if let items = parts.queryItems {
            guard isMAC, !items.isEmpty,
                  Set(items.map(\.name)).count == items.count,
                  items.allSatisfy({ item in
                      guard ["su", "ignored"].contains(item.name), let value = item.value, !value.isEmpty else { return false }
                      return !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
                  }) else {
                throw MSALNativeAuthMFAServiceError.untrustedEndpoint
            }
        }
        return try validate(value, allowsLegacyService: !isMAC, allowsQuery: isMAC)
    }
}

internal struct MSALNativeAuthMFACredentialPolicy {
    let requiresNumberMatching: Bool

    init(encoded: String) throws {
        if encoded.isEmpty {
            requiresNumberMatching = false
            return
        }
        guard encoded.utf8.count <= 4096, let data = Data(base64Encoded: encoded), !data.isEmpty else {
            throw MSALNativeAuthMFAServiceError.unsupportedPolicy
        }
        let fields = try Self.fields(Array(data))
        // UserCredentialPolicy fields: phone (2), companion (4), platform (5).
        guard Set(fields.keys).isSubset(of: [2, 4, 5]), let phone = fields[2] else {
            throw MSALNativeAuthMFAServiceError.unsupportedPolicy
        }
        let phoneValues = try Self.scalarFields(phone, allowed: Set(1...8))
        // Only PUSH/ANY mode with disabled context/app-lock requirements and enabled policy state is supported.
        guard (phoneValues[1] ?? 0) <= 1,
              [1, 2].contains(phoneValues[2] ?? 0),
              (phoneValues[3] ?? 0) == 0, (phoneValues[4] ?? 0) == 0,
              (phoneValues[6] ?? 0) == 0, (phoneValues[7] ?? 0) <= 2,
              (phoneValues[8] ?? 0) == 0 else {
            throw MSALNativeAuthMFAServiceError.unsupportedPolicy
        }
        var requiresNumber = try Self.numberMatching(phoneValues[5] ?? 0)
        if let companion = fields[4] {
            // Support only explicit number-matching/availability settings, not other companion capabilities.
            let values = try Self.scalarFields(companion, allowed: [5, 7])
            guard (values[7] ?? 0) <= 2 else { throw MSALNativeAuthMFAServiceError.unsupportedPolicy }
            let companionRequiresNumber = try Self.numberMatching(values[5] ?? 0)
            requiresNumber = requiresNumber || companionRequiresNumber
        }
        if let platform = fields[5] {
            let values = try Self.scalarFields(platform, allowed: [1])
            guard (values[1] ?? 0) == 0 else { throw MSALNativeAuthMFAServiceError.unsupportedPolicy }
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
        default: throw MSALNativeAuthMFAServiceError.unsupportedPolicy
        }
    }

    private static func scalarFields(_ field: Field, allowed: Set<Int>) throws -> [Int: UInt64] {
        guard case .message(let bytes) = field else { throw MSALNativeAuthMFAServiceError.unsupportedPolicy }
        let fields = try Self.fields(bytes)
        guard Set(fields.keys).isSubset(of: allowed) else { throw MSALNativeAuthMFAServiceError.unsupportedPolicy }
        var values: [Int: UInt64] = [:]
        for (key, field) in fields {
            guard case .scalar(let value) = field else { throw MSALNativeAuthMFAServiceError.unsupportedPolicy }
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
                throw MSALNativeAuthMFAServiceError.unsupportedPolicy
            }
            let number = Int(tag >> 3)
            guard fields[number] == nil, fields.count < 16 else {
                throw MSALNativeAuthMFAServiceError.unsupportedPolicy
            }
            switch tag & 7 {
            case 0:
                fields[number] = .scalar(try varint(bytes, offset: &offset))
            case 2:
                let length = try varint(bytes, offset: &offset)
                guard length <= UInt64(bytes.count - offset) else {
                    throw MSALNativeAuthMFAServiceError.unsupportedPolicy
                }
                let end = offset + Int(length)
                fields[number] = .message(Array(bytes[offset..<end]))
                offset = end
            default:
                throw MSALNativeAuthMFAServiceError.unsupportedPolicy
            }
        }
        return fields
    }

    private static func varint(_ bytes: [UInt8], offset: inout Int) throws -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<10 {
            guard offset < bytes.count else { throw MSALNativeAuthMFAServiceError.unsupportedPolicy }
            let byte = bytes[offset]
            offset += 1
            guard index < 9 || byte <= 1 else { throw MSALNativeAuthMFAServiceError.unsupportedPolicy }
            value |= UInt64(byte & 0x7f) << (index * 7)
            if byte & 0x80 == 0 { return value }
        }
        throw MSALNativeAuthMFAServiceError.unsupportedPolicy
    }
}

internal struct MSALNativeAuthMFAXml: Codable, Sendable {
    let name: String
    var text: String = ""
    var attributes: [String: String] = [:]
    var children: [MSALNativeAuthMFAXml] = []

    func child(_ name: String) throws -> MSALNativeAuthMFAXml {
        let matches = children.filter { $0.name == name }
        guard matches.count == 1, let value = matches.first else {
            throw MSALNativeAuthMFAServiceError.invalidResponse
        }
        return value
    }

    func value(_ name: String) throws -> String {
        let node = try child(name)
        guard node.children.isEmpty else { throw MSALNativeAuthMFAServiceError.invalidResponse }
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
            throw MSALNativeAuthMFAServiceError.invalidResponse
        }
        let delegate = MSALNativeAuthMFAXmlParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), !delegate.invalid, delegate.stack.isEmpty, let root = delegate.root else {
            throw MSALNativeAuthMFAServiceError.invalidResponse
        }
        return root
    }
}

private final class MSALNativeAuthMFAXmlParser: NSObject, XMLParserDelegate {
    var stack: [MSALNativeAuthMFAXml] = []
    var root: MSALNativeAuthMFAXml?
    var invalid = false
    private var count = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        count += 1
        guard count <= 4096, stack.count < 32, root == nil else {
            invalid = true
            parser.abortParsing()
            return
        }
        stack.append(MSALNativeAuthMFAXml(name: elementName, attributes: attributeDict))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let text = String(data: CDATABlock, encoding: .utf8) else {
            invalid = true
            parser.abortParsing()
            return
        }
        self.parser(parser, foundCharacters: text)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let node = stack.popLast(), node.name == elementName else {
            invalid = true
            parser.abortParsing()
            return
        }
        if stack.isEmpty {
            root = node
        } else {
            stack[stack.count - 1].children.append(node)
        }
    }
}
