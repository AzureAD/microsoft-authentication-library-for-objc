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
import MSAL
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A built-in token provider that uses MSAL's web-based interactive flow to acquire tokens.
///
/// On first call, it presents a web view for interactive sign-in. On subsequent calls,
/// it attempts silent token acquisition using the cached account, falling back to interactive
/// if the silent attempt fails with `MSALErrorInteractionRequired`.
///
/// Usage:
/// ```swift
/// let tokenProvider = try MSALNativeAuthTokenProvider(clientId: "your-client-id")
/// credConfig.tokenProvider = tokenProvider
/// ```
@objcMembers
public class MSALNativeAuthTokenProvider: NSObject, MSALNativeCredentialManagementTokenProvider {

    private static let credentialManagementScopes = ["api://02815c3e-3ef8-40a4-8f95-cfb184350d7e/Me.UserAuthenticationMethod.ReadWrite"]
    private static let credentialManagementClaims = "{\"access_token\":{\"acrs\":{\"essential\":true,\"values\":[\"urn:user:registersecurityinfo\"]},\"amr\":{\"essential\":true,\"values\":[\"ngcmfa\"]}}}"

    private let application: MSALPublicClientApplication
    private var cachedAccount: MSALAccount?

    /// Initialize with a client ID and optional tenant/slice targeting.
    ///
    /// - Parameters:
    ///   - clientId: The application (client) ID registered in the identity platform.
    ///   - tenantId: The tenant ID (directory GUID) used to build the authority. When `nil`, the default MSAL authority is used.
    ///   - dc: An optional ESTS slice/datacenter (`dc`) used for test-slice targeting. When `nil`, no slice config is applied.
    /// - Throws: If the MSAL configuration is invalid.
    public init(clientId: String, tenantId: String? = nil, dc: String? = nil) throws
    {
        let config = MSALPublicClientApplicationConfig(clientId: clientId)
        config.cacheConfig.keychainSharingGroup = "com.microsoft.adalcache"

        if let dc = dc
        {
            config.sliceConfig = MSALSliceConfig(slice: nil, dc: dc)
        }

        if let tenantId = tenantId,
           let authorityURL = URL(string: "https://login.microsoftonline.com/\(tenantId)")
        {
            config.authority = try MSALAuthority(url: authorityURL)

            // Set known authority to skip broker and run local flow only
            config.knownAuthorities = [config.authority]
        }

        self.application = try MSALPublicClientApplication(configuration: config)
        super.init()
    }

    /// Retrieve an access token using MSAL web flow.
    ///
    /// Attempts silent acquisition first. If no cached account exists or interaction is required,
    /// falls back to interactive web view sign-in.
    ///
    /// - Parameters:
    ///   - scopes: The scopes required by the credential management operation.
    ///   - completionBlock: Called with the access token on success, or nil and an error on failure.
    public func getAccessToken(
        scopes: [String],
        completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock
    )
    {
        // When mock mode is ON, return a fake token immediately without hitting the network.
        if CredentialManagementEnvironment.isMockAPIEnabled
        {
            completionBlock("mock-access-token-for-testing", nil)
            return
        }

        if let account = cachedAccount ?? (try? application.allAccounts().first)
        {
            acquireTokenSilent(scopes: scopes, account: account, completionBlock: completionBlock)
        }
        else
        {
            acquireTokenInteractive(scopes: scopes, completionBlock: completionBlock)
        }
    }

    /// Clear the cached account so the next token request triggers interactive sign-in.
    public func signOut()
    {
        if let account = cachedAccount ?? (try? application.allAccounts().first)
        {
            try? application.remove(account)
        }
        cachedAccount = nil
    }

    // MARK: - Private

    private func acquireTokenSilent(
        scopes: [String],
        account: MSALAccount,
        completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock
    )
    {
        let silentParams = MSALSilentTokenParameters(scopes: Self.credentialManagementScopes, account: account)
        silentParams.claimsRequest = MSALClaimsRequest(jsonString: Self.credentialManagementClaims, error: nil)
        silentParams.forceRefresh = true

        application.acquireTokenSilent(with: silentParams) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result
            {
                self.cachedAccount = result.account
                completionBlock(result.accessToken, nil)
                return
            }

            if let nsError = error as NSError?,
               nsError.domain == MSALErrorDomain,
               nsError.code == MSALError.interactionRequired.rawValue
            {
                self.acquireTokenInteractive(scopes: scopes, completionBlock: completionBlock)
                return
            }

            let credError = MSALNativeCredentialManagementError(
                type: .unauthorized,
                message: "Silent token acquisition failed: \(error?.localizedDescription ?? "Unknown error")"
            )
            completionBlock(nil, credError)
        }
    }

    private func acquireTokenInteractive(
        scopes: [String],
        completionBlock: @escaping MSALNativeCredentialManagementTokenCompletionBlock
    )
    {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard let viewController = self.topViewController() else
            {
                let error = MSALNativeCredentialManagementError(
                    type: .invalidConfiguration,
                    message: "Unable to find a view controller to present the web view from."
                )
                completionBlock(nil, error)
                return
            }

            #if os(iOS)
            let webParams = MSALWebviewParameters(authPresentationViewController: viewController)
            #elseif os(macOS)
            let webParams = MSALWebviewParameters(authPresentationViewController: viewController)
            webParams.webviewType = .wkWebView
            #endif

            let interactiveParams = MSALInteractiveTokenParameters(scopes: Self.credentialManagementScopes, webviewParameters: webParams)
            interactiveParams.promptType = .login
            interactiveParams.claimsRequest = MSALClaimsRequest(jsonString: Self.credentialManagementClaims, error: nil)

            self.application.acquireToken(with: interactiveParams) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result
                {
                    self.cachedAccount = result.account
                    completionBlock(result.accessToken, nil)
                    return
                }

                let credError = MSALNativeCredentialManagementError(
                    type: .unauthorized,
                    message: "Interactive sign-in failed: \(error?.localizedDescription ?? "Unknown error")"
                )
                completionBlock(nil, credError)
            }
        }
    }

    #if os(iOS)
    private func topViewController() -> UIViewController?
    {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else
        {
            return nil
        }

        var top = rootVC
        while let presented = top.presentedViewController
        {
            top = presented
        }
        return top
    }
    #elseif os(macOS)
    private func topViewController() -> NSViewController?
    {
        return NSApplication.shared.keyWindow?.contentViewController
    }
    #endif
}

