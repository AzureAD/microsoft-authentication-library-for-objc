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

internal protocol MSALNativeAuthMFATransporting: Sendable {
    func send(_ request: URLRequest, endpointPolicy: any MSALNativeAuthMFARequestPolicy) async throws -> Data
}

internal protocol MSALNativeAuthMFARequestPolicy: Sendable {
    func validate(_ request: URLRequest) throws
    func acceptsEmptyResponse(statusCode: Int) throws -> Bool
}

internal final class MSALNativeAuthMFATransport: MSALNativeAuthMFATransporting {
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

    func send(_ request: URLRequest, endpointPolicy: any MSALNativeAuthMFARequestPolicy) async throws -> Data {
        try Task.checkCancellation()
        try endpointPolicy.validate(request)
        do {
            let (bytes, response) = try await session.bytes(for: request, delegate: MSALNativeAuthMFARedirectBlocker())
            defer { bytes.task.cancel() }
            guard let response = response as? HTTPURLResponse else {
                throw MSALNativeAuthMFAFailure.invalidResponse
            }
            if try endpointPolicy.acceptsEmptyResponse(statusCode: response.statusCode) { return Data() }
            guard response.expectedContentLength <= 1_048_576 else {
                throw MSALNativeAuthMFAFailure.invalidResponse
            }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < 1_048_576 else { throw MSALNativeAuthMFAFailure.invalidResponse }
                data.append(byte)
            }
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as MSALNativeAuthMFAFailure {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            // URLSession errors may contain activation URLs; do not expose their userInfo.
            throw MSALNativeAuthMFAFailure.transportFailure
        }
    }
}

private final class MSALNativeAuthMFARedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

internal struct MSALNativeAuthMFAGraphClient: Sendable {
    let transport: any MSALNativeAuthMFATransporting

    func deleteRegistration(endpoint: URL, accessToken: String) async throws {
        try MSALNativeAuthMFAEndpoint.Policy.graphDeletion.validate(endpoint)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        MSALNativeAuthMFARequestHeaders.apply(to: &request)
        _ = try await transport.send(request, endpointPolicy: MSALNativeAuthMFAEndpoint.Policy.graphDeletion)
    }
}

internal enum MSALNativeAuthMFARequestHeaders {
    static func apply(to request: inout URLRequest) {
        request.setValue((MSALNativeAuthMFARequestContext.correlationId ?? UUID()).uuidString, forHTTPHeaderField: "client-request-id")
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "AppName")
        request.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, forHTTPHeaderField: "AppVersion")
    }
}
