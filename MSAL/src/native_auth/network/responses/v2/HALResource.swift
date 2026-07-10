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

/// Represents a HAL Link Object as defined by the JSON-HAL specification.
///
/// See: https://www.ietf.org/archive/id/draft-kelly-json-hal-11.html
internal struct HALLink {
    /// The URI of the linked resource.
    let href: String

    /// Secondary key distinguishing links within the same relation.
    let name: String?

    /// Whether `href` is a URI Template (RFC 6570).
    let templated: Bool

    init(href: String, name: String? = nil, templated: Bool = false) {
        self.href = href
        self.name = name
        self.templated = templated
    }

    /// Parses a HAL Link Object from a JSON dictionary.
    init?(json: [String: Any]) {
        guard let href = json["href"] as? String else { return nil }
        self.href = href
        self.name = json["name"] as? String
        self.templated = json["templated"] as? Bool ?? false
    }
}

/// Generic parser for HAL+JSON documents.
///
/// Handles extraction of `_links` and `_embedded` sections,
/// and provides typed accessors for common HAL patterns.
internal struct HALResource {
    /// The raw JSON properties (excluding `_links` and `_embedded`).
    let properties: [String: Any]

    /// All links keyed by relation type.
    let links: [String: [HALLink]]

    /// All embedded resources keyed by relation type.
    let embedded: [String: [[String: Any]]]

    /// Parses a HAL resource from a JSON dictionary.
    init(json: [String: Any]) {
        var props = json
        var parsedLinks: [String: [HALLink]] = [:]
        var parsedEmbedded: [String: [[String: Any]]] = [:]

        // Parse _links
        if let linksJson = json["_links"] as? [String: Any] {
            for (rel, value) in linksJson {
                if rel == "curies" { continue }

                if let linkDict = value as? [String: Any], let link = HALLink(json: linkDict) {
                    parsedLinks[rel] = [link]
                } else if let linkArray = value as? [[String: Any]] {
                    parsedLinks[rel] = linkArray.compactMap { HALLink(json: $0) }
                }
            }
            props.removeValue(forKey: "_links")
        }

        // Parse _embedded
        if let embeddedJson = json["_embedded"] as? [String: Any] {
            for (rel, value) in embeddedJson {
                if let array = value as? [[String: Any]] {
                    parsedEmbedded[rel] = array
                } else if let single = value as? [String: Any] {
                    parsedEmbedded[rel] = [single]
                }
            }
            props.removeValue(forKey: "_embedded")
        }

        self.properties = props
        self.links = parsedLinks
        self.embedded = parsedEmbedded
    }

    // MARK: - Accessors

    /// Returns a single link for the given relation, or nil if not present.
    func link(rel: String) -> HALLink? {
        return links[rel]?.first
    }

    /// Returns all links for the given relation.
    func allLinks(rel: String) -> [HALLink] {
        return links[rel] ?? []
    }

    /// Returns embedded resources for the given relation.
    func embeddedResources(rel: String) -> [[String: Any]] {
        return embedded[rel] ?? []
    }

    /// Returns a string property value.
    func string(forKey key: String) -> String? {
        return properties[key] as? String
    }
}
