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

        let credentialMethod = MSALPhoneCredentialMethod(
            phoneNumber: phoneNumber
        )

        Task {
            let result = await credClient.registerCredentialMethod(credentialMethod)
            handleRegistrationResult(result)
        }
    }

    // MARK: - Register Password

    func registerPassword() {
        guard let credClient = credClient else {
            errorMessage = "Credential client not initialized."
            return
        }
        isLoading = true
        statusMessage = "Registering password..."
        errorMessage = nil

        let credentialMethod = MSALPasswordCredentialMethod()

        Task {
            let result = await credClient.registerCredentialMethod(credentialMethod)
            handleRegistrationResult(result)
        }
    }

    // MARK: - Register Passkey

    func registerPasskey(displayName: String? = nil) {
        let relyingPartyIdentifier = Configuration.relyingPartyIdentifier

        // Mock: generate a random challenge (in production, this comes from the server)
        var challengeBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, challengeBytes.count, &challengeBytes)
        let challenge = Data(challengeBytes)

        // Mock: use a random user ID (in production, this comes from the server)
        let userId = Data(UUID().uuidString.utf8)

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyIdentifier
        )

        let registrationRequest = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: userName.isEmpty ? "user@example.com" : userName,
            userID: userId
        )

        let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
        passkeyDelegate = PasskeyAuthorizationDelegate { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let credential):
                    // Register the passkey in the credential management client
                    let credentialIdString = credential.credentialID.base64EncodedString()
                    let passkeyMethod = MSALPasskeyCredentialMethod(
                        displayName: displayName ?? "Passkey (\(String(credentialIdString.prefix(8)))...)",
                        credentialID: credentialIdString
                    )
                    guard let credClient = self.credClient else { return }
                    let registerResult = await credClient.registerCredentialMethod(passkeyMethod)
                    self.handleRegistrationResult(registerResult)
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = "Passkey creation failed: \(error.localizedDescription)"
                }
            }
        }
        authController.delegate = passkeyDelegate
        authController.presentationContextProvider = passkeyDelegate
        authController.performRequests()
    }

    private var passkeyDelegate: PasskeyAuthorizationDelegate?

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
