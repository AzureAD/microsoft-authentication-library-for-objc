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
    private let tokenProvider = MSALMfaSampleWebTokenProvider()
    lazy var model = MSALMfaSampleModel(
        sdk: sdk, registerForPush: pushRegistration.register,
        tokenProvider: tokenProvider
    )

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
final class MSALMfaSampleWebTokenProvider: MSALTokenProvider
{
    enum Failure: Error, Equatable
    {
        case notConfigured
        case noPresentationContext
        case authenticationFailed
        case userCancelled
        case interactionRequired
        case accountMismatch
    }

    private var applications: [String: MSALPublicClientApplication] = [:]

    func getAccessToken(parameters request: MSALTokenProviderParameters) async throws -> MSALTokenProviderResult
    {
        try Task.checkCancellation()
        let application = try application(for: request)
        let accounts: [MSALAccount]? = try application.allAccounts()
        if let account = accounts?.first(where: {
            if request.tenantId == nil, request.objectId == nil { return accounts?.count == 1 }
            return $0.tenantProfiles?.contains(where: {
                (request.tenantId == nil || $0.tenantId?.caseInsensitiveCompare(request.tenantId ?? "") == .orderedSame)
                    && (request.objectId == nil || $0.identifier?.caseInsensitiveCompare(request.objectId ?? "") == .orderedSame)
            }) == true
        })
        {
            let parameters = MSALSilentTokenParameters(scopes: request.scopes, account: account)
            try Self.configure(parameters, for: request)
            do
            {
                let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
                    application.acquireTokenSilent(with: parameters) { result, error in
                        if let result { continuation.resume(returning: result) }
                        else { continuation.resume(throwing: error ?? Failure.authenticationFailed) }
                    }
                }
                try Task.checkCancellation()
                return try Self.tokenResult(result, for: request)
            }
            catch
            {
                let failure = error as NSError
                guard failure.domain == MSALErrorDomain, failure.code == MSALError.interactionRequired.rawValue else { throw error }
            }
        }
        try Task.checkCancellation()
        try Self.requireInteractionAllowed(request)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else
        {
            throw Failure.noPresentationContext
        }
        while let presented = presenter.presentedViewController { presenter = presented }
        let web = Self.webviewParameters(presenter: presenter)
        let parameters = MSALInteractiveTokenParameters(scopes: request.scopes, webviewParameters: web)
        try Self.configure(parameters, for: request)
        parameters.loginHint = request.loginHint
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
        return try Self.tokenResult(result, for: request)
    }

    static func configure(_ parameters: MSALTokenParameters, for request: MSALTokenProviderParameters) throws
    {
        parameters.scopes = request.scopes
        parameters.correlationId = request.correlationId
        parameters.claimsRequest = nil
        guard let json = request.claimsRequestJSON else { return }
        var error: NSError?
        let claims: MSALClaimsRequest? = MSALClaimsRequest(jsonString: json, error: &error)
        guard let claims else
        {
            if let error { throw error }
            throw Failure.authenticationFailed
        }
        parameters.claimsRequest = claims
    }

    static func requireInteractionAllowed(_ request: MSALTokenProviderParameters) throws
    {
        guard request.allowsInteraction else { throw Failure.interactionRequired }
    }

    static func tokenResult(_ result: MSALResult, for request: MSALTokenProviderParameters) throws -> MSALTokenProviderResult
    {
        guard let tenantId = result.tenantProfile.tenantId,
              let objectId = result.tenantProfile.claims?["oid"] as? String,
              !tenantId.isEmpty, !objectId.isEmpty else { throw Failure.authenticationFailed }
        guard (request.tenantId == nil || tenantId.caseInsensitiveCompare(request.tenantId ?? "") == .orderedSame),
              (request.objectId == nil || objectId.caseInsensitiveCompare(request.objectId ?? "") == .orderedSame) else
        {
            throw Failure.accountMismatch
        }
        return MSALTokenProviderResult(
            accessToken: result.accessToken, expiresOn: result.expiresOn, scopes: result.scopes,
            tenantId: tenantId, objectId: objectId, authorityURL: result.authority.url,
            authenticationScheme: result.authenticationScheme
        )
    }

    static func webviewParameters(presenter: UIViewController) -> MSALWebviewParameters
    {
        let web = MSALWebviewParameters(authPresentationViewController: presenter)
        // A UIKit-hosted browser allows the sample's MFA alert to appear above the sign-in page.
        web.webviewType = .safariViewController
        web.presentationStyle = .pageSheet
        return web
    }

    private func application(for request: MSALTokenProviderParameters) throws -> MSALPublicClientApplication
    {
        guard let clientId = Bundle.main.object(forInfoDictionaryKey: "MSALMfaClientId") as? String,
              UUID(uuidString: clientId) != nil,
              let bundleId = Bundle.main.bundleIdentifier else { throw Failure.notConfigured }
        if let application = applications[request.authorityURL.absoluteString] { return application }
        let authority = try MSALAuthority(url: request.authorityURL)
        let config = MSALPublicClientApplicationConfig(
            clientId: clientId, redirectUri: "msauth.\(bundleId)://auth", authority: authority
        )
        config.cacheConfig.keychainSharingGroup = bundleId
        let application = try MSALPublicClientApplication(configuration: config)
        applications[request.authorityURL.absoluteString] = application
        return application
    }
}
