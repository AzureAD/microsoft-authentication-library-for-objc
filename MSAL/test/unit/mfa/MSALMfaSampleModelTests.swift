//------------------------------------------------------------------------------
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
//------------------------------------------------------------------------------

import XCTest
import MSAL

@MainActor
final class MSALMfaSampleModelTests: XCTestCase
{
    func testInitialListIsEmptyAndValidationRequiresBothFields()
    {
        let model = MSALMfaSampleModel()
        XCTAssertTrue(model.registrations.isEmpty)
        XCTAssertFalse(model.isRegistering)
        XCTAssertNil(model.validationError)
        XCTAssertFalse(MSALMfaSampleModel.canFinish(name: "", secret: "synthetic"))
        XCTAssertFalse(MSALMfaSampleModel.canFinish(name: " \n", secret: "synthetic"))
        XCTAssertFalse(MSALMfaSampleModel.canFinish(name: "Demo", secret: "\n "))
        XCTAssertTrue(MSALMfaSampleModel.canFinish(name: " Demo ", secret: "synthetic"))
    }

    func testInvalidManualInputDoesNotActivate() async
    {
        var calls = 0
        let model = MSALMfaSampleModel
        { parameters in
            calls += 1
            return await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: parameters)
        }
        let missingName = await model.finishManualEntry(name: " ", secret: "synthetic")
        XCTAssertFalse(missingName)
        XCTAssertEqual(model.validationError, .missingName)
        let missingSecret = await model.finishManualEntry(name: "Demo", secret: "\n")
        XCTAssertFalse(missingSecret)
        XCTAssertEqual(model.validationError, .missingSecret)
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testSimulatedScanAddsUniqueMockRows() async
    {
        let model = MSALMfaSampleModel()
        let first = await model.simulateScan()
        let second = await model.simulateScan()
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(model.registrations.count, 2)
        XCTAssertEqual(Set(model.registrations.map(\.id)).count, 2)
        XCTAssertTrue(model.registrations.allSatisfy { $0.source == .simulatedScan })
        XCTAssertFalse(model.isRegistering)
        XCTAssertTrue(MSALMfaSampleModel().registrations.isEmpty)
    }

    func testManualEntryOnlySubmitsSyntheticQRAndRetainsDisplayMetadata() async throws
    {
        var submittedQR: String?
        let model = MSALMfaSampleModel
        { parameters in
            submittedQR = parameters.qrCode
            return await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: parameters)
        }
        let added = await model.finishManualEntry(name: " Demo account \n", secret: "synthetic-only-secret")
        XCTAssertTrue(added)
        XCTAssertEqual(submittedQR, "mock-qr-activation")
        let registration = try XCTUnwrap(model.registrations.first)
        XCTAssertEqual(registration.name, "Demo account")
        XCTAssertEqual(registration.source, .manualEntry)
        XCTAssertEqual(Set(Mirror(reflecting: registration).children.compactMap(\.label)), ["id", "name", "source"])
        XCTAssertNil(model.validationError)
    }

    func testDuplicateSubmissionIsIgnoredWhileActivationIsPending() async
    {
        let gate = ActivationGate()
        let model = MSALMfaSampleModel(activate: gate.activate)
        let first = Task { await model.simulateScan() }
        await fulfillment(of: [gate.started], timeout: 2)
        XCTAssertTrue(model.isRegistering)
        let duplicate = await model.simulateScan()
        XCTAssertFalse(duplicate)
        XCTAssertEqual(gate.calls, 1)
        gate.resume()
        let added = await first.value
        XCTAssertTrue(added)
        XCTAssertEqual(model.registrations.count, 1)
    }

    func testCancelIgnoresLateCompletionAndAllowsNewRegistration() async
    {
        let gate = ActivationGate()
        let model = MSALMfaSampleModel(activate: gate.activate)
        let first = Task { await model.simulateScan() }
        await fulfillment(of: [gate.started], timeout: 2)
        model.cancelRegistration()
        XCTAssertFalse(model.isRegistering)
        gate.resume()
        let canceled = await first.value
        XCTAssertFalse(canceled)
        XCTAssertTrue(model.registrations.isEmpty)
        let added = await model.finishManualEntry(name: "New demo", secret: "synthetic")
        XCTAssertTrue(added)
        XCTAssertEqual(model.registrations.count, 1)
        XCTAssertEqual(model.registrations.first?.name, "New demo")
    }

    func testCanceledTaskDoesNotAppendARow() async
    {
        let gate = ActivationGate()
        let model = MSALMfaSampleModel(activate: gate.activate)
        let operation = Task { await model.simulateScan() }
        await fulfillment(of: [gate.started], timeout: 2)
        operation.cancel()
        gate.resume()
        let added = await operation.value
        XCTAssertFalse(added)
        XCTAssertFalse(model.isRegistering)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testOldCompletionDoesNotEndNewRegistration() async
    {
        let oldGate = ActivationGate()
        let newGate = ActivationGate()
        var calls = 0
        let model = MSALMfaSampleModel
        { parameters in
            calls += 1
            return await (calls == 1 ? oldGate : newGate).activate(parameters)
        }
        let oldOperation = Task { await model.simulateScan() }
        await fulfillment(of: [oldGate.started], timeout: 2)
        model.cancelRegistration()
        let newOperation = Task { await model.finishManualEntry(name: "New demo", secret: "synthetic") }
        await fulfillment(of: [newGate.started], timeout: 2)
        oldGate.resume()
        let oldAdded = await oldOperation.value
        XCTAssertFalse(oldAdded)
        XCTAssertTrue(model.isRegistering)
        XCTAssertTrue(model.registrations.isEmpty)
        newGate.resume()
        let newAdded = await newOperation.value
        XCTAssertTrue(newAdded)
        XCTAssertFalse(model.isRegistering)
        XCTAssertEqual(model.registrations.map(\.name), ["New demo"])
    }
}

@MainActor
private final class ActivationGate
{
    let started = XCTestExpectation(description: "Mock activation started")
    private(set) var calls = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func activate(_ parameters: MSALNativeAuthMfaSdkRegistrationParameters) async -> MSALNativeAuthMfaSdkRegistrationResult
    {
        calls += 1
        if !isReleased
        {
            await withCheckedContinuation
            { continuation in
                self.continuation = continuation
                started.fulfill()
            }
        }
        return await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: parameters)
    }

    func resume()
    {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}
