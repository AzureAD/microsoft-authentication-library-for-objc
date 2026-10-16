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
import XCTest

final class MailTMHTTPClientTests: XCTestCase {
    func test_throttledRequest_waitsOneSecondAndRetriesSameRequest() async throws {
        let session = StubSession(statuses: [429, 201])
        let client = MailTMHTTPClient(baseURLString: "https://mail.example", dataForRequest: session.data)

        let result = await client.sendJSON(
            path: "/accounts",
            method: MailTMHTTPClient.HTTPMethod.post,
            authorizationToken: "test-token",
            jsonBody: ["address": "test@example.com", "password": "test-password"]
        )

        XCTAssertEqual(result?.status, 201)
        XCTAssertEqual((result?.json as? [String: Int])?["status"], 201)
        XCTAssertEqual(session.requests.count, 2)
        let firstRequest = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(firstRequest.httpMethod, "POST")
        XCTAssertEqual(firstRequest.url?.path, "/accounts")
        XCTAssertEqual(firstRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(session.requests.last, firstRequest)
        assertOneSecondBetweenAttempts(session)
    }

    func test_repeatedThrottling_stopsAfterThreeRetriesAndReturnsLastResponse() async {
        let session = StubSession(statuses: [429, 429, 429, 429])
        let client = MailTMHTTPClient(baseURLString: "https://mail.example", dataForRequest: session.data)

        let result = await client.sendJSON(path: "/accounts")

        XCTAssertEqual(result?.status, 429)
        XCTAssertEqual((result?.json as? [String: Int])?["status"], 429)
        XCTAssertEqual(session.requests.count, 4)
        assertOneSecondBetweenAttempts(session)
    }

    func test_nonThrottledResponses_areNotRetried() async {
        for status in [200, 201, 400, 401, 422, 500] {
            let session = StubSession(statuses: [status])
            let client = MailTMHTTPClient(baseURLString: "https://mail.example", dataForRequest: session.data)

            let result = await client.sendJSON(path: "/accounts")

            XCTAssertEqual(result?.status, status)
            XCTAssertEqual(session.requests.count, 1)
        }
    }

    func test_transportFailure_isNotRetried() async {
        let session = StubSession(statuses: [], error: URLError(.notConnectedToInternet))
        let client = MailTMHTTPClient(baseURLString: "https://mail.example", dataForRequest: session.data)

        let result = await client.sendJSON(path: "/accounts")

        XCTAssertNil(result)
        XCTAssertEqual(session.requests.count, 1)
    }

    func test_cancellationDuringRetryDelay_stopsWithoutAnotherRequest() async {
        let session = StubSession(statuses: [429])
        let client = MailTMHTTPClient(baseURLString: "https://mail.example", dataForRequest: session.data)

        let task = Task {
            await client.sendJSON(path: "/accounts")
        }
        await fulfillment(of: [session.firstRequest], timeout: 5)
        task.cancel()
        let result = await task.value

        XCTAssertNil(result)
        XCTAssertEqual(session.requests.count, 1)
    }

    private func assertOneSecondBetweenAttempts(
        _ session: StubSession,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (previous, next) in zip(session.requestTimes, session.requestTimes.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next - previous, 1, file: file, line: line)
        }
    }

    // Each test owns a session; sendJSON awaits each request before issuing the next.
    private final class StubSession {
        let statuses: [Int]
        let error: Error?
        let firstRequest = XCTestExpectation(description: "first HTTP request")
        var requests: [URLRequest] = []
        var requestTimes: [TimeInterval] = []

        init(statuses: [Int], error: Error? = nil) {
            self.statuses = statuses
            self.error = error
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            requestTimes.append(ProcessInfo.processInfo.systemUptime)
            if requests.count == 1 {
                firstRequest.fulfill()
            }
            if let error {
                throw error
            }
            guard requests.count <= statuses.count else {
                XCTFail("Unexpected extra HTTP request")
                throw URLError(.badServerResponse)
            }
            let status = statuses[requests.count - 1]
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = try JSONSerialization.data(withJSONObject: ["status": status])
            return (data, response)
        }
    }
}
