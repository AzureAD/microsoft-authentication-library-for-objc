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
@testable import MSAL
import UIKit
import SwiftUI

@MainActor
final class MSALMfaSampleModelTests: XCTestCase
{
    private enum RequestError: Error
    {
        case failed
    }

    private static func registerForPush() async throws -> MSALMfaSamplePushRegistration.Registration
    {
        MSALMfaSamplePushRegistration.Registration(deviceToken: Data([0x01, 0x02, 0xA0]), environment: .sandbox)
    }

    func testSampleCompatibilityVersionMatchesReferenceCapture()
    {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, "6.8.56")
    }

    func testSampleDeviceNameOverridePreservesSuppliedValue()
    {
        XCTAssertEqual(
            MSALMfaSampleAppDelegate.registrationDeviceName(
                environment: ["MSAL_MFA_DEVICE_NAME": " Synthetic <device> "], currentDeviceName: "Fallback"
            ),
            " Synthetic <device> "
        )
    }

    func testSampleDeviceNameFallsBackForMissingOrBlankOverride()
    {
        for environment in [[:], ["MSAL_MFA_DEVICE_NAME": ""], ["MSAL_MFA_DEVICE_NAME": " \n "]]
        {
            XCTAssertEqual(
                MSALMfaSampleAppDelegate.registrationDeviceName(environment: environment, currentDeviceName: "Synthetic current device"),
                "Synthetic current device"
            )
        }
    }

    func testActivationWaitsUntilCallbackTokenIsAccepted() async
    {
        let sdk = SampleSDKFixture()
        let update = ChallengeGate()
        let requested = expectation(description: "APNs registration requested")
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { true },
            registerForRemoteNotifications: { requested.fulfill() },
            updatePushRegistration: { token, environment in
                await update.wait()
                try await sdk.updatePushRegistration(deviceToken: token, apnsEnvironment: environment)
            }
        )
        let model = Self.makeModel(registerForPush: push.register, activate: {
            try await sdk.registerAuthMethod(registrationParameters: $0)
        })
        let task = Task { await model.registerQRCode("scanned-code") }
        await fulfillment(of: [requested], timeout: 2)
        push.didRegister(deviceToken: Data([0x01]))
        await fulfillment(of: [update.started], timeout: 2)
        XCTAssertTrue(model.isRegistering)
        XCTAssertTrue(model.registrations.isEmpty)
        update.resume()
        let added = await task.value
        XCTAssertTrue(added)
        XCTAssertEqual(model.registrations.count, 1)
    }

    func testFailedSDKTokenHandoffBlocksActivationAndCachedTokenCanRetry() async
    {
        let sdk = SampleSDKFixture()
        let requested = expectation(description: "APNs registration requested")
        var calls = 0
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { true },
            registerForRemoteNotifications: { requested.fulfill() },
            updatePushRegistration: { token, environment in
                calls += 1
                if calls == 1 { throw RequestError.failed }
                try await sdk.updatePushRegistration(deviceToken: token, apnsEnvironment: environment)
            }
        )
        let model = Self.makeModel(registerForPush: push.register, activate: {
            try await sdk.registerAuthMethod(registrationParameters: $0)
        })
        let first = Task { await model.registerQRCode("scanned-code") }
        await fulfillment(of: [requested], timeout: 2)
        push.didRegister(deviceToken: Data([0x01]))
        let failed = await first.value
        XCTAssertFalse(failed)
        XCTAssertEqual(model.validationError, .pushRegistration(.synchronizationFailed))
        XCTAssertTrue(model.registrations.isEmpty)
        let added = await model.registerQRCode("scanned-code")
        XCTAssertTrue(added)
        XCTAssertEqual(calls, 2)
    }

    func testQRWaitsForNewestTokenHandoffWhenTokenChanges() async throws
    {
        let firstUpdate = ChallengeGate()
        let secondUpdate = ChallengeGate()
        let requested = expectation(description: "APNs registration requested")
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { true },
            registerForRemoteNotifications: { requested.fulfill() },
            updatePushRegistration: { token, _ in
                await (token == Data([0x01]) ? firstUpdate : secondUpdate).wait()
            }
        )
        let task = Task { try await push.register() }
        await fulfillment(of: [requested], timeout: 2)
        push.didRegister(deviceToken: Data([0x01]))
        await fulfillment(of: [firstUpdate.started], timeout: 2)
        push.didRegister(deviceToken: Data([0x02]))
        await fulfillment(of: [secondUpdate.started], timeout: 2)
        firstUpdate.resume()
        secondUpdate.resume()
        let registration = try await task.value
        XCTAssertEqual(registration.deviceToken, Data([0x02]))
    }

    private static func makeModel(
        registerForPush: @escaping @MainActor () async throws -> MSALMfaSamplePushRegistration.Registration,
        loadChallenges: @escaping () async throws -> [MSALNativeAuthMFAAuthSession] = {
            try await SampleSDKFixture().pullPendingNotifications()
        },
        respond: @escaping (
            MSALNativeAuthMFAAuthSession, Bool, String
        ) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult = { session, approve, number in
            let sdk = SampleSDKFixture()
            if approve { return try await sdk.approve(authSession: session, number: number) }
            return try await sdk.deny(authSession: session)
        },
        activate: @escaping (MSALNativeAuthMFARegistrationParameters) async throws -> MSALNativeAuthMFARegistrationResult = activateFixture
    ) -> MSALMfaSampleModel
    {
        MSALMfaSampleModel(
            registerForPush: registerForPush,
            loadChallenges: loadChallenges,
            respond: respond,
            activate: activate
        )
    }

    func testEveryAppleCallbackForwardsRawTokenAndEnvironmentWithoutAnAccount() async throws
    {
        var forwarded: [Data] = []
        let push = makePushRegistration(
            environment: { .production },
            updatePushRegistration: { token, environment in
                XCTAssertEqual(environment, .production)
                forwarded.append(token)
            }
        )
        let tokens = [Data([0x00, 0xAB]), Data([0x00, 0xAB]), Data([0xFF, 0x01])]
        for token in tokens
        {
            let task = try XCTUnwrap(push.didRegister(deviceToken: token))
            await task.value
        }
        XCTAssertEqual(forwarded, tokens)
        XCTAssertNil(push.backgroundFailure)
    }

    func testForegroundAcquiresFreshTokenWithoutPromptingEvenWithCachedToken() async throws
    {
        let requested = expectation(description: "Fresh APNs registration requested")
        let forwarded = expectation(description: "Fresh token forwarded to SDK")
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { XCTFail("Foreground refresh must not prompt"); return false },
            registerForRemoteNotifications: { requested.fulfill() },
            isAuthorized: { true },
            updatePushRegistration: { token, _ in
                if token == Data([0x02]) { forwarded.fulfill() }
            }
        )
        let initial = try XCTUnwrap(push.didRegister(deviceToken: Data([0x01])))
        await initial.value
        let task = Task { await push.refreshIfAuthorized() }
        await fulfillment(of: [requested], timeout: 2)
        push.didRegister(deviceToken: Data([0x02]))
        await task.value
        await fulfillment(of: [forwarded], timeout: 2)
        XCTAssertEqual(push.currentDeviceToken, Data([0x02]))
    }

    func testForegroundWithoutPermissionDoesNotPromptOrRegister() async
    {
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { XCTFail("Only QR setup may prompt"); return false },
            registerForRemoteNotifications: { XCTFail("No notification permission") },
            isAuthorized: { false },
            updatePushRegistration: { _, _ in XCTFail("No token was acquired") }
        )
        await push.refreshIfAuthorized()
        XCTAssertNil(push.backgroundFailure)
    }

    func testPushUpdateFailureIsVisibleAndNextCallbackCanRecover() async throws
    {
        var calls = 0
        let push = makePushRegistration(
            environment: { .sandbox },
            updatePushRegistration: { _, _ in
                calls += 1
                if calls == 1 { throw RequestError.failed }
            }
        )
        let failed = try XCTUnwrap(push.didRegister(deviceToken: Data([0x01])))
        await failed.value
        XCTAssertEqual(push.backgroundFailure, .synchronizationFailed)
        let retry = try XCTUnwrap(push.didRegister(deviceToken: Data([0x01])))
        await retry.value
        XCTAssertNil(push.backgroundFailure)
        XCTAssertEqual(calls, 2)
    }

    func testNewTokenIsForwardedWhilePreviousUpdateIsPendingAndOldErrorIsIgnored() async throws
    {
        let gate = ChallengeGate()
        var forwarded: [Data] = []
        let push = makePushRegistration(
            environment: { .sandbox },
            updatePushRegistration: { token, _ in
                forwarded.append(token)
                if token == Data([0x01])
                {
                    await gate.wait()
                    throw RequestError.failed
                }
            }
        )
        let first = try XCTUnwrap(push.didRegister(deviceToken: Data([0x01])))
        await fulfillment(of: [gate.started], timeout: 2)
        let second = try XCTUnwrap(push.didRegister(deviceToken: Data([0x02])))
        await second.value
        gate.resume()
        await first.value
        XCTAssertEqual(forwarded, [Data([0x01]), Data([0x02])])
        XCTAssertEqual(push.currentDeviceToken, Data([0x02]))
        XCTAssertNil(push.backgroundFailure)
    }

    func testInvalidCallbackInputIsNotSentToSDK() async throws
    {
        let push = makePushRegistration(
            environment: { throw MSALMfaSamplePushRegistration.Failure.invalidConfiguration },
            updatePushRegistration: { _, _ in XCTFail("Invalid configuration must block SDK submission") }
        )
        XCTAssertNil(push.didRegister(deviceToken: Data()))
        XCTAssertEqual(push.backgroundFailure, .missingDeviceToken)
        let task = try XCTUnwrap(push.didRegister(deviceToken: Data([0x01])))
        await task.value
        XCTAssertEqual(push.backgroundFailure, .invalidConfiguration)
    }

    func testForegroundAPNsFailureIsVisibleWithoutQRActivation() async
    {
        let requested = expectation(description: "APNs registration requested")
        let push = makePushRegistration(
            environment: { .sandbox },
            registerForRemoteNotifications: { requested.fulfill() },
            isAuthorized: { true },
            updatePushRegistration: { _, _ in XCTFail("APNs did not provide a token") }
        )
        let task = Task { await push.refreshIfAuthorized() }
        await fulfillment(of: [requested], timeout: 2)
        push.didFailToRegister()
        await task.value
        XCTAssertEqual(push.backgroundFailure, .registrationFailed)
    }

    func testPushRegistrationWaitsForPermissionAndAppleCallback() async throws
    {
        let permission = ChallengeGate()
        let requested = expectation(description: "APNs registration requested")
        var requests = 0
        let push = makePushRegistration(
            environment: { .production },
            requestAuthorization: { await permission.wait(); return true },
            registerForRemoteNotifications: { requests += 1; requested.fulfill() }
        )
        let task = Task { try await push.register() }
        await fulfillment(of: [permission.started], timeout: 2)
        XCTAssertEqual(requests, 0)
        permission.resume()
        await fulfillment(of: [requested], timeout: 2)
        let token = Data([0x00, 0xAB, 0xFF])
        push.didRegister(deviceToken: token)
        let registration = try await task.value
        XCTAssertEqual(registration.deviceToken, token)
        XCTAssertEqual(registration.environment, .production)
        XCTAssertEqual(push.currentDeviceToken, token)
    }

    func testDeniedPermissionDoesNotRegisterWithAPNs() async
    {
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { false },
            registerForRemoteNotifications: { XCTFail("Permission is required") }
        )
        do
        {
            _ = try await push.register()
            XCTFail("Permission denial must fail")
        }
        catch
        {
            XCTAssertEqual(error as? MSALMfaSamplePushRegistration.Failure, .notificationsDenied)
        }
    }

    func testPermissionRequestFailureIsSurfaced() async
    {
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { throw RequestError.failed },
            registerForRemoteNotifications: { XCTFail("Authorization failed") }
        )
        do
        {
            _ = try await push.register()
            XCTFail("Authorization error must fail")
        }
        catch
        {
            XCTAssertEqual(error as? MSALMfaSamplePushRegistration.Failure, .registrationFailed)
        }
    }

    func testInvalidPushConfigurationFailsBeforePermissionRequest() async
    {
        let push = makePushRegistration(
            environment: { throw MSALMfaSamplePushRegistration.Failure.invalidConfiguration },
            requestAuthorization: { XCTFail("Invalid environment must not prompt"); return true },
            registerForRemoteNotifications: { XCTFail("Invalid environment must not register") }
        )
        do
        {
            _ = try await push.register()
            XCTFail("Unknown environment must not default to a service environment")
        }
        catch
        {
            XCTAssertEqual(error as? MSALMfaSamplePushRegistration.Failure, .invalidConfiguration)
        }
    }

    func testAppleRegistrationFailureAllowsRetry() async throws
    {
        let firstRequest = expectation(description: "First registration requested")
        let retryRequest = expectation(description: "Retry requested")
        var calls = 0
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { true },
            registerForRemoteNotifications: {
                calls += 1
                (calls == 1 ? firstRequest : retryRequest).fulfill()
            }
        )
        let first = Task { try await push.register() }
        await fulfillment(of: [firstRequest], timeout: 2)
        push.didFailToRegister()
        do
        {
            _ = try await first.value
            XCTFail("APNs failure must fail the pending request")
        }
        catch
        {
            XCTAssertEqual(error as? MSALMfaSamplePushRegistration.Failure, .registrationFailed)
        }
        let retry = Task { try await push.register() }
        await fulfillment(of: [retryRequest], timeout: 2)
        push.didRegister(deviceToken: Data([0x01]))
        let registration = try await retry.value
        XCTAssertEqual(registration.deviceToken, Data([0x01]))
        XCTAssertEqual(calls, 2)
    }

    func testEmptyAppleTokenIsRejected() async
    {
        let requested = expectation(description: "APNs registration requested")
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { true },
            registerForRemoteNotifications: { requested.fulfill() }
        )
        let task = Task { try await push.register() }
        await fulfillment(of: [requested], timeout: 2)
        push.didRegister(deviceToken: Data())
        do
        {
            _ = try await task.value
            XCTFail("Empty APNs token must not activate an account")
        }
        catch
        {
            XCTAssertEqual(error as? MSALMfaSamplePushRegistration.Failure, .missingDeviceToken)
        }
        XCTAssertNil(push.currentDeviceToken)
    }

    func testMissingAppleCallbackTimesOut() async
    {
        let timeout = ChallengeGate()
        let requested = expectation(description: "APNs registration requested")
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { true },
            registerForRemoteNotifications: { requested.fulfill() },
            waitForTimeout: { await timeout.wait() }
        )
        let task = Task { try await push.register() }
        await fulfillment(of: [requested, timeout.started], timeout: 2)
        timeout.resume()
        do
        {
            _ = try await task.value
            XCTFail("Missing callback must not wait indefinitely")
        }
        catch
        {
            XCTAssertEqual(error as? MSALMfaSamplePushRegistration.Failure, .timedOut)
        }
    }

    func testCanceledPushWaiterDoesNotCancelOtherWaiter() async throws
    {
        let permissions = expectation(description: "Both callers authorized")
        permissions.expectedFulfillmentCount = 2
        var calls = 0
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { permissions.fulfill(); return true },
            registerForRemoteNotifications: { calls += 1 }
        )
        let first = Task { try await push.register() }
        let second = Task { try await push.register() }
        await fulfillment(of: [permissions], timeout: 2)
        XCTAssertEqual(calls, 1)
        first.cancel()
        do
        {
            _ = try await first.value
            XCTFail("Canceled waiter must not receive a token")
        }
        catch
        {
            XCTAssertTrue(error is CancellationError)
        }
        push.didRegister(deviceToken: Data([0x02]))
        let result = try await second.value
        XCTAssertEqual(result.deviceToken, Data([0x02]))
    }

    func testCancellationDuringPermissionPromptDoesNotRequestAPNs() async
    {
        let permission = ChallengeGate()
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { await permission.wait(); return true },
            registerForRemoteNotifications: { XCTFail("Canceled flow must not request an APNs token") }
        )
        let task = Task { try await push.register() }
        await fulfillment(of: [permission.started], timeout: 2)
        task.cancel()
        permission.resume()
        do
        {
            _ = try await task.value
            XCTFail("Canceled authorization must not continue")
        }
        catch
        {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testCanceledLastPushWaiterDoesNotResumeOnLateAppleCallback() async throws
    {
        let requested = expectation(description: "APNs registration requested")
        var calls = 0
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { true },
            registerForRemoteNotifications: { calls += 1; requested.fulfill() }
        )
        let task = Task { try await push.register() }
        await fulfillment(of: [requested], timeout: 2)
        task.cancel()
        do
        {
            _ = try await task.value
            XCTFail("The canceled request must finish without a token")
        }
        catch
        {
            XCTAssertTrue(error is CancellationError)
        }
        push.didRegister(deviceToken: Data([0x03]))
        let next = try await push.register()
        XCTAssertEqual(next.deviceToken, Data([0x03]))
        XCTAssertEqual(calls, 1)
    }

    func testLatestAppleTokenIsReusedOnlyAfterCheckingPermission() async throws
    {
        var authorized = true
        let push = makePushRegistration(
            environment: { .sandbox },
            requestAuthorization: { authorized },
            registerForRemoteNotifications: { XCTFail("The current launch already has an APNs token") }
        )
        push.didRegister(deviceToken: Data([0x01]))
        push.didRegister(deviceToken: Data([0x02]))
        let registration = try await push.register()
        XCTAssertEqual(registration.deviceToken, Data([0x02]))
        authorized = false
        do
        {
            _ = try await push.register()
            XCTFail("A cached token must not bypass revoked notification permission")
        }
        catch
        {
            XCTAssertEqual(error as? MSALMfaSamplePushRegistration.Failure, .notificationsDenied)
        }
    }

    func testAppDelegateForwardsAppleRegistrationCallbacks()
    {
        let delegate = MSALMfaSampleAppDelegate(sdk: MSALNativeAuthMFAManager())
        let token = Data([0xAB, 0xCD])
        delegate.application(UIApplication.shared, didRegisterForRemoteNotificationsWithDeviceToken: token)
        XCTAssertEqual(delegate.pushRegistration.currentDeviceToken, token)
        delegate.application(UIApplication.shared, didFailToRegisterForRemoteNotificationsWithError: RequestError.failed)
        XCTAssertNil(delegate.pushRegistration.currentDeviceToken)
    }

    func testQRActivationWaitsForPushRegistrationAndForwardsOnlyQRCode() async
    {
        let gate = ChallengeGate()
        let token = Data([0x00, 0xAB, 0xFF])
        var calls = 0
        let model = Self.makeModel(registerForPush: {
            await gate.wait()
            return MSALMfaSamplePushRegistration.Registration(deviceToken: token, environment: .production)
        }, activate: { parameters in
            calls += 1
            XCTAssertEqual(parameters.qrCode, "actual-scanned-text")
            XCTAssertEqual(Set(Mirror(reflecting: parameters).children.compactMap(\.label)), ["qrCode", "accountName", "secretKey", "activationCode", "activationURL"])
            return try await activateFixture(parameters)
        })
        let task = Task { await model.registerQRCode("actual-scanned-text") }
        await fulfillment(of: [gate.started], timeout: 2)
        XCTAssertTrue(model.isRegistering)
        XCTAssertEqual(calls, 0)
        gate.resume()
        let added = await task.value
        XCTAssertTrue(added)
        XCTAssertEqual(calls, 1)
    }

    func testPushFailureDoesNotCallSDKAndShowsActionableError() async
    {
        let model = Self.makeModel(registerForPush: {
            throw MSALMfaSamplePushRegistration.Failure.notificationsDenied
        }, activate: { _ in
            XCTFail("Denied push permission must prevent activation")
            throw RequestError.failed
        })
        let added = await model.registerQRCode("scanned-code")
        XCTAssertFalse(added)
        XCTAssertEqual(model.validationError, .pushRegistration(.notificationsDenied))
        XCTAssertTrue(model.registrations.isEmpty)
        XCTAssertFalse(model.isRegistering)
    }

    func testNavigationDuringPushRegistrationPreventsLateSDKActivation() async
    {
        let gate = ChallengeGate()
        let model = Self.makeModel(registerForPush: {
            await gate.wait()
            return try await Self.registerForPush()
        }, activate: { _ in
            XCTFail("Late APNs completion must not activate a canceled QR request")
            throw RequestError.failed
        })
        let task = Task { await model.registerQRCode("scanned-code") }
        await fulfillment(of: [gate.started], timeout: 2)
        model.cancelRegistration()
        gate.resume()
        let added = await task.value
        XCTAssertFalse(added)
        XCTAssertNil(model.validationError)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testManualEntryRequiresPushRegistration() async
    {
        var called = false
        let model = Self.makeModel(registerForPush: {
            called = true
            return try await Self.registerForPush()
        })
        let added = await model.finishManualEntry(name: "Account", secret: "test-key")
        XCTAssertTrue(added)
        XCTAssertTrue(called)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: { _ in
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: { parameters in
            calls += 1
            if calls == 1 { throw RequestError.failed }
            return try await activateFixture(parameters)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: { _ in throw RequestError.failed })
        let added = await model.finishManualEntry(name: "Account", secret: "test-key")
        XCTAssertFalse(added)
        XCTAssertEqual(model.validationError, .registrationFailed)
        XCTAssertFalse(model.isRegistering)
        XCTAssertTrue(model.registrations.isEmpty)
    }

    func testRefreshFailureDoesNotPresentSignInPrompt() async
    {
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges: { throw RequestError.failed })
        await model.refreshChallengeFromAccounts()
        XCTAssertNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertEqual(model.challengeStatus, .requestFailed)
    }

    func testResponseFailureDoesNotReportApproval() async throws
    {
        let model = Self.makeModel(registerForPush: Self.registerForPush, respond: { _, _, _ in throw RequestError.failed })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: "42"))
        await response.value
        XCTAssertEqual(model.challengeStatus, .requestFailed)
        XCTAssertFalse(model.isRespondingToChallenge)
    }

    func testRepeatedRegistrationUsesSDKIdentityInsteadOfAddingDuplicateRows() async throws
    {
        let result = try await activateFixture(MSALNativeAuthMFARegistrationParameters(qrCode: "scanned-code"))
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: { _ in result })
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
        let model = Self.makeModel(registerForPush: Self.registerForPush)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            await gate.wait()
            let sessions = try await SampleSDKFixture().pullPendingNotifications()
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            calls += 1
            await gate.wait()
            return try await SampleSDKFixture().pullPendingNotifications()
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
        let model = Self.makeModel(registerForPush: Self.registerForPush)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate:
        { parameters in
            calls += 1
            return try await activateFixture(parameters)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush)
        let first = await model.registerQRCode("scanned-qr-payload")
        let second = await model.registerQRCode("scanned-qr-payload")
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(model.registrations.count, 2)
        XCTAssertEqual(Set(model.registrations.map(\.id)).count, 2)
        XCTAssertTrue(model.registrations.allSatisfy { $0.source == .qrCode })
        XCTAssertFalse(model.isRegistering)
        XCTAssertTrue(Self.makeModel(registerForPush: Self.registerForPush).registrations.isEmpty)
    }

    func testQRAndManualInputUseTheSameRegistrationOperation() async
    {
        var inputs: [MSALNativeAuthMFARegistrationParameters] = []
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: { parameters in
            inputs.append(parameters)
            return try await activateFixture(parameters)
        })
        let scanned = await model.registerQRCode("scanned-qr-payload")
        let entered = await model.finishManualEntry(name: "Entered account", secret: "entered-secret")
        XCTAssertTrue(scanned)
        XCTAssertTrue(entered)
        XCTAssertEqual(inputs.count, 2)
        XCTAssertEqual(inputs.first?.qrCode, "scanned-qr-payload")
        XCTAssertNil(inputs.first?.secretKey)
        XCTAssertEqual(inputs.last?.activationURL, "Entered account")
        XCTAssertEqual(inputs.last?.activationCode, "entered-secret")
        XCTAssertNil(inputs.last?.qrCode)
        XCTAssertEqual(model.registrations.map(\.source), [.qrCode, .manualEntry])
    }

    func testScannedQRCodeIsForwardedUnchangedAndUsesSDKAccountName() async throws
    {
        var submittedQR: String?
        let manager = SampleSDKFixture()
        try await manager.updatePushRegistration(deviceToken: Data([0x01]), apnsEnvironment: .sandbox)
        let scannedCode = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&issuer=Test"
        var returnedName: String?
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate:
        { parameters in
            submittedQR = parameters.qrCode
            XCTAssertNil(parameters.accountName)
            XCTAssertNil(parameters.secretKey)
            let result = try await manager.registerAuthMethod(registrationParameters: parameters)
            returnedName = result.accountName
            return result
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate:
        { parameters in
            calls += 1
            submittedName = parameters.activationURL
            submittedSecret = parameters.activationCode
            XCTAssertNil(parameters.qrCode)
            return try await activateFixture(parameters)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate:
        { _ in
            try await SampleSDKFixture().registerAuthMethod(
                registrationParameters: MSALNativeAuthMFARegistrationParameters(
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate:
        { _ in
            try await SampleSDKFixture().registerAuthMethod(
                registrationParameters: MSALNativeAuthMFARegistrationParameters(
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: gate.activate)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: gate.activate)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: gate.activate)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate: gate.activate)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, activate:
        { parameters in
            calls += 1
            return try await (calls == 1 ? oldGate : newGate).activate(parameters)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            calls += 1
            return try await SampleSDKFixture().pullPendingNotifications()
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

    func testPushDuringRefreshIsPresentedOnceWhetherOrNotPullReturnsIt() async throws
    {
        for includedInPull in [false, true]
        {
            let gate = ChallengeGate()
            let sessions = try await SampleSDKFixture().pullPendingNotifications()
            let session = try XCTUnwrap(sessions.first)
            let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
            {
                await gate.wait()
                return includedInPull ? [session] : []
            })
            model.setApplicationActive(true)
            model.setAccountsVisible(true)
            let refresh = Task { await model.refreshChallenge() }
            await fulfillment(of: [gate.started], timeout: 2)
            model.receivePushSessions([session])
            XCTAssertNil(model.challengePrompt)
            gate.resume()
            await refresh.value
            let prompt = try XCTUnwrap(model.challengePrompt)
            XCTAssertEqual(prompt.session.guid, session.guid)
            XCTAssertNil(model.challengeStatus)
            let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: false, number: ""))
            await response.value
            XCTAssertNil(model.challengePrompt)
            model.receivePushSessions([session])
            XCTAssertNil(model.challengePrompt)
        }
    }

    func testEmptyChallengeResponseDoesNotPresentAlert() async
    {
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges: { [] })
        await model.refreshChallenge()
        XCTAssertNil(model.challengePrompt)
        XCTAssertFalse(model.isLoadingChallenge)
        XCTAssertEqual(model.challengeStatus, .noPendingChallenge)
    }

    func testApprovalPassesEnteredNumberWithoutMatchingFixedChallengeNumber() async throws
    {
        var submittedNumber: String?
        var submittedSession: MSALNativeAuthMFAAuthSession?
        var submittedApproval: Bool?
        let model = Self.makeModel(registerForPush: Self.registerForPush, respond:
        { session, approve, number in
            submittedNumber = number
            submittedSession = session
            submittedApproval = approve
            return try await SampleSDKFixture().approve(authSession: session, number: number)
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

    func testOrdinaryApprovalDoesNotRequireOrForwardANumber() async throws
    {
        let session = MSALNativeAuthMFAAuthSession(
            guid: UUID().uuidString, accountName: "Fixture account", username: "fixture@example.test",
            firstEntropyNumber: "", requiresNumberMatching: false
        )
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges: { [session] }, respond:
        { submitted, approve, number in
            XCTAssertTrue(submitted === session)
            XCTAssertTrue(approve)
            XCTAssertTrue(number.isEmpty)
            return MSALNativeAuthMFAPendingAuthSessionCompletionResult(wasApproved: true)
        })
        await model.refreshChallenge()
        let prompt = try XCTUnwrap(model.challengePrompt)
        let response = try XCTUnwrap(model.respondToChallenge(id: prompt.id, approve: true, number: ""))
        await response.value
        XCTAssertEqual(model.challengeStatus, .approved)
    }

    func testInvalidNumberDoesNotSubmitAndDenialDoesNotRequireNumber() async throws
    {
        var calls = 0
        let model = Self.makeModel(registerForPush: Self.registerForPush, respond:
        { session, approve, number in
            calls += 1
            XCTAssertFalse(approve)
            XCTAssertEqual(number, "")
            return try await SampleSDKFixture().deny(authSession: session)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            loads += 1
            return try await SampleSDKFixture().pullPendingNotifications()
        }, respond: { session, _, number in
            responses += 1
            await gate.wait()
            return try await SampleSDKFixture().approve(authSession: session, number: number)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            loads += 1
            if loads == 1 { await gate.wait() }
            return try await SampleSDKFixture().pullPendingNotifications()
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            await gate.wait()
            return try await SampleSDKFixture().pullPendingNotifications()
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
        let model = Self.makeModel(registerForPush: Self.registerForPush)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            calls += 1
            if calls == 1
            {
                await gate.wait()
                XCTAssertTrue(Task.isCancelled)
            }
            return try await SampleSDKFixture().pullPendingNotifications()
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            calls += 1
            await gate.wait()
            return try await SampleSDKFixture().pullPendingNotifications()
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, loadChallenges:
        {
            await gate.wait()
            return try await SampleSDKFixture().pullPendingNotifications()
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, respond:
        { session, _, number in
            await gate.wait()
            return try await SampleSDKFixture().approve(authSession: session, number: number)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, respond:
        { session, _, number in
            await gate.wait()
            return try await SampleSDKFixture().approve(authSession: session, number: number)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, respond:
        { session, _, number in
            calls += 1
            return try await SampleSDKFixture().approve(authSession: session, number: number)
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
        let model = Self.makeModel(registerForPush: Self.registerForPush, respond:
        { session, _, _ in
            try await SampleSDKFixture().deny(authSession: session)
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
private func makePushRegistration(
    environment: @escaping @MainActor () throws -> MSALNativeAuthMFAAPNsEnvironment = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MSALMfaAPNsEnvironment") as? String,
              let environment = MSALNativeAuthMFAAPNsEnvironment(rawValue: value) else {
            throw MSALMfaSamplePushRegistration.Failure.invalidConfiguration
        }
        return environment
    },
    requestAuthorization: @escaping @MainActor () async throws -> Bool = { true },
    registerForRemoteNotifications: @escaping @MainActor () -> Void = {},
    waitForTimeout: @escaping @MainActor () async throws -> Void = { try await Task.sleep(for: .seconds(30)) },
    isAuthorized: @escaping @MainActor () async -> Bool = { true },
    updatePushRegistration: @escaping @MainActor (Data, MSALNativeAuthMFAAPNsEnvironment) async throws -> Void = { _, _ in }
) -> MSALMfaSamplePushRegistration
{
    MSALMfaSamplePushRegistration(
        environment: environment, requestAuthorization: requestAuthorization,
        registerForRemoteNotifications: registerForRemoteNotifications, waitForTimeout: waitForTimeout,
        isAuthorized: isAuthorized, updatePushRegistration: updatePushRegistration
    )
}

private struct SampleSDKFixture
{
    func updatePushRegistration(deviceToken: Data, apnsEnvironment: MSALNativeAuthMFAAPNsEnvironment) async throws
    {
        try Task.checkCancellation()
        guard !deviceToken.isEmpty else { throw MSALNativeAuthMFAPushRegistrationError.invalidDeviceToken }
    }

    func registerAuthMethod(registrationParameters: MSALNativeAuthMFARegistrationParameters) async throws
        -> MSALNativeAuthMFARegistrationResult
    {
        MSALNativeAuthMFARegistrationResult(
            registrationId: UUID().uuidString,
            accountName: (registrationParameters.activationURL ?? registrationParameters.accountName ?? "Fixture account")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func pullPendingNotifications() async throws -> [MSALNativeAuthMFAAuthSession]
    {
        [MSALNativeAuthMFAAuthSession(guid: UUID().uuidString, accountName: "Fixture account",
                                       username: "fixture@example.test", firstEntropyNumber: "")]
    }

    func approve(authSession: MSALNativeAuthMFAAuthSession, number: String) async throws
        -> MSALNativeAuthMFAPendingAuthSessionCompletionResult
    {
        MSALNativeAuthMFAPendingAuthSessionCompletionResult(wasApproved: true)
    }

    func deny(authSession: MSALNativeAuthMFAAuthSession) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult
    {
        MSALNativeAuthMFAPendingAuthSessionCompletionResult(wasApproved: false)
    }
}

private func activateFixture(
    _ parameters: MSALNativeAuthMFARegistrationParameters
) async throws -> MSALNativeAuthMFARegistrationResult
{
    let sdk = SampleSDKFixture()
    try await sdk.updatePushRegistration(deviceToken: Data([0x01, 0x02, 0xA0]), apnsEnvironment: .sandbox)
    return try await sdk.registerAuthMethod(registrationParameters: parameters)
}

@MainActor
private final class ActivationGate
{
    let started = XCTestExpectation(description: "Mock activation started")
    private(set) var calls = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func activate(_ parameters: MSALNativeAuthMFARegistrationParameters) async throws -> MSALNativeAuthMFARegistrationResult
    {
        await wait()
        return try await activateFixture(parameters)
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
