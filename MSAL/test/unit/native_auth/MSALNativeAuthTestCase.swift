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
@_implementationOnly import MSAL_Private

class MSALNativeAuthTestCase: XCTestCase {
    //Do not create more than one instance of this variable, inherit this class instead
    static let logger = MSALNativeAuthTestLogger()
    var dispatcher: MSALNativeAuthTelemetryTestDispatcher!
    var receivedEvents: [[AnyHashable: Any]] = []

    override func setUpWithError() throws {
        // Logger needs to reset so the expectation name and count resets from the previous test
        // The previous test could be across class
        Self.logger.reset()

        dispatcher = MSALNativeAuthTelemetryTestDispatcher()

        dispatcher.setTestCallback { event in
            self.receivedEvents.append(event.propertyMap)
        }

        MSIDTelemetry.sharedInstance().add(dispatcher)
    }

    override func tearDown() {
        // Logger needs to reset so the expectation name and count resets for the next test.
        // The next test could be across classes
        Self.logger.reset()

        receivedEvents.removeAll()
        MSIDTelemetry.sharedInstance().remove(dispatcher)
    }
}
