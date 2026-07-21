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

/// Runs an async operation with progressive delays between attempts until it yields a non-nil
/// result or the attempts are exhausted. Extracted (per PR #3040 review feedback) so the
/// polling/backoff schedule is a single reusable component.
struct RetryExecutor {

    /// Delays (seconds) applied between attempts. The last value is reused if attempts exceed its count.
    let delays: [Double]

    /// - Parameters:
    ///   - maxAttempts: total number of times `operation` is invoked.
    ///   - operation: async work returning an optional result; the first non-nil value stops the loop.
    func execute<T>(maxAttempts: Int, operation: () async -> T?) async -> T? {
        guard maxAttempts > 0 else {
            return nil
        }
        for attempt in 1...maxAttempts {
            if let result = await operation() {
                return result
            }
            if attempt < maxAttempts, !delays.isEmpty {
                let delay = delays[min(attempt - 1, delays.count - 1)]
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * Double(NSEC_PER_SEC)))
                } catch {
                    // The task was cancelled (e.g. XCTest timeout); stop retrying immediately
                    // rather than continuing to poll the API.
                    return nil
                }
            }
        }
        return nil
    }
}
