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

internal protocol MSALNativeAuthMfaSdkTransporting: Sendable {
    func send(_ request: URLRequest, endpointPolicy: MSALNativeAuthMfaSdkEndpoint.Policy) async throws -> Data
}

internal final class MSALNativeAuthMfaSdkTransport: MSALNativeAuthMfaSdkTransporting {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func send(_ request: URLRequest, endpointPolicy: MSALNativeAuthMfaSdkEndpoint.Policy) async throws -> Data {
        try Task.checkCancellation()
        guard let url = request.url else { throw MSALNativeAuthMfaSdkServiceError.untrustedEndpoint }
        try endpointPolicy.validate(url)
        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: MSALNativeAuthMfaSdkRedirectBlocker())
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse else {
                throw MSALNativeAuthMfaSdkServiceError.invalidResponse
            }
            guard response.statusCode == 200 else {
                throw MSALNativeAuthMfaSdkServiceError.httpFailure(statusCode: response.statusCode)
            }
            guard response.expectedContentLength <= 1_048_576 else {
                throw MSALNativeAuthMfaSdkServiceError.invalidResponse
            }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < 1_048_576 else { throw MSALNativeAuthMfaSdkServiceError.invalidResponse }
                data.append(byte)
            }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as MSALNativeAuthMfaSdkServiceError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            // URLSession errors may contain activation URLs; do not expose their userInfo.
            throw MSALNativeAuthMfaSdkServiceError.transportFailure
        }
    }
}

private final class MSALNativeAuthMfaSdkRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

internal struct MSALNativeAuthMfaSdkServiceClient: Sendable {
    let transport: any MSALNativeAuthMfaSdkTransporting
    private let namespace = "http://www.phonefactor.com/PfPaWs"

    func activation(operation: String, endpoint: URL, fields: [MSALNativeAuthMfaSdkXml]) async throws -> MSALNativeAuthMfaSdkXml {
        let method = MSALNativeAuthMfaSdkXml(name: operation, attributes: ["xmlns": namespace], children: fields)
        let envelope = MSALNativeAuthMfaSdkXml(
            name: "soap:Envelope", attributes: ["xmlns:soap": "http://schemas.xmlsoap.org/soap/envelope/"],
            children: [MSALNativeAuthMfaSdkXml(name: "soap:Body", children: [method])]
        )
        var request = try request(endpoint: endpoint, body: envelope, endpointPolicy: .activation)
        request.setValue(namespace + "/" + operation, forHTTPHeaderField: "SOAPAction")
        let response = try MSALNativeAuthMfaSdkXml.parse(await transport.send(request, endpointPolicy: .activation))
        let body = try response.child("Body")
        if body.children.contains(where: { $0.name == "Fault" }) {
            throw MSALNativeAuthMfaSdkServiceError.serviceFailure(operation: operation, code: "SOAPFault")
        }
        let result = try body.child(operation + "Response")
        let outcome = try result.value(operation + "Result").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["true", "1", "false", "0"].contains(outcome) else {
            throw MSALNativeAuthMfaSdkServiceError.invalidResponse
        }
        if outcome == "false" || outcome == "0" {
            var code = "Rejected"
            if result.children.contains(where: { $0.name == "error" }),
               let value = try result.child("error").optionalValue("Code") {
                let numericCode = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !numericCode.isEmpty, numericCode.utf8.count <= 10,
                   numericCode.utf8.allSatisfy({ (48...57).contains($0) }) {
                    code = numericCode
                }
            }
            throw MSALNativeAuthMfaSdkServiceError.serviceFailure(operation: operation, code: code)
        }
        return result
    }

    func phoneApp(operation: String, endpoint: URL, fields: [MSALNativeAuthMfaSdkXml],
                  headers: [String: String] = [:]) async throws -> MSALNativeAuthMfaSdkXml {
        let tag = operation.prefix(1).lowercased() + operation.dropFirst()
        let body = MSALNativeAuthMfaSdkXml(
            name: "pfpMessage", attributes: ["version": "1.6"],
            children: [
                MSALNativeAuthMfaSdkXml(name: "header", children: [
                    MSALNativeAuthMfaSdkXml(name: "source", children: [
                        MSALNativeAuthMfaSdkXml(name: "component", attributes: ["type": "pfsvc", "role": "master"], children: [
                            MSALNativeAuthMfaSdkXml(name: "host", attributes: ["ip": "", "hostname": "", "serverId": ""])
                        ])
                    ])
                ]),
                MSALNativeAuthMfaSdkXml(name: "request", attributes: [
                    "request-id": UUID().uuidString.lowercased(), "async": "0", "response-url": "", "language": "en"
                ], children: [
                    MSALNativeAuthMfaSdkXml(name: tag.hasSuffix("Request") ? tag : tag + "Request", children: fields)
                ])
            ]
        )
        var request = try request(endpoint: endpoint, body: body, endpointPolicy: .phoneApp)
        request.setValue(operation, forHTTPHeaderField: "x-ms-mac-action")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let result = try MSALNativeAuthMfaSdkXml.parse(await transport.send(request, endpointPolicy: .phoneApp))
        let response = try result.child("response")
        guard try response.child("status").attributes["disposition"] == "success" else {
            throw MSALNativeAuthMfaSdkServiceError.serviceFailure(operation: operation, code: "Rejected")
        }
        let expected = tag.hasSuffix("Request") ? String(tag.dropLast(7)) + "Response" : tag + "Response"
        return try response.child(expected)
    }

    private func request(
        endpoint: URL, body: MSALNativeAuthMfaSdkXml, endpointPolicy: MSALNativeAuthMfaSdkEndpoint.Policy
    ) throws -> URLRequest {
        try endpointPolicy.validate(endpoint)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = Data(body.encoded.utf8)
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "client-request-id")
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "AppName")
        request.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, forHTTPHeaderField: "AppVersion")
        return request
    }
}
