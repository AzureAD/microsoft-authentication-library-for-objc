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

    // MARK: - Private Properties

    private var credClient: MSALNativeCredentialMethodsClient?
    private var tokenProvider: SampleTokenProvider?

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

        Task {
            let result = await credClient.listCredentialMethods()
            switch result {
            case .success(let methods):
                isLoading = false
                credentialMethods = methods
                statusMessage = "Loaded \(methods.count) credential method(s)."
            case .failure(let error):
                isLoading = false
                errorMessage = "List failed: \(error.message ?? "Unknown error")"
            }
        }
    }

    func registerCredentialMethod(type: String, value: String) {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }

        isLoading = true
        statusMessage = "Registering \(type)..."
        errorMessage = nil

        Task {
            let parameters: [String: Any] = ["value": value]
            let result = await credClient.registerCredentialMethod(type: type, parameters: parameters)
            switch result {
            case .success(let method):
                isLoading = false
                statusMessage = "Registered \(method.credentialType) successfully."
                listCredentialMethods()
            case .failure(let error):
                isLoading = false
                errorMessage = "Registration failed: \(error.message ?? "Unknown error")"
            }
        }
    }

    func deleteCredentialMethod(id: String) {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }

        isLoading = true
        statusMessage = "Deleting credential method..."
        errorMessage = nil

        Task {
            let result = await credClient.deleteCredentialMethod(credentialMethod: id)
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
}

// MARK: - All credential operations use async/await (no delegates needed)
