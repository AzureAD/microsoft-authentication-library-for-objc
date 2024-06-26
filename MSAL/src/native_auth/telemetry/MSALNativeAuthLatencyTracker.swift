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
    typealias LatencyFlow = (id: MSALNativeAuthTelemetryApiId, latency: Int)

    func start(id: MSALNativeAuthTelemetryApiId)
    func stop(id: MSALNativeAuthTelemetryApiId)
    func dispatchNext() -> LatencyFlow?
}

final class MSALNativeAuthLatencyTracker: MSALNativeAuthLatencyTracking {

    static var shared = MSALNativeAuthLatencyTracker()

    // [id: startTime]
    private var runningTrackers: [MSALNativeAuthTelemetryApiId: Date] = [:]

    // [(id, latencyMs)]
    private var latenciesQueue: [LatencyFlow] = []

    private init() {}

    func start(id: MSALNativeAuthTelemetryApiId) {
        runningTrackers[id] = .init()
    }

    func stop(id: MSALNativeAuthTelemetryApiId) {
        guard let startTime = runningTrackers[id] else {
            MSALLogger.log(level: .error, context: MSIDBasicContext(), format: "LatencyTracker for \(id) has not been started!")
            return
        }

        let difference = calculateDiff(endTime: Date(), startTime: startTime)
        latenciesQueue.enqueue((id, difference))
    }

    func dispatchNext() -> LatencyFlow? {
        latenciesQueue.dequeue()
    }

    private func calculateDiff(endTime: Date, startTime: Date) -> Int {
        let differenceMs = endTime.timeIntervalSince(startTime) * 1000
        return Int(differenceMs)
    }
}

// TODO: Create a proper Queue class
private extension Array where Element == MSALNativeAuthLatencyTracking.LatencyFlow {

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
