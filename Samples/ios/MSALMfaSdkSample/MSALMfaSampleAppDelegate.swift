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

import UIKit
import MSAL
import UserNotifications

@MainActor
final class MSALMfaSampleAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate
{
    let sdk: MSALNativeAuthMFAManager
    let pushRegistration: MSALMfaSamplePushRegistration
    lazy var model = MSALMfaSampleModel(sdk: sdk, registerForPush: pushRegistration.register)

    override convenience init()
    {
        self.init(sdk: MSALNativeAuthMFAManager(
            enableExperimentalService: true,
            deviceName: Self.registrationDeviceName(
                environment: ProcessInfo.processInfo.environment,
                currentDeviceName: UIDevice.current.name
            )
        ))
    }

    static func registrationDeviceName(environment: [String: String], currentDeviceName: String) -> String
    {
        guard let override = environment["MSAL_MFA_DEVICE_NAME"],
              !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            return currentDeviceName
        }
        return override
    }

    init(sdk: MSALNativeAuthMFAManager)
    {
        self.sdk = sdk
        self.pushRegistration = MSALMfaSamplePushRegistration(updatePushRegistration: {
            try await sdk.updatePushRegistration(deviceToken: $0, apnsEnvironment: $1)
        })
        super.init()
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        UNUserNotificationCenter.current().delegate = self
        if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any]
        {
            let fields = Self.fields(payload)
            Task { await process(fields) }
        }
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        let fields = Self.fields(userInfo)
        var completion = Optional(completionHandler)
        let operation = Task { await process(fields) }
        let deadline = Task
        {
            do { try await Task.sleep(for: .seconds(25)) }
            catch { return }
            operation.cancel()
            completion?(.failed)
            completion = nil
        }
        Task
        {
            let succeeded = await operation.value
            deadline.cancel()
            completion?(succeeded ? .newData : .failed)
            completion = nil
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let fields = Self.fields(notification.request.content.userInfo)
        completionHandler([])
        Task { @MainActor in await process(fields) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                           withCompletionHandler completionHandler: @escaping () -> Void)
    {
        let fields = Self.fields(response.notification.request.content.userInfo)
        completionHandler()
        Task { @MainActor in await process(fields) }
    }

    @discardableResult
    private func process(_ fields: [String: String]) async -> Bool
    {
        do
        {
            model.receivePushSessions(try await sdk.handlePushNotification(payload: fields))
            return true
        }
        catch
        {
            model.reportPushFailure()
            return false
        }
    }

    private nonisolated static func fields(_ payload: [AnyHashable: Any]) -> [String: String]
    {
        let source = payload["data"] as? [AnyHashable: Any] ?? payload
        var fields: [String: String] = [:]
        for (key, value) in source
        {
            if let key = key as? String, let value = value as? String
            {
                fields[key] = value
            }
        }
        return fields
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        // Convert the Data bytes into a continuous hex string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        print("Push Token String: \(tokenString)")
        
        pushRegistration.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)
    {
        pushRegistration.didFailToRegister()
    }
}
