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

/// Maps server method types to SDK `MSALCredentialType` values.
///
/// The server uses different type identifiers (e.g., "fido") than the SDK
/// (e.g., `.passkey`). This mapper handles the bidirectional translation.
internal struct CredentialMethodMapper
{
    // MARK: - Server type → SDK type mapping

    /// Maps a server `type` string to an `MSALCredentialType`.
    static func credentialType(fromServerType serverType: String) -> MSALCredentialType?
    {
        switch serverType
        {
        case "fido":
            return .passkey
        case "phone", "sms":
            return .phone
        case "password":
            return .password
        default:
            return nil
        }
    }

    /// Maps an `MSALCredentialType` to the server's `type` string for API paths.
    static func serverType(from credentialType: MSALCredentialType) -> String
    {
        return credentialType.rawValue
    }

    // MARK: - HAL JSON → Credential Method

    /// Parses a single credential method from a HAL-embedded method JSON object.
    ///
    /// - Parameter json: The method JSON from `_embedded.methods[]`.
    /// - Returns: A concrete `MSALCredentialMethodProtocol` instance, or nil for unknown types.
    static func parseMethod(from json: [String: Any]) -> (any MSALCredentialMethodProtocol)?
    {
        guard let serverType = json["type"] as? String,
              let id = json["id"] as? String else
        {
            return nil
        }

        let displayName = json["displayName"] as? String

        switch serverType
        {
        case "fido":
            return MSALPasskeyCredentialMethod(
                id: id,
                displayName: displayName,
                createdAt: nil,
                credentialID: nil,
                aaguid: json["aaGuid"] as? String
            )

        case "phone", "sms":
            return MSALPhoneCredentialMethod(
                id: id,
                createdAt: nil,
                phoneNumber: displayName
            )

        case "password":
            return MSALPasswordCredentialMethod(
                id: id,
                createdAt: nil
            )

        default:
            // Unknown method type — skip for forward compatibility
            return nil
        }
    }

    /// Parses the list of credential methods from a `GET /me/methods` HAL response.
    ///
    /// - Parameter halResource: The parsed HAL resource.
    /// - Returns: Array of credential method instances.
    static func parseMethods(from halResource: HALResource) -> [any MSALCredentialMethodProtocol]
    {
        let methodsJson = halResource.embeddedResources(rel: "methods")
        return methodsJson.compactMap { parseMethod(from: $0) }
    }
}
