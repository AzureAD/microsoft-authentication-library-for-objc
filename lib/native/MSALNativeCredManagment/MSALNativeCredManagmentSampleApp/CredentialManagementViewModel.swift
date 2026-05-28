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

    // MARK: - Private Properties

    private var credClient: MSALNativeCredentialMethodsClient?
    private var tokenProvider: SampleTokenProvider?
    private var pendingChallengeState: MSALCredentialMethodChallengeState?

    // MARK: - Initialization

    func initialize() {
        do {
            // 1. Configure shared logger (used by both MSAL and Credential Management)
            MSALGlobalConfig.loggerConfig.logLevel = .verbose
            MSALGlobalConfig.loggerConfig.setLogCallback { _, message, containsPII in
                if !containsPII {
                    print("MSAL: \(message ?? "")")
                }
            }

            // 2. Create token provider
            tokenProvider = SampleTokenProvider()

            // 3. Create shared request interceptor
            let sharedRequestInterceptor = SampleRequestInterceptor()

            // 4. Initialize Credential Management Client
            let credConfig = MSALNativeCredentialManagementConfig()
            credConfig.requestInterceptor = sharedRequestInterceptor
            credConfig.tokenProvider = tokenProvider
            credClient = try MSALNativeCredentialMethodsClient(config: credConfig)

            statusMessage = "SDK initialized successfully."
        } catch {
            errorMessage = "Failed to initialize: \(error.localizedDescription)"
        }
    }

    // MARK: - Sign In (Fake for POC)

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

        credClient.listCredentialMethods(delegate: self)
    }

    func registerCredentialMethod(type: String, value: String) {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }

        isLoading = true
        statusMessage = "Registering \(type)..."
        errorMessage = nil

        let parameters: [String: Any] = ["value": value]
        credClient.registerCredentialMethod(type: type, parameters: parameters, delegate: self)
    }

    func deleteCredentialMethod(id: String) {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }

        isLoading = true
        statusMessage = "Deleting credential method..."
        errorMessage = nil

        credClient.deleteCredentialMethod(credentialMethodId: id, delegate: self)
    }

    func submitChallenge(code: String) {
        guard let state = pendingChallengeState else {
            errorMessage = "No pending challenge."
            return
        }

        isLoading = true
        statusMessage = "Verifying code..."
        showChallengeInput = false

        state.submitChallenge(code: code, delegate: self)
        pendingChallengeState = nil
    }

    // MARK: - Sign Out

    func signOut() {
        tokenProvider?.setSignedIn(false)
        isSignedIn = false
        userName = ""
        credentialMethods = []
        statusMessage = "Signed out."
    }
}

// MARK: - MSALCredentialMethodsListDelegate

extension CredentialManagementViewModel: MSALCredentialMethodsListDelegate {

    nonisolated func onCredentialMethodsListCompleted(methods: [MSALCredentialMethod]) {
        Task { @MainActor in
            isLoading = false
            credentialMethods = methods
            statusMessage = "Loaded \(methods.count) credential method(s)."
        }
    }

    nonisolated func onCredentialMethodsListError(error: MSALNativeCredentialManagementError) {
        Task { @MainActor in
            isLoading = false
            errorMessage = "List failed: \(error.message ?? "Unknown error")"
        }
    }
}

// MARK: - MSALCredentialMethodRegisterDelegate

extension CredentialManagementViewModel: MSALCredentialMethodRegisterDelegate {

    nonisolated func onCredentialMethodRegistrationCompleted(method: MSALCredentialMethod) {
        Task { @MainActor in
            isLoading = false
            statusMessage = "Registered \(method.credentialType) successfully."
            listCredentialMethods()
        }
    }

    nonisolated func onCredentialMethodRegistrationError(error: MSALNativeCredentialManagementError) {
        Task { @MainActor in
            isLoading = false
            errorMessage = "Registration failed: \(error.message ?? "Unknown error")"
        }
    }

    nonisolated func onCredentialMethodChallengeRequired(state: MSALCredentialMethodChallengeState) {
        Task { @MainActor in
            isLoading = false
            pendingChallengeState = state
            challengeHint = state.sentTo ?? "your registered contact"
            showChallengeInput = true
            statusMessage = "Verification code sent to \(challengeHint)."
        }
    }
}

// MARK: - MSALCredentialMethodDeleteDelegate

extension CredentialManagementViewModel: MSALCredentialMethodDeleteDelegate {

    nonisolated func onCredentialMethodDeleteCompleted() {
        Task { @MainActor in
            isLoading = false
            statusMessage = "Credential method deleted."
            listCredentialMethods()
        }
    }

    nonisolated func onCredentialMethodDeleteError(error: MSALNativeCredentialManagementError) {
        Task { @MainActor in
            isLoading = false
            errorMessage = "Delete failed: \(error.message ?? "Unknown error")"
        }
    }
}
