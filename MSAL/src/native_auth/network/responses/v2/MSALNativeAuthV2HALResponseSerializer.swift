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
            return MSALNativeAuthHALResponse(
                statusCode: statusCode,
                correlationId: correlationId,
                continuationToken: nil,
                links: [:],
                error: nil,
                isWebFallbackRequired: false
            )
        }

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            MSALNativeAuthLogger.log(level: .error, context: context, format: "V2 ResponseSerializer failed: body is not a JSON object")
            throw MSALNativeAuthInternalError.responseSerializationError(headerCorrelationId: correlationId)
        }

        let resource = HALResource(json: json)
        let state = resource.string(forKey: "state")
        let error = parseError(from: json, fallbackCorrelationId: correlationId)
        let base = BaseFields(
            statusCode: statusCode,
            correlationId: correlationId,
            continuationToken: resource.string(forKey: "continuationToken") ?? resource.string(forKey: "continuation_token"),
            links: parseLinks(from: resource, json: json),
            error: error,
            isWebFallbackRequired: error?.code == "redirect_to_web" || state == "webFallbackRequired"
        )

        return makeConcreteResponse(resource: resource, json: json, state: state, base: base)
    }

    /// Routes the parsed HAL body to the concrete response subclass that matches its shape.
    private func makeConcreteResponse(
        resource: HALResource,
        json: [String: Any],
        state: String?,
        base: BaseFields
    ) -> MSALNativeAuthHALResponse {
        // The final authorize-challenge outcome carries an authorization code.
        if let code = resource.string(forKey: "code") {
            return makeAuthorizationCodeResponse(base, code: code)
        }

        if let actionValue = resource.string(forKey: "action") {
            switch MSALNativeAuthV2HALAction(rawValue: actionValue) {
            case .challenge:
                return makeChallengeResponse(base, methods: parseMethods(from: resource), hint: resource.string(forKey: "hint"))
            case .verify:
                return makeCodeSentResponse(
                    base,
                    codeLength: json["codeLength"] as? Int,
                    methodType: resource.string(forKey: "type"),
                    hint: resource.string(forKey: "hint")
                )
            case .update:
                return makeUpdateResponse(base)
            case .poll:
                return makePollResponse(base)
            default:
                break
            }
        }

        if state == "continue" {
            return makeReadyToCompleteResponse(base)
        }

        return makeBaseResponse(base)
    }

    /// The envelope fields shared by every concrete response, threaded through the factory helpers.
    private struct BaseFields {
        let statusCode: Int
        let correlationId: UUID?
        let continuationToken: String?
        let links: [String: String]
        let error: MSALNativeAuthHALResponse.ServerError?
        let isWebFallbackRequired: Bool
    }

    private func makeBaseResponse(_ base: BaseFields) -> MSALNativeAuthHALResponse {
        return MSALNativeAuthHALResponse(
            statusCode: base.statusCode,
            correlationId: base.correlationId,
            continuationToken: base.continuationToken,
            links: base.links,
            error: base.error,
            isWebFallbackRequired: base.isWebFallbackRequired
        )
    }

    private func makeChallengeResponse(
        _ base: BaseFields,
        methods: [MSALNativeAuthHALChallengeResponse.EmbeddedMethod],
        hint: String?
    ) -> MSALNativeAuthHALChallengeResponse {
        return MSALNativeAuthHALChallengeResponse(
            statusCode: base.statusCode,
            correlationId: base.correlationId,
            continuationToken: base.continuationToken,
            links: base.links,
            error: base.error,
            isWebFallbackRequired: base.isWebFallbackRequired,
            methods: methods,
            hint: hint
        )
    }

    private func makeCodeSentResponse(
        _ base: BaseFields,
        codeLength: Int?,
        methodType: String?,
        hint: String?
    ) -> MSALNativeAuthHALCodeSentResponse {
        return MSALNativeAuthHALCodeSentResponse(
            statusCode: base.statusCode,
            correlationId: base.correlationId,
            continuationToken: base.continuationToken,
            links: base.links,
            error: base.error,
            isWebFallbackRequired: base.isWebFallbackRequired,
            codeLength: codeLength,
            methodType: methodType,
            hint: hint
        )
    }

    private func makeUpdateResponse(_ base: BaseFields) -> MSALNativeAuthHALUpdateResponse {
        return MSALNativeAuthHALUpdateResponse(
            statusCode: base.statusCode,
            correlationId: base.correlationId,
            continuationToken: base.continuationToken,
            links: base.links,
            error: base.error,
            isWebFallbackRequired: base.isWebFallbackRequired
        )
    }

    private func makePollResponse(_ base: BaseFields) -> MSALNativeAuthHALPollResponse {
        return MSALNativeAuthHALPollResponse(
            statusCode: base.statusCode,
            correlationId: base.correlationId,
            continuationToken: base.continuationToken,
            links: base.links,
            error: base.error,
            isWebFallbackRequired: base.isWebFallbackRequired
        )
    }

    private func makeReadyToCompleteResponse(_ base: BaseFields) -> MSALNativeAuthHALReadyToCompleteResponse {
        return MSALNativeAuthHALReadyToCompleteResponse(
            statusCode: base.statusCode,
            correlationId: base.correlationId,
            continuationToken: base.continuationToken,
            links: base.links,
            error: base.error,
            isWebFallbackRequired: base.isWebFallbackRequired
        )
    }

    private func makeAuthorizationCodeResponse(_ base: BaseFields, code: String) -> MSALNativeAuthHALAuthorizationCodeResponse {
        return MSALNativeAuthHALAuthorizationCodeResponse(
            statusCode: base.statusCode,
            correlationId: base.correlationId,
            continuationToken: base.continuationToken,
            links: base.links,
            error: base.error,
            isWebFallbackRequired: base.isWebFallbackRequired,
            code: code
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

    private func parseMethods(from resource: HALResource) -> [MSALNativeAuthHALChallengeResponse.EmbeddedMethod] {
        let methodResources = resource.embeddedResources(rel: "methods")
        return methodResources.map { dict in
            let methodResource = HALResource(json: dict)
            var links: [String: String] = [:]
            for (relation, halLinks) in methodResource.links {
                if let href = halLinks.first?.href {
                    links[relation] = href
                }
            }
            return MSALNativeAuthHALChallengeResponse.EmbeddedMethod(
                id: methodResource.string(forKey: "id"),
                type: methodResource.string(forKey: "type"),
                hint: methodResource.string(forKey: "hint"),
                links: links
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
