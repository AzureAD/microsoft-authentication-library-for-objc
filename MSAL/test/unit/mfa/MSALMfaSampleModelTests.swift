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
import UIKit
import SwiftUI

@MainActor
final class MSALMfaSampleModelTests: XCTestCase
{
    private enum RequestError: Error
    {
        case failed
    }

    func testCameraDeliversOneUnmodifiedQRCodePerAttempt()
    {
        var received: [String] = []
        let scanner = MSALMfaSampleCameraScanner.Coordinator(onCode: { received.append($0) }, onError: { XCTFail() })
        scanner.isEnabled = true
        XCTAssertFalse(scanner.receiveCode(" \n"))
        let code = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&issuer=Test"
        XCTAssertTrue(scanner.receiveCode(code))
        XCTAssertFalse(scanner.receiveCode(code))
        XCTAssertFalse(scanner.receiveCode("another-code"))
        XCTAssertEqual(received, [code])
        XCTAssertFalse(scanner.canScan)
    }

    func testInactiveAndInvalidatedCameraDiscardsResults()
    {
        let scanner = MSALMfaSampleCameraScanner.Coordinator(onCode: { _ in XCTFail() }, onError: { XCTFail() })
        XCTAssertFalse(scanner.receiveCode("scanned-code"))
        scanner.isEnabled = true
        scanner.invalidate()
        XCTAssertFalse(scanner.receiveCode("late-code"))
        XCTAssertFalse(scanner.canScan)
    }

    func testCameraFailureIsReportedOnceAndStopsFurtherDelivery() async
    {
        let failure = expectation(description: "Camera failure reported")
        failure.assertForOverFulfill = true
        let scanner = MSALMfaSampleCameraScanner.Coordinator(onCode: { _ in XCTFail() }, onError: { failure.fulfill() })
        scanner.isEnabled = true
        scanner.reportFailure()
        scanner.reportFailure()
        XCTAssertFalse(scanner.receiveCode("late-code"))
        await fulfillment(of: [failure], timeout: 2)
    }

    func testCameraTeardownDiscardsQueuedFailure() async
    {
        let scanner = MSALMfaSampleCameraScanner.Coordinator(onCode: { _ in XCTFail() }, onError: { XCTFail() })
        scanner.isEnabled = true
        scanner.reportFailure()
        scanner.invalidate()
        let drained = expectation(description: "Main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
    }

    func testEmptyQRCodeDoesNotCallSDK() async
    {
        let model = MSALMfaSampleModel(activate: { _ in
            XCTFail("Empty camera input must not reach activation")
            throw RequestError.failed
        })
        let added = await model.registerQRCode(" \n")
        XCTAssertFalse(added)
        XCTAssertEqual(model.validationError, .missingQRCode)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testRegistrationFailureSurfacesErrorAndAllowsRetry() async
    {
        var calls = 0
        let model = MSALMfaSampleModel(activate: { parameters in
            calls += 1
            if calls == 1 { throw RequestError.failed }
            return try await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: parameters)
        })
        let failed = await model.registerQRCode("scanned-code")
        XCTAssertFalse(failed)
        XCTAssertEqual(model.validationError, .registrationFailed)
        XCTAssertFalse(model.isRegistering)
        XCTAssertTrue(model.registrations.isEmpty)
        let retried = await model.registerQRCode("scanned-code")
        XCTAssertTrue(retried)
        XCTAssertNil(model.validationError)
        XCTAssertEqual(calls, 2)
    }

    func testManualRegistrationFailureDoesNotAddAccount() async
    {
        let model = MSALMfaSampleModel(addThirdPartyAccount: { _ in throw RequestError.failed })
        let added = await model.finishManualEntry(name: "Account", secret: "test-key")
        XCTAssertFalse(added)
        XCTAssertEqual(model.validationError, .registrationFailed)
        XCTAssertFalse(model.isRegistering)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testRefreshFailureDoesNotPresentSignInPrompt() async
    {
        let model = MSALMfaSampleModel(loadChallenges: { throw RequestError.failed })
        await model.refreshChallengeFromAccounts()
        XCTAssertNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertEqual(model.challengeStatus, .requestFailed)
    }

    func testResponseFailureDoesNotReportApproval() async throws
    {
        let model = MSALMfaSampleModel(respond: { _, _, _ in throw RequestError.failed })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: "42"))
        await response.value
        XCTAssertEqual(model.challengeStatus, .requestFailed)
        XCTAssertFalse(model.isRespondingToChallenge)
    }

