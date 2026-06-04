//
//  CredentialManagementViewModel.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-05-27.
//

import Foundation
import MSAL
import MSALNativeCredManagment
import SwiftUI
import AuthenticationServices
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Main view model that demonstrates the credential management SDK integration.
@MainActor
class CredentialManagementViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isSignedIn = false
    @Published var userName: String = ""
    @Published var credentialMethods: [MSALCredentialMethod] = []
    @Published var isLoading = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?

    // Challenge state
    @Published var showChallengeInput = false
    @Published var challengeHint: String = ""

    // Toggle: real server vs mock (backed by UserDefaults — SDK reads this internally)
    @Published var useMockAPI: Bool = UserDefaults.standard.bool(
        forKey: "com.microsoft.identity.credentialmanagement.useMockAPI"
    ) {
        didSet {
            UserDefaults.standard.set(useMockAPI, forKey: "com.microsoft.identity.credentialmanagement.useMockAPI")
            // Invalidate cached client so next call picks up new mode
            credClient = nil
            reinitializeClient()
        }
    }

    // MARK: - Private Properties

    private var credClient: MSALNativeCredentialMethodsClient?
    private var tokenProvider: SampleTokenProvider?
    private var pendingChallengeState: MSALCredentialMethodChallengeState?

    // MARK: - Initialization

    func initialize() {
        reinitializeClient()
    }

    private func reinitializeClient() {
        do {
            // 1. Configure shared logger (used by both MSAL and Credential Management)
            MSALGlobalConfig.loggerConfig.logLevel = .verbose
            MSALGlobalConfig.loggerConfig.setLogCallback { _, message, containsPII in
                if !containsPII {
                    print("MSAL: \(message ?? "")")
                }
            }

            // 2. Create token provider
            if tokenProvider == nil {
                tokenProvider = SampleTokenProvider()
            }

            // 3. Create shared request interceptor
            let sharedRequestInterceptor = SampleRequestInterceptor()

            // 4. Initialize Credential Management Client
            let credConfig = MSALNativeCredentialManagementConfig()
            credConfig.requestInterceptor = sharedRequestInterceptor
            credConfig.tokenProvider = tokenProvider
            credConfig.tenantSubdomain = Configuration.tenantSubdomain

            credClient = try MSALNativeCredentialMethodsClient(config: credConfig)

            let mode = useMockAPI ? "Mock API (UserDefaults)" : "Real Server"
            statusMessage = "SDK initialized (\(mode))."
        } catch {
            errorMessage = "Failed to initialize: \(error.localizedDescription)"
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) {
        isLoading = true
        statusMessage = "Signing in..."
        errorMessage = nil

        // Simulate a brief network delay, then return fake token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.tokenProvider?.setSignedIn(true)
            self.isSignedIn = true
            self.userName = email
            self.isLoading = false
            self.statusMessage = "Signed in successfully (POC - fake token)."
        }
    }

    // MARK: - Credential Management Operations

    func listCredentialMethods() {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }

        isLoading = true
        statusMessage = "Loading credential methods..."
        errorMessage = nil

        Task {
            let result = await credClient.listCredentialMethods()
            switch result {
            case .success(let methods):
                isLoading = false
                credentialMethods = methods.compactMap { $0 as? MSALCredentialMethod }
                statusMessage = "Loaded \(methods.count) credential method(s)."
            case .failure(let error):
                isLoading = false
                errorMessage = "List failed: \(error.message ?? "Unknown error")"
            }
        }
    }

    // MARK: - Register Phone

    func registerPhone(phoneNumber: String) {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }

        isLoading = true
        statusMessage = "Registering phone..."
        errorMessage = nil

        let params = MSALRegisterPhoneNumberParams(phoneNumber: phoneNumber)

        Task {
            let result = await credClient.register.phoneNumber(params: params)
            handleRegistrationResult(result)
        }
    }

    // MARK: - Register Password

    func registerPassword(password: String) {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty."
            return
        }
        isLoading = true
        statusMessage = "Registering password..."
        errorMessage = nil

        let params = MSALRegisterPasswordParams(password: password)

        Task {
            let result = await credClient.register.password(params: params)
            handleRegistrationResult(result)
        }
    }

    // MARK: - Register Passkey

    func registerPasskey(displayName: String? = nil) {
        guard let credClient = self.credClient else { return }
        isLoading = true

        Task { @MainActor in
            guard let anchor = Self.resolveAnchor() else
            {
                self.isLoading = false
                self.errorMessage = "No window available."
                return
            }

            let params = MSALRegisterPasskeyParams(
                presentationAnchor: anchor,
                displayName: displayName
            )

            let result = await credClient.register.passkey(params: params)
            handleRegistrationResult(result)
        }
    }

    private static func resolveAnchor() -> ASPresentationAnchor?
    {
        #if os(macOS)
        return NSApplication.shared.keyWindow
        #else
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
        #endif
    }

    func submitChallenge(code: String) {
        guard let state = pendingChallengeState else {
            errorMessage = "No pending challenge."
            return
        }

        isLoading = true
        statusMessage = "Verifying code..."
        showChallengeInput = false

        Task {
            let result = await state.submitChallenge(code: code)
            switch result {
            case .success(let method):
                isLoading = false
                pendingChallengeState = nil
                statusMessage = "Registered \(method.credentialType.rawValue) successfully."
                listCredentialMethods()
            case .failure(let error):
                isLoading = false
                errorMessage = "Verification failed: \(error.message ?? "Unknown error")"
            }
        }
    }

    func deleteCredentialMethod(_ method: MSALCredentialMethod) {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }

        isLoading = true
        statusMessage = "Deleting credential method..."
        errorMessage = nil

        Task {
            let result = await credClient.deleteCredentialMethod(method)
            switch result {
            case .success:
                isLoading = false
                statusMessage = "Credential method deleted."
                listCredentialMethods()
            case .failure(let error):
                isLoading = false
                errorMessage = "Delete failed: \(error.message ?? "Unknown error")"
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        tokenProvider?.setSignedIn(false)
        isSignedIn = false
        userName = ""
        credentialMethods = []
        statusMessage = "Signed out."
    }

    // MARK: - Private Helpers

    private func handleRegistrationResult(
        _ result: Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    ) {
        switch result {
        case .success(let registrationResult):
            switch registrationResult {
            case .completed(let method):
                isLoading = false
                statusMessage = "Registered \(method.credentialType.rawValue) successfully."
                listCredentialMethods()
            case .challengeRequired(let state):
                isLoading = false
                pendingChallengeState = state
                challengeHint = state.sentTo ?? "your registered contact"
                showChallengeInput = true
                statusMessage = "Verification code sent to \(challengeHint)."
            }
        case .failure(let error):
            isLoading = false
            errorMessage = "Registration failed: \(error.message ?? "Unknown error")"
        }
    }
}

// MARK: - All credential operations use async/await (no delegates needed)
