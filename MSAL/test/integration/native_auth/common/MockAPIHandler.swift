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

import XCTest

class MockAPIHandler {
    
    private let baseURL = (ProcessInfo.processInfo.environment["authorityURL"] ?? "<mock api url not set>") + "/config/"

    func clearQueues(correlationId: UUID) throws {
        guard let url = URL(string: baseURL + "all") else {
            XCTFail("Invalid Delete URL")
            throw MockAPIError.invalidURL
        }
        guard let body = try? JSONEncoder().encode(ClearQueueRequestBody(correlationId: correlationId)) else {
            XCTFail("Invalid Request")
            throw MockAPIError.invalidRequest
        }
        Task {
            try await performHTTPCall(url: url, body: body, httpMethod: "DELETE")
        }
    }
    
    func getAllConfig() async throws -> [String: Any] {
        guard let url = URL(string: baseURL + "all") else {
            XCTFail("Invalid get all config URL")
            throw MockAPIError.invalidURL
        }
        let result = try await performHTTPCall(url: url)
        return try JSONSerialization.jsonObject(with: result, options: []) as? [String: Any] ?? [:]
    }
    
    func addResponse(endpoint: MockAPIEndpoint, correlationId: UUID, responses: [MockAPIResponse]) async throws {
        guard let url = URL(string: baseURL + "response") else {
            XCTFail("Invalid add response URL")
            throw MockAPIError.invalidURL
        }
        guard let body = try? JSONEncoder().encode(
            AddResponsesRequestBody(endpoint: endpoint.rawValue, responseList: responses.map({$0.rawValue}), correlationId: correlationId)
        ) else {
            XCTFail("Invalid Request")
            throw MockAPIError.invalidRequest
        }
        _ = try await performHTTPCall(url: url, body: body, httpMethod: "POST")
    }
    
    private func performHTTPCall(url: URL, body: Data? = nil, httpMethod: String = "GET") async throws -> Data {
        var request = URLRequest(url: url)
        request.httpBody = body
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MockAPIError.invalidServerResponse
        }
        return data
    }
}