    func testRepeatedRegistrationUsesSDKIdentityInsteadOfAddingDuplicateRows() async throws
    {
        let result = try await MSALNativeAuthMfaSdkManager().activateMfaAccount(
            registrationParameters: MSALNativeAuthMfaSdkRegistrationParameters(qrCode: "scanned-code")
        )
        let model = MSALMfaSampleModel(activate: { _ in result })
        let first = await model.registerQRCode("scanned-code")
        let second = await model.registerQRCode("scanned-code")
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(model.registrations.map(\.id), [result.registrationId])
    }

    func testHostedAccountsRefreshEndsIndicatorBeforeAlertAndAfterBothDecisions() async throws
    {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let model = MSALMfaSampleModel()
        let controller = UIHostingController(rootView: MSALMfaSampleAccountsView(model: model))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer
        {
            model.cancelChallengeFlow()
            controller.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKeyAndVisible()
        }

        let mounted = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.challengePresenter(in: controller)?.viewIfLoaded?.window != nil
            },
            object: nil
        )
        await fulfillment(of: [mounted], timeout: 3)
        let presenter = try XCTUnwrap(challengePresenter(in: controller))
        let refreshControl = presenter.refreshControl
        refreshControl.beginRefreshing()
        presenter.scrollView.setContentOffset(CGPoint(x: 0, y: -120), animated: false)
        refreshControl.sendActions(for: .valueChanged)
        let presented = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.presentedAlert(in: controller).map { !$0.isBeingPresented } ?? false
            },
            object: nil
        )
        await fulfillment(of: [presented], timeout: 3)
        let alert = try XCTUnwrap(presentedAlert(in: controller))
        XCTAssertFalse(refreshControl.isRefreshing)
        XCTAssertEqual(refreshControl.alpha, 0)
        XCTAssertEqual(presenter.scrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertNotNil(model.challengePrompt)
        let session = try XCTUnwrap(model.challengePrompt?.session)
        XCTAssertTrue(alert.message?.hasPrefix("\(session.accountName)\n\(session.username)\n\n") == true)
        XCTAssertEqual(alert.preferredStyle, .alert)
        XCTAssertEqual(alert.actions.count, 2)
        XCTAssertEqual(alert.actions.first?.style, .destructive)
        let yes = try XCTUnwrap(alert.actions.last)
        XCTAssertFalse(yes.isEnabled)
        let field = try XCTUnwrap(alert.textFields?.first)
        field.text = "7"
        field.sendActions(for: .editingChanged)
        XCTAssertTrue(yes.isEnabled)
        field.text = "not a number"
        field.sendActions(for: .editingChanged)
        XCTAssertFalse(yes.isEnabled)
        refreshControl.beginRefreshing()
        refreshControl.sendActions(for: .valueChanged)
        let duplicateRefreshEnded = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in !refreshControl.isRefreshing },
            object: nil
        )
        await fulfillment(of: [duplicateRefreshEnded], timeout: 3)
        XCTAssertTrue(presentedAlert(in: controller) === alert)

        let prompt = try XCTUnwrap(model.challengePrompt)
        let denial = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: false, number: ""))
        await denial.value
        let dismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in self.presentedAlert(in: controller) == nil },
            object: nil
        )
        await fulfillment(of: [dismissed], timeout: 3)
        XCTAssertEqual(model.challengeStatus, .denied)
        XCTAssertFalse(refreshControl.isRefreshing)
        XCTAssertEqual(refreshControl.alpha, 0)
        XCTAssertEqual(presenter.scrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertEqual(field.text, "")
        refreshControl.beginRefreshing()
        presenter.scrollView.setContentOffset(CGPoint(x: 0, y: -120), animated: false)
        refreshControl.sendActions(for: .valueChanged)
        let presentedAgain = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.presentedAlert(in: controller).map { !$0.isBeingPresented } ?? false
            },
            object: nil
        )
        await fulfillment(of: [presentedAgain], timeout: 3)
        XCTAssertFalse(presentedAlert(in: controller) === alert)
        XCTAssertEqual(presenter.scrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertFalse(refreshControl.isRefreshing)
        XCTAssertEqual(refreshControl.alpha, 0)
        XCTAssertNotNil(model.challengePrompt)
        let nextPrompt = try XCTUnwrap(model.challengePrompt)
        let approval = try XCTUnwrap(model.respondToChallenge(id: nextPrompt.id, approve: true, number: "7"))
        await approval.value
        let approvedAlertDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in self.presentedAlert(in: controller) == nil },
            object: nil
        )
        await fulfillment(of: [approvedAlertDismissed], timeout: 3)
        XCTAssertEqual(model.challengeStatus, .approved)
        XCTAssertEqual(presenter.scrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertFalse(refreshControl.isRefreshing)
        XCTAssertEqual(refreshControl.alpha, 0)
    }

    func testCancelingAccountsRefreshEndsIndicatorAndDiscardsDelayedChallenge() async throws
    {
        let gate = ChallengeGate()
        let returned = expectation(description: "Canceled loader returned")
        let model = MSALMfaSampleModel(loadChallenges:
        {
            await gate.wait()
            let sessions = try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
            returned.fulfill()
            return sessions
        })
        let controller = MSALMfaSampleChallengeAlertController(model: model, content: AnyView(Text("Accounts")))
        { _, _, _ in
            XCTFail("Canceling refresh must not submit a response")
        }
        controller.loadViewIfNeeded()
        controller.refreshControl.beginRefreshing()
        controller.scrollView.setContentOffset(CGPoint(x: 0, y: -120), animated: false)
        controller.refreshControl.sendActions(for: .valueChanged)
        await fulfillment(of: [gate.started], timeout: 3)
        XCTAssertTrue(controller.refreshControl.isRefreshing)
        XCTAssertEqual(controller.refreshControl.alpha, 1)
        controller.cancelRefresh()
        XCTAssertEqual(controller.scrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertFalse(controller.refreshControl.isRefreshing)
        XCTAssertEqual(controller.refreshControl.alpha, 0)
        XCTAssertFalse(model.isLoadingChallenge)
        gate.resume()
        await fulfillment(of: [returned], timeout: 3)
        XCTAssertNil(model.challengePrompt)
        XCTAssertFalse(controller.refreshControl.isRefreshing)
    }

    func testRefreshWaitsForDragReleaseBeforeLoadingChallenge() async
    {
        let gate = ChallengeGate()
        var calls = 0
        let model = MSALMfaSampleModel(loadChallenges:
        {
            calls += 1
            await gate.wait()
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        })
        let controller = MSALMfaSampleChallengeAlertController(model: model, content: AnyView(Text("Accounts")))
        { _, _, _ in
            XCTFail("Pulling to refresh must not submit a response")
        }
        controller.loadViewIfNeeded()
        controller.scrollViewWillBeginDragging(controller.scrollView)
        controller.refreshControl.beginRefreshing()
        controller.scrollView.setContentOffset(CGPoint(x: 0, y: -120), animated: false)
        controller.refreshControl.sendActions(for: .valueChanged)
        controller.refreshControl.sendActions(for: .valueChanged)
        controller.synchronizePresentation()
        XCTAssertTrue(controller.isRefreshPending)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertNil(model.challengePrompt)
        XCTAssertNil(controller.presentedViewController)
        XCTAssertEqual(controller.scrollView.contentOffset.y, -120, accuracy: 0.5)
        XCTAssertEqual(calls, 0)

        controller.scrollViewDidEndDragging(controller.scrollView, willDecelerate: true)
        XCTAssertFalse(controller.isRefreshPending)
        await fulfillment(of: [gate.started], timeout: 3)
        XCTAssertEqual(calls, 1)
        gate.resume()
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in model.challengePrompt != nil && !controller.refreshControl.isRefreshing },
            object: nil
        )
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(controller.scrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertEqual(controller.refreshControl.alpha, 0)
        controller.cancelRefresh()
    }

    func testCancelingQueuedRefreshPreventsRequestOnRelease()
    {
        let model = MSALMfaSampleModel()
        let controller = MSALMfaSampleChallengeAlertController(model: model, content: AnyView(Text("Accounts")))
        { _, _, _ in
            XCTFail("Canceling the gesture must not submit a response")
        }
        controller.loadViewIfNeeded()
        controller.scrollViewWillBeginDragging(controller.scrollView)
        controller.refreshControl.beginRefreshing()
        controller.refreshControl.sendActions(for: .valueChanged)
        XCTAssertTrue(controller.isRefreshPending)
        controller.cancelRefresh()
        controller.scrollViewDidEndDragging(controller.scrollView, willDecelerate: false)
        XCTAssertFalse(controller.isRefreshPending)
        XCTAssertFalse(controller.refreshControl.isRefreshing)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertNil(model.challengePrompt)
    }

    private func presentedAlert(in controller: UIViewController) -> UIAlertController?
    {
        if let alert = controller.presentedViewController as? UIAlertController
        {
            return alert
        }
        for child in controller.children
        {
            if let alert = presentedAlert(in: child)
            {
                return alert
            }
        }
        return nil
    }

    private func challengePresenter(in controller: UIViewController) -> MSALMfaSampleChallengeAlertController?
    {
        if let presenter = controller as? MSALMfaSampleChallengeAlertController
        {
            return presenter
        }
        for child in controller.children
        {
            if let presenter = challengePresenter(in: child)
            {
                return presenter
            }
        }
        return nil
    }

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
        let model = MSALMfaSampleModel(activate:
        { parameters in
            calls += 1
            return try await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: parameters)
        }, addThirdPartyAccount: { parameters in
            calls += 1
            return try await MSALNativeAuthMfaSdkManager().addThirdPartyAccount(registrationParameters: parameters)
        })
        let missingName = await model.finishManualEntry(name: " ", secret: "synthetic")
        XCTAssertFalse(missingName)
        XCTAssertEqual(model.validationError, .missingName)
        let missingSecret = await model.finishManualEntry(name: "Demo", secret: "\n")
        XCTAssertFalse(missingSecret)
        XCTAssertEqual(model.validationError, .missingSecret)
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testScannedQRCodesAddUniqueRows() async
    {
        let model = MSALMfaSampleModel()
        let first = await model.registerQRCode("scanned-qr-payload")
        let second = await model.registerQRCode("scanned-qr-payload")
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(model.registrations.count, 2)
        XCTAssertEqual(Set(model.registrations.map(\.id)).count, 2)
        XCTAssertTrue(model.registrations.allSatisfy { $0.source == .qrCode })
        XCTAssertFalse(model.isRegistering)
        XCTAssertTrue(MSALMfaSampleModel().registrations.isEmpty)
    }

    func testScannedQRCodeIsForwardedUnchangedAndUsesSDKAccountName() async throws
    {
        var submittedQR: String?
        let manager = MSALNativeAuthMfaSdkManager()
        let scannedCode = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&issuer=Test"
        var returnedName: String?
        let model = MSALMfaSampleModel(activate:
        { parameters in
            submittedQR = parameters.qrCode
            let result = try await manager.activateMfaAccount(registrationParameters: parameters)
            returnedName = result.accountName
            return result
        }, addThirdPartyAccount: { parameters in
            XCTFail("Scanning must not call the manual account API")
            return try await manager.addThirdPartyAccount(registrationParameters: parameters)
        })
        let added = await model.registerQRCode(scannedCode)
        XCTAssertTrue(added)
        XCTAssertEqual(submittedQR, scannedCode)
        let registration = try XCTUnwrap(model.registrations.first)
        XCTAssertEqual(registration.name, returnedName)
        XCTAssertEqual(registration.source, .qrCode)
    }

    func testManualEntryPassesExactNameAndSecretToSDKWithoutQR() async throws
    {
        var submittedName: String?
        var submittedSecret: String?
        var calls = 0
        let model = MSALMfaSampleModel(activate:
        { parameters in
            XCTFail("Manual entry must not call QR activation")
            return try await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: parameters)
        }, addThirdPartyAccount: { parameters in
            calls += 1
            submittedName = parameters.accountName
            submittedSecret = parameters.secretKey
            return try await MSALNativeAuthMfaSdkManager().addThirdPartyAccount(registrationParameters: parameters)
        })
        let added = await model.finishManualEntry(name: " Entered account \n", secret: " synthetic-only-secret \n")
        XCTAssertTrue(added)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(submittedName, " Entered account \n")
        XCTAssertEqual(submittedSecret, " synthetic-only-secret \n")
        let registration = try XCTUnwrap(model.registrations.first)
        XCTAssertEqual(registration.name, "Entered account")
        XCTAssertEqual(registration.source, .manualEntry)
        XCTAssertEqual(Set(Mirror(reflecting: registration).children.compactMap(\.label)), ["id", "name", "source"])
        XCTAssertNil(model.validationError)
    }

    func testManualEntryDisplaysSDKResultRatherThanSubmittedName() async
    {
        let model = MSALMfaSampleModel(addThirdPartyAccount:
        { _ in
            try await MSALNativeAuthMfaSdkManager().addThirdPartyAccount(
                registrationParameters: MSALNativeAuthMfaSdkManualRegistrationParameters(
                    accountName: "SDK display name",
                    secretKey: "synthetic"
                )
            )
        })
        let added = await model.finishManualEntry(name: "Entered account", secret: "synthetic")
        XCTAssertTrue(added)
        XCTAssertEqual(model.registrations.first?.name, "SDK display name")
    }

    func testIncompleteSDKRegistrationDoesNotAddRow() async
    {
        let model = MSALMfaSampleModel(addThirdPartyAccount:
        { _ in
            try await MSALNativeAuthMfaSdkManager().addThirdPartyAccount(
                registrationParameters: MSALNativeAuthMfaSdkManualRegistrationParameters(
                    accountName: "",
                    secretKey: "synthetic"
                )
            )
        })
        let added = await model.finishManualEntry(name: "Entered account", secret: "synthetic")
        XCTAssertFalse(added)
        XCTAssertTrue(model.registrations.isEmpty)
        XCTAssertEqual(model.validationError, .unexpectedResult)
        XCTAssertFalse(model.isRegistering)
    }

    func testManualRegistrationBlocksDuplicateAndScanWhilePending() async
    {
        let gate = ActivationGate()
        let model = MSALMfaSampleModel(activate: gate.activate, addThirdPartyAccount: gate.addThirdPartyAccount)
        let operation = Task { await model.finishManualEntry(name: "Entered account", secret: "synthetic") }
        await fulfillment(of: [gate.started], timeout: 2)
        let duplicate = await model.finishManualEntry(name: "Duplicate", secret: "synthetic")
        let scan = await model.registerQRCode("scanned-qr-payload")
        XCTAssertFalse(duplicate)
        XCTAssertFalse(scan)
        XCTAssertEqual(gate.calls, 1)
        gate.resume()
        let added = await operation.value
        XCTAssertTrue(added)
        XCTAssertEqual(model.registrations.map(\.name), ["Entered account"])
    }

    func testDuplicateSubmissionIsIgnoredWhileActivationIsPending() async
    {
        let gate = ActivationGate()
        let model = MSALMfaSampleModel(activate: gate.activate)
        let first = Task { await model.registerQRCode("scanned-qr-payload") }
        await fulfillment(of: [gate.started], timeout: 2)
        XCTAssertTrue(model.isRegistering)
        let duplicate = await model.registerQRCode("scanned-qr-payload")
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
        let first = Task { await model.registerQRCode("scanned-qr-payload") }
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
        let model = MSALMfaSampleModel(addThirdPartyAccount: gate.addThirdPartyAccount)
        let operation = Task { await model.finishManualEntry(name: "Entered account", secret: "synthetic") }
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
        let model = MSALMfaSampleModel(activate:
        { parameters in
            calls += 1
            return try await (calls == 1 ? oldGate : newGate).activate(parameters)
        }, addThirdPartyAccount: { parameters in
            calls += 1
            return try await (calls == 1 ? oldGate : newGate).addThirdPartyAccount(parameters)
        })
        let oldOperation = Task { await model.registerQRCode("scanned-qr-payload") }
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

    func testChallengeNumberRequiresNonnegativeIntegerDigits()
    {
        for number in ["", " \n", "1.5", "-1", "+1", "1e2", "abc", "4 2", String(repeating: "9", count: 100)]
        {
            XCTAssertFalse(MSALMfaSampleModel.isValidChallengeNumber(number), number)
        }
        for number in ["0", "7", "42", "007", " 42\n"]
        {
            XCTAssertTrue(MSALMfaSampleModel.isValidChallengeNumber(number), number)
        }
    }

    func testRefreshOnEmptyAccountsPresentsOnePromptUntilDismissed() async throws
    {
        var calls = 0
        let model = MSALMfaSampleModel(loadChallenges:
        {
            calls += 1
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        })
        XCTAssertNil(model.challengePrompt)
        await model.refreshChallenge()
        let first = try XCTUnwrap(model.challengePrompt)
        XCTAssertFalse(first.session.guid.isEmpty)
        XCTAssertTrue(model.registrations.isEmpty)
        await model.refreshChallenge()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.challengePrompt?.id, first.id)
        model.dismissChallenge()
        XCTAssertNil(model.challengePrompt)
        XCTAssertNil(model.respondToChallenge(id: first.id, approve: false, number: ""))
        await model.refreshChallenge()
        XCTAssertEqual(calls, 2)
        XCTAssertNotEqual(model.challengePrompt?.id, first.id)
    }

    func testEmptyChallengeResponseDoesNotPresentAlert() async
    {
        let model = MSALMfaSampleModel(loadChallenges: { [] })
        await model.refreshChallenge()
        XCTAssertNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertEqual(model.challengeStatus, .noPendingChallenge)
    }

    func testApprovalPassesEnteredNumberWithoutMatchingFixedChallengeNumber() async throws
    {
        var submittedNumber: String?
        var submittedSession: MSALNativeAuthMfaSdkAuthSession?
        var submittedApproval: Bool?
        let model = MSALMfaSampleModel(respond:
        { session, approve, number in
            submittedNumber = number
            submittedSession = session
            submittedApproval = approve
            return try await MSALNativeAuthMfaSdkManager().approve(authSession: session, number: number)
        })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: " 7 "))
        XCTAssertNil(model.challengePrompt)
        XCTAssertTrue(model.isRespondingToChallenge)
        await response.value
        XCTAssertTrue(submittedSession === prompt.session)
        XCTAssertEqual(submittedNumber, "7")
        XCTAssertEqual(submittedApproval, true)
        XCTAssertEqual(model.challengeStatus, .approved)
        XCTAssertFalse(model.isRespondingToChallenge)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testInvalidNumberDoesNotSubmitAndDenialDoesNotRequireNumber() async throws
    {
        var calls = 0
        let model = MSALMfaSampleModel(respond:
        { session, approve, number in
            calls += 1
            XCTAssertFalse(approve)
            XCTAssertEqual(number, "")
            return try await MSALNativeAuthMfaSdkManager().deny(authSession: session)
        })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        XCTAssertNil(model.respondToChallenge(id: prompt.id, approve: true, number: "not a number"))
        XCTAssertEqual(model.challengePrompt?.id, prompt.id)
        XCTAssertEqual(model.challengeStatus, .invalidNumber)
        XCTAssertEqual(calls, 0)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: false, number: ""))
        await response.value
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.challengeStatus, .denied)
        XCTAssertNil(model.challengePrompt)
    }

    func testPendingResponseBlocksDuplicateActionsAndRefresh() async throws
    {
        let gate = ChallengeGate()
        var loads = 0
        var responses = 0
        let model = MSALMfaSampleModel(loadChallenges:
        {
            loads += 1
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        }, respond: { session, _, number in
            responses += 1
            await gate.wait()
            return try await MSALNativeAuthMfaSdkManager().approve(authSession: session, number: number)
        })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: "7"))
        await fulfillment(of: [gate.started], timeout: 2)
        model.dismissChallenge()
        XCTAssertNil(model.respondToChallenge(id: prompt.id, approve: false, number: ""))
        await model.refreshChallenge()
        XCTAssertEqual(loads, 1)
        XCTAssertEqual(responses, 1)
        XCTAssertTrue(model.isRespondingToChallenge)
        gate.resume()
        await response.value
        XCTAssertEqual(model.challengeStatus, .approved)
    }

    func testOverlappingAndCanceledRefreshCannotReplaceNewPrompt() async throws
    {
        let gate = ChallengeGate()
        var loads = 0
        let model = MSALMfaSampleModel(loadChallenges:
        {
            loads += 1
            if loads == 1 { await gate.wait() }
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        })
        let oldRefresh = Task { await model.refreshChallenge() }
        await fulfillment(of: [gate.started], timeout: 2)
        await model.refreshChallenge()
        XCTAssertEqual(loads, 1)
        XCTAssertTrue(model.isLoadingChallenge)
        model.cancelChallengeFlow()
        await model.refreshChallenge()
        let newPrompt = try XCTUnwrap(model.challengePrompt)
        gate.resume()
        await oldRefresh.value
        XCTAssertEqual(loads, 2)
        XCTAssertEqual(model.challengePrompt?.id, newPrompt.id)
        XCTAssertFalse(model.isLoadingChallenge)
    }

    func testAccountsRefreshSurvivesCanceledSwiftUIRefreshTask() async
    {
        let gate = ChallengeGate()
        let model = MSALMfaSampleModel(loadChallenges:
        {
            await gate.wait()
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        })
        let refresh = Task { await model.refreshChallengeFromAccounts() }
        await fulfillment(of: [gate.started], timeout: 2)
        refresh.cancel()
        gate.resume()
        await refresh.value
        XCTAssertNotNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertNil(model.challengeStatus)
    }

    func testAccountsRefreshFromAlreadyCanceledCallerStillLoadsPrompt() async
    {
        let model = MSALMfaSampleModel()
        let refresh = Task { await model.refreshChallengeFromAccounts() }
        refresh.cancel()
        await refresh.value
        XCTAssertNotNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
    }

    func testNavigationCancelsOwnedRefreshAndLateResultCannotReplaceNewPrompt() async throws
    {
        let gate = ChallengeGate()
        var calls = 0
        let model = MSALMfaSampleModel(loadChallenges:
        {
            calls += 1
            if calls == 1
            {
                await gate.wait()
                XCTAssertTrue(Task.isCancelled)
            }
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        })
        let oldRefresh = Task { await model.refreshChallengeFromAccounts() }
        await fulfillment(of: [gate.started], timeout: 2)
        model.cancelChallengeFlow()
        XCTAssertNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
        await model.refreshChallengeFromAccounts()
        let newPrompt = try XCTUnwrap(model.challengePrompt)
        gate.resume()
        await oldRefresh.value
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(model.challengePrompt?.id, newPrompt.id)
        XCTAssertFalse(model.isLoadingChallenge)
    }

    func testOverlappingAccountsRefreshesShareOneOwnedRequest() async
    {
        let gate = ChallengeGate()
        var calls = 0
        let model = MSALMfaSampleModel(loadChallenges:
        {
            calls += 1
            await gate.wait()
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        })
        let first = Task { await model.refreshChallengeFromAccounts() }
        await fulfillment(of: [gate.started], timeout: 2)
        let second = Task { await model.refreshChallengeFromAccounts() }
        first.cancel()
        gate.resume()
        await first.value
        await second.value
        XCTAssertEqual(calls, 1)
        XCTAssertNotNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
    }

    func testCanceledRefreshTaskDoesNotPresentPrompt() async
    {
        let gate = ChallengeGate()
        let model = MSALMfaSampleModel(loadChallenges:
        {
            await gate.wait()
            return try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        })
        let refresh = Task { await model.refreshChallenge() }
        await fulfillment(of: [gate.started], timeout: 2)
        refresh.cancel()
        gate.resume()
        await refresh.value
        XCTAssertNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertNil(model.challengeStatus)
    }

    func testLateResponseCannotOverwriteNewChallenge() async throws
    {
        let gate = ChallengeGate()
        let model = MSALMfaSampleModel(respond:
        { session, _, number in
            await gate.wait()
            return try await MSALNativeAuthMfaSdkManager().approve(authSession: session, number: number)
        })
        await model.refreshChallenge()
        let oldPrompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: oldPrompt.id, approve: true, number: "7"))
        await fulfillment(of: [gate.started], timeout: 2)
        model.cancelChallengeFlow()
        await model.refreshChallenge()
        let newPrompt = try XCTUnwrap(model.challengePrompt)
        gate.resume()
        await response.value
        XCTAssertEqual(model.challengePrompt?.id, newPrompt.id)
        XCTAssertNil(model.challengeStatus)
        XCTAssertFalse(model.isRespondingToChallenge)
        XCTAssertNil(model.respondToChallenge(id: oldPrompt.id, approve: false, number: ""))
    }

    func testCanceledResponseTaskDoesNotPublishOutcome() async throws
    {
        let gate = ChallengeGate()
        let model = MSALMfaSampleModel(respond:
        { session, _, number in
            await gate.wait()
            return try await MSALNativeAuthMfaSdkManager().approve(authSession: session, number: number)
        })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: "7"))
        await fulfillment(of: [gate.started], timeout: 2)
        response.cancel()
        gate.resume()
        await response.value
        XCTAssertFalse(model.isRespondingToChallenge)
        XCTAssertNil(model.challengeStatus)
        XCTAssertNil(model.challengePrompt)
    }

    func testResponseCanceledBeforeStartingDoesNotCallSDK() async throws
    {
        var calls = 0
        let model = MSALMfaSampleModel(respond:
        { session, _, number in
            calls += 1
            return try await MSALNativeAuthMfaSdkManager().approve(authSession: session, number: number)
        })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: "7"))
        response.cancel()
        await response.value
        XCTAssertEqual(calls, 0)
        XCTAssertFalse(model.isRespondingToChallenge)
        XCTAssertNil(model.challengeStatus)
    }

    func testMismatchedResponseShowsErrorInsteadOfSuccess() async throws
    {
        let model = MSALMfaSampleModel(respond:
        { session, _, _ in
            try await MSALNativeAuthMfaSdkManager().deny(authSession: session)
        })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: "7"))
        await response.value
        XCTAssertEqual(model.challengeStatus, .unexpectedResult)
        XCTAssertFalse(model.isRespondingToChallenge)
    }
}

@MainActor
private final class ChallengeGate
{
    let started = XCTestExpectation(description: "Mock challenge operation started")
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async
    {
        await withCheckedContinuation
        { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }

    func resume()
    {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class ActivationGate
{
    let started = XCTestExpectation(description: "Mock activation started")
    private(set) var calls = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func activate(_ parameters: MSALNativeAuthMfaSdkRegistrationParameters) async throws -> MSALNativeAuthMfaSdkRegistrationResult
    {
        await wait()
        return try await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: parameters)
    }

    func addThirdPartyAccount(
        _ parameters: MSALNativeAuthMfaSdkManualRegistrationParameters
    ) async throws -> MSALNativeAuthMfaSdkRegistrationResult
    {
        await wait()
        return try await MSALNativeAuthMfaSdkManager().addThirdPartyAccount(registrationParameters: parameters)
    }

    private func wait() async
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
    }

    func resume()
    {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}
