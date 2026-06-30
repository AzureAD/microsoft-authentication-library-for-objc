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

@_implementationOnly import MSAL_Private

/// Parses a raw HTTP response into a ``MSALNativeAuthHALResponse``.
///
/// Unlike the V1 serializer (Decodable + snake_case), V2 responses are HAL+JSON and
/// every HTTP outcome carries a meaningful body, so this serializer never throws on a
/// non-200 status — it captures the status code and lets the V2 validator decide. HAL
/// `_links` / `_embedded` extraction is delegated to the shared `MSIDHALResource`.
final class MSALNativeAuthV2HALResponseSerializer: NSObject, MSIDResponseSerialization {

    func responseObject(for httpResponse: HTTPURLResponse?, data: Data?, context: MSIDRequestContext?) throws -> Any {
        let statusCode = httpResponse?.statusCode ?? 0
        let correlationId = MSALNativeAuthHALResponse.retrieveCorrelationIdFromHeaders(from: httpResponse)

        guard let data = data, !data.isEmpty else {
            // An empty body with a success status is still a valid (terminal) response.
            return MSALNativeAuthHALResponse(
                statusCode: statusCode,
                correlationId: correlationId,
                state: nil,
                action: nil,
                continuationToken: nil,
                codeLength: nil,
                hint: nil,
                code: nil,
                accessToken: nil,
                links: [:],
                methods: [],
                error: nil
            )
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "V2 ResponseSerializer failed: body is not a JSON object")
            throw MSALNativeAuthInternalError.responseSerializationError(headerCorrelationId: correlationId)
        }

        let resource = MSIDHALResource(json: json)

        return MSALNativeAuthHALResponse(
            statusCode: statusCode,
            correlationId: correlationId,
            state: resource.string(forKey: "state"),
            action: resource.string(forKey: "action"),
            continuationToken: resource.string(forKey: "continuationToken") ?? resource.string(forKey: "continuation_token"),
            codeLength: json["codeLength"] as? Int,
            hint: resource.string(forKey: "hint"),
            code: resource.string(forKey: "code"),
            accessToken: resource.string(forKey: "access_token"),
            links: Self.parseLinks(from: resource),
            methods: Self.parseMethods(from: resource),
            error: Self.parseError(from: json, fallbackCorrelationId: correlationId)
        )
    }

    private static func parseLinks(from resource: MSIDHALResource) -> [String: String] {
        var result: [String: String] = [:]
        for (relation, links) in resource.links {
            if let href = links.first?.href {
                result[relation] = href
            }
        }
        return result
    }

    private static func parseMethods(from resource: MSIDHALResource) -> [MSALNativeAuthHALResponse.EmbeddedMethod] {
        let methodResources = resource.embeddedResources(forRelation: "methods")
        return methodResources.map { dict in
            let methodResource = MSIDHALResource(json: dict)
            var links: [String: String] = [:]
            for (relation, halLinks) in methodResource.links {
                if let href = halLinks.first?.href {
                    links[relation] = href
                }
            }
            return MSALNativeAuthHALResponse.EmbeddedMethod(
                id: methodResource.string(forKey: "id"),
                type: methodResource.string(forKey: "type"),
                hint: methodResource.string(forKey: "hint"),
                links: links
            )
        }
    }

    private static func parseError(from json: [String: Any], fallbackCorrelationId: UUID?) -> MSALNativeAuthHALResponse.ServerError? {
        guard let errorDict = json["error"] as? [String: Any] else {
            return nil
        }

        var innerErrorCode: String?
        if let innerError = errorDict["innerError"] as? [String: Any] {
            innerErrorCode = innerError["code"] as? String
        }

        var correlationId = fallbackCorrelationId
        if let serverCorrelationId = errorDict["correlation_id"] as? String {
            correlationId = UUID(uuidString: serverCorrelationId) ?? fallbackCorrelationId
        }

        return MSALNativeAuthHALResponse.ServerError(
            code: errorDict["code"] as? String,
            message: errorDict["message"] as? String,
            innerErrorCode: innerErrorCode,
            correlationId: correlationId
        )
    }
}
