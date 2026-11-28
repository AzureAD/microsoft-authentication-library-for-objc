import LocalAuthentication
import SwiftUI
import UniformTypeIdentifiers

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
    private enum JSONEncoder {
        static var prettyPrinted: Foundation.JSONEncoder {
            let encoder = Foundation.JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return encoder
        }
    }
    @State private var username = ""
    @State private var password = ""
    @State private var newPassword = ""
    @State private var verificationCode = ""
    @State private var signedIn = false
    @State private var currentAccessToken = ""
    @State private var workosSignedIn = false
    @State private var status = "Sign in to your AuthPlatform account."
    @State private var isBusy = false
    @State private var recoveryCode = ""
    @State private var recoveryPackageJSON = ""
    @State private var recoveryCodeInput = ""
    @State private var showRecoveryImporter = false
    @State private var showRecoveryExporter = false
    @AppStorage("authplatform.vaultRecoveryAcknowledged") private var recoveryAcknowledged = false

    private var savedCredentials: [StoredPasswordCredential] {
        (try? SharedCredentialVault.allCredentials()) ?? []
    }

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

                Section("WorkOS AuthKit") {
                    Button {
                        Task { await signInWithWorkOS() }
                    } label: {
                        if isBusy { ProgressView() } else { Text("Continue with WorkOS") }
                    }
                    .disabled(isBusy || workosSignedIn)
                    if workosSignedIn {
                        Text("WorkOS authentication completed. The WorkOS-to-Vapor session bridge is not enabled yet.")
                            .font(.footnote)
                    }
                }

                if signedIn && !workosSignedIn {
                    Section("Link an existing WorkOS identity") {
                        Button("Link WorkOS to this account") {
                            Task { await linkWorkOS() }
                        }
                        .disabled(isBusy || currentAccessToken.isEmpty)
                    }
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

                if signedIn {
                    Section("Manage saved credentials") {
                        if savedCredentials.isEmpty {
                            Text("No credentials are saved on this iPhone.")
                                .font(.footnote)
                        } else {
                            ForEach(savedCredentials) { credential in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(credential.username)
                                        Text(credential.service)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Delete", role: .destructive) {
                                        Task { await deleteSavedCredential(credential) }
                                    }
                                    .disabled(isBusy)
                                }
                            }
                        }
                    }
                }

                if signedIn {
                    Section("Encrypted cloud vault") {
                        if VaultCryptography.hasVaultKey() {
                            Label("Vault encryption key is available in this iPhone's Keychain", systemImage: "lock.shield")
                                .font(.footnote)
                            Button("Synchronize encrypted vault") {
                                Task { await synchronizeEncryptedVault() }
                            }
                            .disabled(isBusy || currentAccessToken.isEmpty || !recoveryAcknowledged)
                        } else {
                            Text("Create a vault key before enabling encrypted cloud synchronization. The server will receive ciphertext only.")
                                .font(.footnote)
                            Button("Create encrypted vault and recovery code") {
                                createEncryptedVault()
                            }
                            .disabled(isBusy)
                        }

                        if !recoveryCode.isEmpty {
                            Text("Save this recovery code offline. It is shown only during this setup session.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                            Text(recoveryCode)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                            if !recoveryPackageJSON.isEmpty {
                                Button {
                                    showRecoveryExporter = true
                                } label: {
                                    Label("Export recovery package as JSON", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        if !recoveryAcknowledged {
                            Toggle("I have securely stored the recovery code and JSON recovery package", isOn: $recoveryAcknowledged)
                        }
                    }

                    Section("Restore vault on this iPhone") {
                        SecureField("Recovery code", text: $recoveryCodeInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Choose recovery package") {
                            showRecoveryImporter = true
                        }
                        .disabled(isBusy || recoveryCodeInput.isEmpty || VaultCryptography.hasVaultKey())
                        Text("Restore is available only when this device does not already contain a vault key. Existing keys are never overwritten.")
                            .font(.footnote)
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
            .fileImporter(isPresented: $showRecoveryImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                restoreEncryptedVault(from: result)
            }
            .fileExporter(
                isPresented: $showRecoveryExporter,
                document: RecoveryPackageDocument(text: recoveryPackageJSON),
                contentType: .json,
                defaultFilename: "AuthPlatform-Vault-Recovery"
            ) { result in
                switch result {
                case .success:
                    status = "Recovery package exported. Keep it separate from your offline recovery code."
                case .failure(let error):
                    status = "Recovery package export failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func createEncryptedVault() {
        do {
            let created = try VaultCryptography.createVaultKey()
            recoveryCode = created.recoveryCode
            recoveryPackageJSON = String(data: try JSONEncoder.prettyPrinted.encode(created.recoveryPackage), encoding: .utf8) ?? ""
            recoveryAcknowledged = false
            status = "Vault key created. Export the recovery package and store the recovery code offline before synchronizing."
        } catch {
            status = "Could not create the encrypted vault: \(error.localizedDescription)"
        }
    }

    private func restoreEncryptedVault(from result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let package = try JSONDecoder().decode(VaultCryptography.RecoveryPackage.self, from: data)
            try VaultCryptography.restoreVaultKey(recoveryCode: recoveryCodeInput, package: package)
            recoveryCodeInput = ""
            recoveryAcknowledged = false
            status = "Vault key restored securely. Confirm that you have safely stored the recovery code and package before synchronizing."
        } catch {
            status = "Vault recovery failed: \(error.localizedDescription)"
        }
    }

    private func deleteSavedCredential(_ credential: StoredPasswordCredential) async {
        isBusy = true
        defer { isBusy = false }
        do {
            guard let refreshToken = try AuthSessionVault.refreshToken() else {
                status = "Sign in again before deleting a synchronized credential."
                return
            }
            let api = try AuthPlatformAPI()
            let refreshed = try await api.refresh(refreshToken: refreshToken)
            try AuthSessionVault.save(refreshToken: refreshed.refreshToken)
            currentAccessToken = refreshed.accessToken
            try await EncryptedVaultService.delete(credential, api: api, accessToken: refreshed.accessToken)
            status = "Credential deleted locally and a server tombstone was recorded for other devices."
        } catch {
            status = "Credential was not deleted because secure synchronization could not be confirmed: \(error.localizedDescription)"
        }
    }

    private func synchronizeEncryptedVault() async {
        isBusy = true
        defer { isBusy = false }
        do {
            guard let refreshToken = try AuthSessionVault.refreshToken() else {
                status = "Your session has expired. Sign in again before synchronizing."
                return
            }
            let api = try AuthPlatformAPI()
            let refreshed = try await api.refresh(refreshToken: refreshToken)
            guard refreshed.emailVerified else {
                status = "Verify your account before synchronizing the vault."
                return
            }
            try AuthSessionVault.save(refreshToken: refreshed.refreshToken)
            currentAccessToken = refreshed.accessToken
            let changed = try await EncryptedVaultService.synchronize(api: api, accessToken: refreshed.accessToken)
            status = "Encrypted vault synchronized. \(changed) remote credential changes applied. The server received encrypted envelopes only."
        } catch {
            status = "Encrypted vault synchronization failed: \(error.localizedDescription)"
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
            currentAccessToken = tokens.accessToken
            signedIn = true
            status = "Signed in. Your refresh token is stored in the shared Keychain."
        } catch {
            status = error.localizedDescription
        }
    }

    private func signInWithWorkOS() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let workOS = try await WorkOSAuthKitService().signIn()
            let api = try AuthPlatformAPI()
            let appSession = try await api.exchangeWorkOS(accessToken: workOS.accessToken)
            guard appSession.emailVerified else {
                status = "Your WorkOS identity must have a verified email address."
                return
            }
            try AuthSessionVault.save(refreshToken: appSession.refreshToken)
            currentAccessToken = appSession.accessToken
            signedIn = true
            workosSignedIn = true
            status = "WorkOS sign-in completed and exchanged for a protected AuthPlatform session. Refresh token saved in Keychain."
        } catch {
            status = error.localizedDescription
        }
    }

    private func linkWorkOS() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let workOS = try await WorkOSAuthKitService().signIn()
            let api = try AuthPlatformAPI()
            try await api.linkWorkOS(
                localAccessToken: currentAccessToken,
                workOSAccessToken: workOS.accessToken
            )
            workosSignedIn = true
            status = "WorkOS identity securely linked to your signed-in AuthPlatform account."
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


private struct RecoveryPackageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let value = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = value
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
