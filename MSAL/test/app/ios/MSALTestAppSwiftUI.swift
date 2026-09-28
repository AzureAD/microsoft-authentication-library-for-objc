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

import SwiftUI
import WebKit

@objc(MSALTestAppSwiftRootController)
final class MSALTestAppSwiftRootController: UIViewController {
    private var engine: MSALTestAppAcquireTokenViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        let storyboard = UIStoryboard(name: "MSALTestAppAcquireTokenViewController", bundle: nil)
        engine = storyboard.instantiateViewController(
            withIdentifier: "MSALTestAppAcquireTokenViewController"
        ) as? MSALTestAppAcquireTokenViewController
        addChild(engine)
        engine.view.frame = .zero
        engine.view.isHidden = true
        view.addSubview(engine.view)
        engine.didMove(toParent: self)

        let model = MSALTestAppScreenModel(engine: engine)
        let host = UIHostingController(rootView: MSALTestAppScreen(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}

private final class MSALTestAppScreenModel: ObservableObject {
    let engine: MSALTestAppAcquireTokenViewController
    let cache = MSALTestAppCacheViewController()
    let logger = MSALTestAppLogViewController()
    let settings = MSALTestAppSettings.shared()!
    @Published var profile: String = MSALTestAppSettings.currentProfileName() ?? ""
    @Published var scopes = ""
    @Published var authority = ""
    @Published var accountIdentifier = ""
    @Published var accounts: [MSALAccount] = []
    @Published var loginHint = ""
    @Published var extraQuery = ""
    @Published var prompt = 0
    @Published var webview = 0
    @Published var customWebview = false
    @Published var ephemeralSSO = false
    @Published var validateAuthority = true
    @Published var instanceAware = false
    @Published var claims = false
    @Published var pop = false
    @Published var atsStarvation = false
    @Published var result = ""
    @Published var status = "Ready"
    @Published var inputError: String?
    @Published var cacheEntries: [[String: Any]] = []
    @Published var cacheError: String?
    @Published var log = ""
    @Published var events: [[String: String]] = []
    @Published var selectedPreset = ""
    @Published var customClientId = ""
    @Published var customRedirectUri = ""
    @Published var boundAppRefreshTokens = MSALTestAppSettingsViewController.swiftUIBoundAppRefreshTokensEnabled()

    init(engine: MSALTestAppAcquireTokenViewController) {
        self.engine = engine
        scopes = Array(settings.scopes).sorted().joined(separator: " ")
        authority = settings.authority?.url.absoluteString ?? ""
        validateAuthority = settings.validateAuthority
        loginHint = settings.loginHint ?? ""
        _ = cache.view
        _ = logger.view
        refresh()
    }

    var presets: [[String: Any]] {
        MSALTestAppSettings.configurationPresets(forPlatform: "ios")
    }

    var currentProfile: [AnyHashable: Any] {
        MSALTestAppSettings.currentProfile()
    }

    func selectProfile(_ name: String) {
        guard settings.setCurrentProfileByName(name) else {
            inputError = "Unknown profile: \(name)"
            return
        }
        profile = name
        refreshAccounts()
    }

    func applyPreset(_ preset: [String: Any]) {
        selectedPreset = preset["name"] as? String ?? ""
        if let scope = preset["scope"] as? String { scopes = scope }
        if let value = preset["validateAuthority"] as? Bool { validateAuthority = value }
        if let value = preset["instanceAware"] as? Bool { instanceAware = value }
        if let value = preset["claims"] as? Bool { claims = value }
        if let value = preset["atsStarvation"] as? Bool { atsStarvation = value }
        if let value = preset["prompt"] as? String, value == "Default" { prompt = 4 }
        if let value = preset["authority"] as? String { authority = value }
        if preset["requiresTenantAuthority"] as? Bool == true {
            authority = ""
            inputError = "Select the Microsoft Online tenant authority before acquiring."
        } else {
            inputError = nil
        }
    }

    func prepare(requireScopes: Bool = true) -> Bool {
        if profile == "Custom" {
            settings.customClientId = customClientId
            settings.customRedirectUri = customRedirectUri
            guard UUID(uuidString: customClientId) != nil else {
                inputError = "Enter a valid client ID (UUID) in the Custom profile."
                return false
            }
            guard let parts = URLComponents(string: customRedirectUri),
                  parts.scheme != nil, parts.host?.isEmpty == false,
                  !customRedirectUri.contains(where: \.isWhitespace) else {
                inputError = "Enter a valid absolute redirect URI with a scheme and host."
                return false
            }
        }
        if requireScopes, let error = settings.updateScopes(withText: scopes) {
            inputError = error
            return false
        }
        if selectedPreset == "Cross-domain · Microsoft Online" &&
           !(authority.hasPrefix("https://login.microsoftonline.com/") &&
             authority.count > "https://login.microsoftonline.com/".count) {
            inputError = "Enter the Microsoft Online tenant authority for this phase."
            return false
        }
        if authority.isEmpty {
            settings.authority = nil
        } else if let error = engine.updateSwiftUIAuthority(authority) {
            inputError = error
            return false
        }
        engine.configureForSwiftUI(
            withLoginHint: loginHint,
            extraQuery: extraQuery,
            prompt: prompt,
            webview: webview,
            customWebview: customWebview,
            ephemeralSSO: ephemeralSSO,
            validateAuthority: validateAuthority,
            instanceAware: instanceAware,
            claims: claims,
            pop: pop,
            atsStarvation: atsStarvation
        )
        inputError = nil
        return true
    }

    func run(_ action: String) {
        if (action == "silent" || action == "signout") && settings.currentAccount == nil {
            inputError = "Select an account before \(action == "silent" ? "silent acquisition" : "sign-out")."
            return
        }
        guard prepare(requireScopes: action != "clear" && action != "signout") else { return }
        status = "Running \(action)…"
        engine.runSwiftUIAction(action)
        refresh()
    }

    func refreshAccounts() {
        guard profile != "Custom" || UUID(uuidString: customClientId) != nil else { return }
        engine.availableAccounts { [weak self] accounts, error in
            self?.accounts = accounts ?? []
            if let error = error { self?.inputError = error.localizedDescription }
        }
    }

    func selectAccount(_ identifier: String) {
        accountIdentifier = identifier
        settings.currentAccount = accounts.first { $0.identifier == identifier }
    }

    func addKnownScope(_ scope: String) {
        let existing = scopes.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
        if !existing.contains(scope) {
            let current = scopes.trimmingCharacters(in: .whitespacesAndNewlines)
            scopes = current.isEmpty ? scope : "\(current) \(scope)"
        }
    }

    func refresh() {
        if settings.currentAccount == nil && !accountIdentifier.isEmpty {
            accountIdentifier = ""
        }
        let latestResult = engine.swiftUIResult() ?? ""
        if latestResult != result && !latestResult.isEmpty {
            status = "Response available"
        }
        result = latestResult
        log = logger.swiftUILog()
        cacheEntries = cache.swiftUICacheEntries()
        events = MSALTestAppTelemetryViewController.shared().swiftUIEvents()
    }

}

private struct MSALTestAppScreen: View {
    @ObservedObject var model: MSALTestAppScreenModel
    @State private var showClearConfirmation = false
    @State private var showSignoutConfirmation = false
    @State private var showCacheConfirmation: (String, [String: Any])?
    @State private var selectedCacheEntry: [String: Any]?
    @State private var showProfileDetails = false

    var body: some View {
        TabView {
            NavigationStack {
                Form {
                    sessionSection
                    Section("Acquire") {
                        TextField("Scopes · separate with spaces or commas", text: $model.scopes)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("select-scopes")
                        Menu("Add known scope") {
                            ForEach(MSALTestAppSettings.availableScopes(), id: \.self) { scope in
                                Button(scope) { model.addKnownScope(scope) }
                            }
                        }
                        if let error = model.inputError {
                            Text(error).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently)
                        }
                        Button("Acquire interactively") { model.run("interactive") }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("acquireTokenInteractive")
                        Button("Acquire silently") { model.run("silent") }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("acquireTokenSilent")
                        Text(model.status).font(.footnote).foregroundStyle(.secondary)
                        if !model.result.isEmpty {
                            Text(model.result).font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .accessibilityIdentifier("result")
                        } else {
                            Text("Choose a scope, then acquire a token to inspect the result.")
                                .foregroundStyle(.secondary)
                        }

                    }
                    Section("Configuration presets · inputs only") {
                        ForEach(model.presets.indices, id: \.self) { index in
                            let preset = model.presets[index]
                            Button(preset["name"] as? String ?? "") { model.applyPreset(preset) }
                                .accessibilityHint(preset["sources"] as? String ?? "")
                        }
                        if let preset = model.presets.first(where: { ($0["name"] as? String) == model.selectedPreset }) {
                            Text(preset["sources"] as? String ?? "").font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Clear preset") {
                                model.selectedPreset = ""
                                model.inputError = nil
                            }
                        }
                    }
                    Section("Authority & browser") {
                        TextField("Authority URL · blank for default", text: $model.authority)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("select-authority")
                        Picker("Known authority", selection: $model.authority) {
                            Text("Default").tag("")
                            ForEach(MSALTestAppSettings.aadAuthorities() +
                                    MSALTestAppSettings.b2cAuthorities(), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        Toggle("Validate authority", isOn: $model.validateAuthority)
                            .accessibilityIdentifier(model.validateAuthority ? "validateAuthorityYes" : "validateAuthorityNo")
                        Toggle("Instance aware", isOn: $model.instanceAware)
                            .accessibilityIdentifier(model.instanceAware ? "instanceAwareYes" : "instanceAwareNo")
                        Picker("Browser", selection: $model.webview) {
                            Text("Embedded").tag(0)
                            Text("System").tag(1)
                        }
                        Toggle("Custom WKWebView", isOn: $model.customWebview)
                            .disabled(model.webview != 0)
                        if model.webview == 0 && model.customWebview {
                            MSALTestAppWebView(webView: model.engine.swiftUICustomWebview())
                                .frame(minHeight: 340)
                            Button("Cancel custom web authentication") {
                                model.engine.runSwiftUIAction("cancel")
                            }
                        }
                        Toggle("Ephemeral system session", isOn: $model.ephemeralSSO)
                            .disabled(model.webview != 1)
                            .accessibilityIdentifier(model.ephemeralSSO ? "systemWebViewNo" : "systemWebViewYes")
                        Button("Cancel web authentication") { model.engine.runSwiftUIAction("cancel") }
                    }

                    Section("Request options") {
                        TextField("Login hint", text: $model.loginHint)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("select-loginhint")
                        TextField("Extra query parameters", text: $model.extraQuery)
                            .accessibilityIdentifier("select-eqp")
                        Picker("Prompt", selection: $model.prompt) {
                            ForEach(Array(["Select", "Login", "Consent", "Create", "Default"].enumerated()), id: \.offset) { index, name in
                                Text(name).tag(index)
                            }
                        }

                        Toggle("Device ID claim", isOn: $model.claims)
                        Toggle("Proof of possession", isOn: $model.pop)
                        Toggle("ATS thread starvation", isOn: $model.atsStarvation)
                        Menu("Run stress test") {
                            Button("Silent · same token") { model.run("stressSame") }
                            Button("Silent · expiring token") { model.run("stressExpiring") }
                            Button("Silent · multiple users") { model.run("stressUsers") }
                            Button("Silent · until success") { model.run("stressUntilSuccess") }
                            Button("Stop stress test") { model.engine.runSwiftUIAction("stressStop") }
                        }
                    }
                    Section("Account & cache actions") {
                        Button("Sign out selected account") { showSignoutConfirmation = true }
                            .disabled(model.accountIdentifier.isEmpty)
                        Button("Clear cache", role: .destructive) { showClearConfirmation = true }
                    }
                    Section("Device & cache policy") {
                        LabeledContent(
                            "Keychain sharing group",
                            value: MSALTestAppSettingsViewController.swiftUIKeychainSharingGroup()
                        )
                        ForEach(MSALTestAppSettingsViewController.swiftUIDeviceInformation().keys.sorted(), id: \.self) { key in
                            LabeledContent(
                                key,
                                value: MSALTestAppSettingsViewController.swiftUIDeviceInformation()[key] ?? ""
                            )
                        }
                        Toggle("Request bound app refresh tokens", isOn: $model.boundAppRefreshTokens)
                            .onChange(of: model.boundAppRefreshTokens) { _, enabled in
                                MSALTestAppSettingsViewController.setSwiftUIBoundAppRefreshTokensEnabled(enabled)
                            }
                    }
                }
                .navigationTitle("Acquire")
                .onAppear { model.refreshAccounts() }
            }
            .tabItem { Label("Acquire", systemImage: "key.fill") }

            NavigationStack {
                List {
                    Button("Refresh cache") { model.cache.refreshSwiftUICache(); model.refresh() }
                    if let error = model.cacheError {
                        Text(error).foregroundStyle(.red)
                    }
                    ForEach(model.cacheEntries.indices, id: \.self) { index in
                        let entry = model.cacheEntries[index]
                        Button {
                            selectedCacheEntry = entry
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry["section"] as? String ?? "").font(.caption).foregroundStyle(.secondary)
                                Text(entry["title"] as? String ?? "Credential").font(.body)
                                Text(entry["subtitle"] as? String ?? "").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            ForEach(entry["actions"] as? [String] ?? [], id: \.self) { action in
                                Button(action, role: action.hasPrefix("Delete") ? .destructive : nil) {
                                    showCacheConfirmation = (action, entry)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Cache")
                .overlay {
                    if model.cacheEntries.isEmpty {
                        ContentUnavailableView("No credentials", systemImage: "tray",
                                               description: Text("Refresh after acquiring a token."))
                    }
                }
            }
            .tabItem { Label("Cache", systemImage: "tray.full") }

            NavigationStack {
                List {
                    Section("Execution result") {
                        Text(model.result.isEmpty ? "No request yet." : model.result)
                            .textSelection(.enabled)
                    }
                    Section("Telemetry") {
                        Button("Clear telemetry") {
                            MSALTestAppTelemetryViewController.shared().clearSwiftUIEvents()
                            model.refresh()
                        }
                        ForEach(model.events.indices, id: \.self) { index in
                            Text(model.events[index].map { "\($0.key): \($0.value)" }
                                    .sorted().joined(separator: "\n"))
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    Section("Logs · PII excluded") {
                        Text(model.log.isEmpty ? "No log messages yet." : model.log)
                            .font(.footnote.monospaced()).textSelection(.enabled)
                    }
                }
                .navigationTitle("Diagnostics")
            }
            .tabItem { Label("Inspect", systemImage: "waveform.path.ecg") }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in model.refresh() }
        .confirmationDialog("Clear all cached credentials?", isPresented: $showClearConfirmation) {
            Button("Clear cache", role: .destructive) { model.run("clear") }
        }
        .confirmationDialog("Sign out the selected account?", isPresented: $showSignoutConfirmation) {
            Button("Sign out", role: .destructive) { model.run("signout") }
        }
        .confirmationDialog("Modify cached credential?", isPresented: Binding(
            get: { showCacheConfirmation != nil },
            set: { if !$0 { showCacheConfirmation = nil } }
        )) {
            if let (action, entry) = showCacheConfirmation, let item = entry["item"] {
                Button(action, role: action.hasPrefix("Delete") ? .destructive : nil) {
                    if !model.cache.performSwiftUICacheAction(action, entry: item) {
                        model.cacheError = "Cache changed. Refresh and try again."
                    } else {
                        model.cacheError = nil
                    }
                    model.refresh()
                    showCacheConfirmation = nil
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedCacheEntry != nil },
            set: { if !$0 { selectedCacheEntry = nil } }
        )) {
            NavigationStack {
                ScrollView {
                    if let item = selectedCacheEntry?["item"] {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sensitive cache data may be shown. Do not share screenshots or copied values.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(model.cache.swiftUICacheDetail(forEntry: item) ?? "No cache details available.")
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                                .privacySensitive()
                        }
                        .padding()
                    }
                }
                .navigationTitle("Cache details")
                .toolbar {
                    Button("Done") { selectedCacheEntry = nil }
                }
            }
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            Picker("Profile", selection: $model.profile) {
                ForEach(MSALTestAppSettings.profileNames(), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .accessibilityIdentifier("select-profile")
            .onChange(of: model.profile) { _, name in model.selectProfile(name) }
            if model.profile == "Custom" {
                TextField("Client ID (UUID)", text: $model.customClientId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Redirect URI", text: $model.customRedirectUri)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Custom values remain in this session only.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                DisclosureGroup("Profile details", isExpanded: $showProfileDetails) {
                    LabeledContent("Client ID", value: model.currentProfile["clientId"] as? String ?? "")
                    LabeledContent("Redirect URI", value: model.currentProfile["redirectUri"] as? String ?? "")
                    if let nestedId = model.currentProfile["nestedAuthBrokerClientId"] as? String {
                        LabeledContent("Nested broker client ID", value: nestedId)
                    }
                    if let nestedRedirect = model.currentProfile["nestedAuthBrokerRedirectUri"] as? String {
                        LabeledContent("Nested broker redirect URI", value: nestedRedirect)
                    }
                }
            }
            Picker("Account", selection: $model.accountIdentifier) {
                Text("None").tag("")
                ForEach(model.accounts, id: \.identifier) { account in
                    Text(account.username ?? account.identifier ?? "Account")
                        .tag(account.identifier ?? "")
                }
            }
            .accessibilityIdentifier("select-user")
            .onChange(of: model.accountIdentifier) { _, identifier in model.selectAccount(identifier) }
            LabeledContent("Authority") {
                Text(model.authority.isEmpty ? "Default" : model.authority)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel(model.authority.isEmpty ? "Default authority" : model.authority)
            }
            Button("Refresh accounts") { model.refreshAccounts() }
        }
    }
}

private struct MSALTestAppWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView.removeFromSuperview()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
