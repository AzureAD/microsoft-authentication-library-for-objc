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
    private let deletionSignIn = MSALMfaSampleDeletionSignIn()
    lazy var model = MSALMfaSampleModel(
        sdk: sdk, registerForPush: pushRegistration.register,
        deletionTokenProvider: { [weak self] context in
            guard let self else { throw CancellationError() }
            return try await self.acquireDeletionToken(context: context)
        }
    )

    private func acquireDeletionToken(context: MSALNativeAuthMFADeletionContext) async throws -> MSALResult
    {
        try await model.acquireDeletionToken {
            try await self.deletionSignIn.acquireToken(context: context)
        }
    }

    override convenience init()
    {
        self.init(sdk: MSALNativeAuthMFAManager())
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
        MSALGlobalConfig.brokerAvailability = .none
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
        let revision = model.registrationRevision
        do
        {
            let sessions = try await sdk.handlePushNotification(payload: fields)
            guard model.registrationRevision == revision else { return true }
            model.receivePushSessions(sessions)
            return true
        }
        catch
        {
            guard model.registrationRevision == revision else { return true }
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

@MainActor
final class MSALMfaSampleDeletionSignIn
{
    enum Failure: Error
    {
        case notConfigured
        case noPresentationContext
        case authenticationFailed
        case userCancelled
    }

    private var applications: [String: MSALPublicClientApplication] = [:]

    func acquireToken(context: MSALNativeAuthMFADeletionContext) async throws -> MSALResult
    {
        try Task.checkCancellation()
        let application = try application(for: context)
        let claimsRequest = try Self.deletionClaimsRequest()
        let accounts: [MSALAccount]? = try application.allAccounts()
        if let account = accounts?.first(where: {
            $0.tenantProfiles?.contains(where: {
                $0.tenantId?.caseInsensitiveCompare(context.tenantId) == .orderedSame
                    && $0.identifier?.caseInsensitiveCompare(context.objectId) == .orderedSame
            }) == true
        })
        {
            let parameters = MSALSilentTokenParameters(scopes: context.scopes, account: account)
            parameters.claimsRequest = claimsRequest
            do
            {
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
                    application.acquireTokenSilent(with: parameters) { result, error in
                        if let result { continuation.resume(returning: result) }
                        else { continuation.resume(throwing: error ?? Failure.authenticationFailed) }
                    }
                }
                try Task.checkCancellation()
                return result
            }
            catch
            {
                let failure = error as NSError
                guard failure.domain == MSALErrorDomain, failure.code == MSALError.interactionRequired.rawValue else { throw error }
            }
        }
        try Task.checkCancellation()
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else
        {
            throw Failure.noPresentationContext
        }
        while let presented = presenter.presentedViewController { presenter = presented }
        let web = Self.webviewParameters(presenter: presenter)
        let parameters = MSALInteractiveTokenParameters(scopes: context.scopes, webviewParameters: web)
        parameters.claimsRequest = claimsRequest
        parameters.loginHint = context.username
        parameters.promptType = .login
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
            application.acquireToken(with: parameters) { result, error in
                if let result { continuation.resume(returning: result) }
                else if let error = error as NSError?,
                        error.domain == MSALErrorDomain, error.code == MSALError.userCanceled.rawValue
                {
                    continuation.resume(throwing: Failure.userCancelled)
                }
                else { continuation.resume(throwing: error ?? Failure.authenticationFailed) }
            }
        }
        try Task.checkCancellation()
        return result
    }

    static func deletionClaimsRequest() throws -> MSALClaimsRequest
    {
        // Graph deletion requires fresh strong authentication; prompt=login alone does not request it.
        // Supplying claims also bypasses MSAL's access-token cache in the silent path.
        var error: NSError?
        let request: MSALClaimsRequest? = MSALClaimsRequest(
            jsonString: #"{"access_token":{"amr":{"essential":true,"values":["ngcmfa"]}}}"#,
            error: &error
        )
        guard let request else
        {
            if let error { throw error }
            throw Failure.authenticationFailed
        }
        return request
    }

    static func webviewParameters(presenter: UIViewController) -> MSALWebviewParameters
    {
        let web = MSALWebviewParameters(authPresentationViewController: presenter)
        // A UIKit-hosted browser allows the sample's MFA alert to appear above the sign-in page.
        web.webviewType = .safariViewController
        web.presentationStyle = .pageSheet
        return web
    }

    private func application(for context: MSALNativeAuthMFADeletionContext) throws -> MSALPublicClientApplication
    {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "MSALMfaClientId") as? String,
              UUID(uuidString: clientId) != nil,
              let bundleId = Bundle.main.bundleIdentifier else { throw Failure.notConfigured }
        if let application = applications[context.tenantId] { return application }
        let authority = try MSALAADAuthority(url: context.authorityURL)
        let config = MSALPublicClientApplicationConfig(
            clientId: clientId, redirectUri: "msauth.\(bundleId)://auth", authority: authority
        )
        config.cacheConfig.keychainSharingGroup = bundleId
        let application = try MSALPublicClientApplication(configuration: config)
        applications[context.tenantId] = application
        return application
    }
}
