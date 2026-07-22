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

@_implementationOnly import MSAL_Private

/// Parses a raw HTTP response into a ``MSALNativeAuthHALResponse``.
///
/// V2 responses are HAL+JSON and every HTTP outcome carries a meaningful body, so this
/// serializer never throws on a non-200 status - it captures the status code and lets the
/// V2 validator decide. HAL `_links` / `_embedded` extraction is delegated to the shared
/// `HALResource`.
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
                authenticationFactor: nil,
                methodId: nil,
                methodType: nil,
                attributes: [],
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

        let resource = HALResource(json: json)

        return MSALNativeAuthHALResponse(
            statusCode: statusCode,
            correlationId: correlationId,
            state: resource.string(forKey: "state"),
            action: resource.string(forKey: "action"),
            continuationToken: resource.string(forKey: "continuationToken") ?? resource.string(forKey: "continuation_token"),
            codeLength: json["codeLength"] as? Int,
            hint: resource.string(forKey: "hint"),
            authenticationFactor: (json["challengeContext"] as? [String: Any])?["authenticationFactor"] as? String,
            methodId: resource.string(forKey: "id"),
            methodType: resource.string(forKey: "type"),
            attributes: parseAttributes(from: json),
            code: resource.string(forKey: "code"),
            accessToken: resource.string(forKey: "access_token"),
            links: parseLinks(from: resource, json: json),
            methods: parseMethods(from: resource),
            error: parseError(from: json, fallbackCorrelationId: correlationId)
        )
    }

    private func parseLinks(from resource: HALResource, json: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (relation, links) in resource.links {
            if let href = links.first?.href {
                result[relation] = href
            }
        }

        for flowScenario in MSALNativeAuthFlowScenario.authorizeChallengeFlows where result[flowScenario.link] == nil {
            if let href = json[flowScenario.link] as? String {
                result[flowScenario.link] = href
            }
        }
        return result
    }

    private func parseMethods(from resource: HALResource) -> [MSALNativeAuthHALResponse.EmbeddedMethod] {
        let methodResources = resource.embeddedResources(rel: "methods")
        return methodResources.map { dict in
            let methodResource = HALResource(json: dict)
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

    private func parseAttributes(from json: [String: Any]) -> [MSALNativeAuthHALResponse.RequiredAttributeEntry] {
        guard let rawAttributes = json["attributes"] as? [[String: Any]] else {
            return []
        }
        return rawAttributes.map { dict in
            MSALNativeAuthHALResponse.RequiredAttributeEntry(
                id: (dict["attributeId"] as? String) ?? (dict["id"] as? String),
                type: dict["type"] as? String,
                required: (dict["required"] as? Bool) ?? false,
                regex: (dict["validationRegex"] as? String) ?? (dict["regex"] as? String)
            )
        }
    }

    private func parseError(from json: [String: Any], fallbackCorrelationId: UUID?) -> MSALNativeAuthHALResponse.ServerError? {
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
