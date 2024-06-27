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

protocol MSALNativeAuthLatencyTracking {
    func start(id: MSALNativeAuthTelemetryApiId)
    func stop(id: MSALNativeAuthTelemetryApiId)
    func dispatchNext() -> LatencyEvent?
}

struct LatencyEvent: Hashable, Codable {
    static let EventKey = "nativeauth_latency_key_"

    let id: MSALNativeAuthTelemetryApiId // create separate classes for Api, Cache, etc.
    let startDate: Date
    var endDate: Date?

    // TODO: Test thoroughly
    var latency: String {
        guard let endDate else { return "" }
        let difference = endDate.timeIntervalSince(startDate) * 1000
        return String(format: "%.0f", difference)
    }

    var userDefaultsKey: String {
        "\(Self.EventKey)\(id)"
    }
}

final class MSALNativeAuthLatencyTracker: MSALNativeAuthLatencyTracking {

    static var shared = MSALNativeAuthLatencyTracker()

    private let userDefaults: UserDefaults
    private var unfinishedEvents: Set<LatencyEvent> = []
    private var queue: [LatencyEvent] = []

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        lookupStoredEvents()
    }

    func start(id: MSALNativeAuthTelemetryApiId) {
        let event = LatencyEvent(id: id, startDate: .init())
        unfinishedEvents.insert(event)
    }

    func stop(id: MSALNativeAuthTelemetryApiId) {
        guard var event = unfinishedEvents.first(where: { $0.id == id }) else {
            return
        }

        unfinishedEvents.remove(event)
        event.endDate = .init()

        persistEvent(event)
        queue.enqueue(event)
    }

    // TODO: Create a function that dequeues the first 8-10 finished events in batch?
    func dispatchNext() -> LatencyEvent? {
        guard let event = queue.dequeue() else {
            return nil
        }

        userDefaults.removeObject(forKey: event.userDefaultsKey)
        return event
    }

    private func lookupStoredEvents() {
        let events = MSALNativeAuthTelemetryApiId.allCases.compactMap {
            let key = "\(LatencyEvent.EventKey)\($0)"
            return retrieveEvent(key)
        }

        for event in events {
            if !queue.contains(where: {$0.id == event.id}) {
                queue.enqueue(event)
            }
        }
    }

    private func persistEvent(_ event: LatencyEvent) {
        let encoder = JSONEncoder()

        do {
            let data = try encoder.encode(event)
            userDefaults.set(data, forKey: event.userDefaultsKey)
        } catch {
            MSALLogger.log(
                level: .error,
                context: MSALNativeAuthRequestContext(),
                format: "Error encoding cached event"
            )
        }
    }

    private func retrieveEvent(_ key: String) -> LatencyEvent? {
        let decoder = JSONDecoder()

        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(LatencyEvent.self, from: data)
        } catch {
            MSALLogger.log(
                level: .error,
                context: MSALNativeAuthRequestContext(),
                format: "Error decoding cached event"
            )

            return nil
        }
    }
}

// TODO: Create a proper Queue class
private extension Array where Element == LatencyEvent {

    mutating func enqueue(_ element: Element) {
        append(element)
    }

    mutating func dequeue() -> Element? {
        guard !isEmpty else {
            return nil
        }
        return removeFirst()
    }
}
