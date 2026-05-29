//
//  ContentView.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-05-27.
//

import SwiftUI
import MSALNativeCredManagment

struct ContentView: View {

    @EnvironmentObject var viewModel: CredentialManagementViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var newCredentialType = "email"
    @State private var newCredentialValue = ""
    @State private var challengeCode = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSignedIn {
                    signedInView
                } else {
                    signInView
                }
            }
            .navigationTitle("Cred Management")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $viewModel.showChallengeInput) {
                challengeView
            }
        }
    }

    // MARK: - Challenge View

    private var challengeView: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)

                Text("Verification Required")
                    .font(.title2)
                    .bold()

                Text("A code was sent to \(viewModel.challengeHint). Enter it below to complete registration.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                TextField("Verification Code", text: $challengeCode)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.center)
                    .font(.title3)

                Button("Verify") {
                    viewModel.submitChallenge(code: challengeCode)
                    challengeCode = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(challengeCode.isEmpty)
            }
            .padding()
            .navigationTitle("Verify")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showChallengeInput = false
                        challengeCode = ""
                    }
                }
            }
        }
    }

    // MARK: - Sign In View

    private var signInView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.key")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Sign in to manage credentials")
                .font(.headline)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                #if os(iOS)
                .autocapitalization(.none)
                #endif

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)

            Button("Sign In") {
                viewModel.signIn(email: email, password: password)
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty)

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Signed In View

    private var signedInView: some View {
        VStack(spacing: 16) {
            // User info header
            HStack {
                VStack(alignment: .leading) {
                    Text("Signed in as")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.userName)
                        .font(.headline)
                }
                Spacer()
                Button("Sign Out") {
                    viewModel.signOut()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal)

            Divider()

            // Status
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            // Credential methods list
            List {
                Section("Registered Methods") {
                    if viewModel.credentialMethods.isEmpty {
                        Text("No credential methods found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.credentialMethods, id: \.id) { method in
                            credentialMethodRow(method)
                        }
                    }
                }

                Section("Add New Method") {
                    Picker("Type", selection: $newCredentialType) {
                        Text("Email").tag("email")
                        Text("Phone").tag("phone")
                        Text("Passkey").tag("passkey")
                    }

                    TextField("Value (email or phone)", text: $newCredentialValue)
                        .textFieldStyle(.roundedBorder)

                    Button("Register") {
                        viewModel.registerCredentialMethod(
                            type: newCredentialType,
                            value: newCredentialValue
                        )
                        newCredentialValue = ""
                    }
                    .disabled(newCredentialValue.isEmpty)
                }
            }
            .refreshable {
                viewModel.listCredentialMethods()
            }
        }
        .onAppear {
            viewModel.listCredentialMethods()
        }
    }

    // MARK: - Credential Method Row

    private func credentialMethodRow(_ method: MSALCredentialMethod) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(method.credentialType.capitalized)
                        .font(.subheadline)
                        .bold()
                    if method.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                if let displayName = method.displayName {
                    Text(displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive) {
                viewModel.deleteCredentialMethod(id: method.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Challenge Verification View

}

#Preview {
    ContentView()
        .environmentObject(CredentialManagementViewModel())
}

