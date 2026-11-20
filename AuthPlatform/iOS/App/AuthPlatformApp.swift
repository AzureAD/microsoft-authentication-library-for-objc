import SwiftUI

@main
struct AuthPlatformApp: App {
    var body: some Scene {
        WindowGroup {
            AuthenticationDemoView()
        }
    }
}

private struct AuthenticationDemoView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var newPassword = ""
    @State private var verificationCode = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sign in") {
                    TextField("Email or username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                Section("Create or update password") {
                    SecureField("New password", text: $newPassword)
                        .textContentType(.newPassword)
                }

                Section("Verification") {
                    TextField("One-time code", text: $verificationCode)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                }

                Section {
                    Text("This starter screen demonstrates Apple Password AutoFill field semantics. Connect these fields to the AuthPlatform API before production use.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AuthPlatform")
        }
    }
}
