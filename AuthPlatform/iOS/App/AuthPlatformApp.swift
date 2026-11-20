import LocalAuthentication
import SwiftUI

@main
struct AuthPlatformApp: App {
    var body: some Scene {
        WindowGroup {
            AuthenticationDemoView()
        }
    }
}

@MainActor
private struct AuthenticationDemoView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var newPassword = ""
    @State private var verificationCode = ""
    @State private var signedIn = false
    @State private var status = "Sign in to your AuthPlatform account."
    @State private var isBusy = false

    private var service: String {
        Bundle.main.object(forInfoDictionaryKey: "AUTH_CREDENTIAL_SERVICE") as? String ?? "auth.example.com"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign in to AuthPlatform") {
                    TextField("Email address", text: $username)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    Button {
                        Task { await signIn() }
                    } label: {
                        if isBusy { ProgressView() } else { Text("Sign in securely") }
                    }
                    .disabled(isBusy || username.isEmpty || password.isEmpty)
                }

                if signedIn {
                    Section("Apple Password AutoFill") {
                        Text("Your server login succeeded. Saving the password below is optional and requires your explicit action.")
                            .font(.footnote)
                        Button("Save this sign-in to this iPhone") {
                            saveCredential()
                        }
                        .disabled(isBusy)
                    }
                }

                Section("Unlock saved sign-in") {
                    Button("Unlock with Face ID / device passcode") {
                        Task { await unlockCredential() }
                    }
                    .disabled(isBusy || username.isEmpty)
                }

                Section("Password and verification fields") {
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                    TextField("One-time code", text: $verificationCode)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                }

                Section("Status") {
                    Text(status)
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("AuthPlatform")
        }
    }

    private func signIn() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let api = try AuthPlatformAPI()
            let tokens = try await api.login(email: username, password: password)
            guard tokens.emailVerified else {
                status = "Verify your email before using this account."
                return
            }
            try AuthSessionVault.save(refreshToken: tokens.refreshToken)
            signedIn = true
            status = "Signed in. Your refresh token is stored in the shared Keychain."
        } catch {
            status = error.localizedDescription
        }
    }

    private func saveCredential() {
        do {
            _ = try SharedCredentialVault.save(
                StoredPasswordCredential(service: service, username: username, password: password)
            )
            status = "Saved on this iPhone. The system AutoFill identity index is being refreshed."
        } catch {
            status = "Could not save this credential: \(error.localizedDescription)"
        }
    }

    private func unlockCredential() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let context = LAContext()
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your saved AuthPlatform sign-in")
            guard let credential = try SharedCredentialVault.credential(service: service, username: username) else {
                status = "No saved credential was found for this email and domain."
                return
            }
            status = "Unlocked \(credential.username) for \(credential.service). The Credential Provider can now offer it to AutoFill."
        } catch {
            status = "Unlock failed: \(error.localizedDescription)"
        }
    }
}
