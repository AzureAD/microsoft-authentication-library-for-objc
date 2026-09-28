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

import AppKit
import SwiftUI
import WebKit

@MainActor
private final class DashboardModel: ObservableObject
{
    let acquire: MSALAcquireTokenViewController
    let cache: MSALCacheViewController
    @Published var values: [String: String] = [:]
    @Published var profiles: [String] = []
    @Published var authorities: [String] = []
    @Published var availableScopes: [String] = []
    @Published var presets: [[String: Any]] = []
    @Published var presetDescription = ""
    @Published var accounts: [String] = []
    @Published var rows: [[String: Any]] = []
    @Published var result = ""
    @Published var message = ""
    @Published var webViewVisible = false
    private var observer: NSObjectProtocol?
    private var cacheObserver: NSObjectProtocol?

    init(acquire: MSALAcquireTokenViewController, cache: MSALCacheViewController)
    {
        self.acquire = acquire
        self.cache = cache
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: .MSALMacDashboardDidUpdate,
            object: acquire,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
        cacheObserver = NotificationCenter.default.addObserver(
            forName: .MSALTestAppCacheChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshCache() }
        }
    }

    deinit
    {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let cacheObserver { NotificationCenter.default.removeObserver(cacheObserver) }
    }

    func refresh()
    {
        let state = acquire.dashboardState()
        profiles = state["profiles"] as? [String] ?? []
        authorities = state["authorities"] as? [String] ?? []
        availableScopes = state["availableScopes"] as? [String] ?? []
        presets = MSALTestAppSettings.configurationPresets(forPlatform: "mac")
        accounts = state["accounts"] as? [String] ?? []
        for key in [
            "profile", "clientId", "redirectUri", "authority", "scopes", "account",
            "loginHint", "extraQuery", "prompt", "authScheme", "webView"
        ]
        {
            values[key] = state[key] as? String ?? ""
        }
        values["validateAuthority"] = (state["validateAuthority"] as? NSNumber)?.boolValue == true ? "true" : "false"
        values["pressureTest"] = (state["pressureTest"] as? NSNumber)?.boolValue == true ? "true" : "false"
        values["xpcMode"] = String((state["xpcMode"] as? NSNumber)?.intValue ?? 0)
        refreshStatus()
    }

    func refreshStatus()
    {
        let state = acquire.dashboardState()
        result = state["result"] as? String ?? ""
        webViewVisible = (state["webViewVisible"] as? NSNumber)?.boolValue ?? false
        accounts = state["accounts"] as? [String] ?? []
    }

    func refreshCache()
    {
        rows = cache.dashboardRows()
    }

    func chooseProfile(_ name: String)
    {
        values["profile"] = name
        if acquire.selectDashboardProfile(name)
        {
            refresh()
            message = ""
        }
    }

    func useScope(_ scope: String)
    {
        let current = values["scopes"] ?? ""
        let parts = current.split(whereSeparator: { $0 == "," || $0.isWhitespace }).map(String.init)
        if !parts.contains(scope)
        {
            values["scopes"] = (parts + [scope]).joined(separator: ", ")
        }
    }

    func applyPreset(_ preset: [String: Any])
    {
        if let scope = preset["scope"] as? String { values["scopes"] = scope }
        if let authority = preset["authority"] as? String { values["authority"] = authority }
        if let validate = preset["validateAuthority"] as? NSNumber
        {
            values["validateAuthority"] = validate.boolValue ? "true" : "false"
        }
        if let prompt = preset["prompt"] as? String { values["prompt"] = prompt }
        presetDescription = preset["sources"] as? String ?? ""
        message = ""
    }

    func run(_ action: String)
    {
        do
        {
            try acquire.updateDashboard(withValues: values)
            message = ""
            acquire.performDashboardAction(action)
            refreshStatus()
            if action == "cache" { refreshCache() }
        }
        catch
        {
            message = error.localizedDescription
        }
    }

    func cancel()
    {
        acquire.performDashboardAction("cancel")
        refreshStatus()
    }

    func stopPressure()
    {
        acquire.performDashboardAction("stopPressure")
        values["pressureTest"] = "false"
        refreshStatus()
    }

    func cacheAction(_ action: String, index: Int)
    {
        cache.performDashboardAction(action, row: index)
        refreshCache()
    }

    func binding(_ key: String) -> Binding<String>
    {
        Binding(
            get: { self.values[key] ?? "" },
            set: { self.values[key] = $0 }
        )
    }
}

private enum DashboardPage: String, CaseIterable, Identifiable
{
    case acquire = "Acquire token"
    case cache = "Token cache"
    var id: Self { self }
    var icon: String { self == .acquire ? "key.horizontal" : "externaldrive" }
}

private struct DashboardView: View
{
    @ObservedObject var model: DashboardModel
    @State private var page: DashboardPage? = .acquire

    var body: some View
    {
        NavigationSplitView
        {
            List(DashboardPage.allCases, selection: $page)
            { destination in
                Label(destination.rawValue, systemImage: destination.icon)
                    .tag(destination)
            }
            .navigationTitle("MSAL Test App")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        }
        detail:
        {
            if page == .cache
            {
                cachePage
            }
            else
            {
                acquirePage
            }
        }
        .frame(minWidth: 850, minHeight: 620)
    }

    private var acquirePage: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 24)
            {
                VStack(alignment: .leading, spacing: 5)
                {
                    Text("Acquire a token").font(.largeTitle.weight(.semibold))
                    Text("Configure the request, then run an interactive or silent flow.")
                        .foregroundStyle(.secondary)
                }
                if !model.presets.isEmpty
                {
                    HStack
                    {
                        Menu("Apply test preset")
                        {
                            ForEach(model.presets.indices, id: \.self)
                            { index in
                                let preset = model.presets[index]
                                Button(preset["name"] as? String ?? "Preset")
                                {
                                    model.applyPreset(preset)
                                }
                            }
                        }
                        if !model.presetDescription.isEmpty
                        {
                            Text(model.presetDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                GroupBox("Application")
                {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12)
                    {
                        GridRow
                        {
                            Text("Profile")
                            Picker("Profile", selection: model.binding("profile"))
                            {
                                ForEach(model.profiles, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .onChange(of: model.values["profile"])
                            { _, newValue in
                                if let newValue { model.chooseProfile(newValue) }
                            }
                        }
                        GridRow
                        {
                            Text("Client ID")
                            TextField("Client ID", text: model.binding("clientId"))
                                .disabled(model.values["profile"] != "Custom")
                        }
                        GridRow
                        {
                            Text("Redirect URI")
                            TextField("Redirect URI", text: model.binding("redirectUri"))
                                .disabled(model.values["profile"] != "Custom")
                        }
                        GridRow
                        {
                            Text("Authority")
                            TextField("Authority URL", text: model.binding("authority"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                GroupBox("Request")
                {
                    VStack(alignment: .leading, spacing: 14)
                    {
                        LabeledContent("Scopes")
                        {
                            TextField("Space- or comma-separated scopes", text: model.binding("scopes"))
                        }
                        HStack(spacing: 8)
                        {
                            Text("Add a scope").foregroundStyle(.secondary)
                            Menu("Available scopes")
                            {
                                ForEach(model.availableScopes, id: \.self)
                                { scope in
                                    Button(scope) { model.useScope(scope) }
                                }
                            }
                        }
                        LabeledContent("Account")
                        {
                            Picker("Account", selection: model.binding("account"))
                            {
                                ForEach(model.accounts, id: \.self)
                                { account in
                                    Text(account.isEmpty ? "Select an account" : account).tag(account)
                                }
                            }
                            .labelsHidden()
                        }
                        LabeledContent("Login hint")
                        {
                            TextField("Optional login hint", text: model.binding("loginHint"))
                        }
                        LabeledContent("Extra query parameters")
                        {
                            TextField("key=value&key2=value2", text: model.binding("extraQuery"))
                        }
                        HStack(spacing: 18)
                        {
                            Picker("Prompt", selection: model.binding("prompt"))
                            {
                                ForEach(["Select", "Login", "Consent", "Create", "Default"], id: \.self)
                                { Text($0).tag($0) }
                            }
                            Picker("Authentication", selection: model.binding("authScheme"))
                            {
                                Text("Bearer").tag("Bearer")
                                Text("PoP").tag("Pop")
                            }
                            Picker("Web view", selection: model.binding("webView"))
                            {
                                Text("MSAL").tag("MSAL")
                                Text("Custom WKWebView").tag("Passed In")
                            }
                        }
                        Toggle("Validate authority", isOn: booleanBinding("validateAuthority"))
                    }
                    .padding(10)
                }
                GroupBox("macOS XPC")
                {
                    HStack
                    {
                        Picker("XPC mode", selection: model.binding("xpcMode"))
                        {
                            Text("Disabled").tag("0")
                            Text("SSO extension companion").tag("1")
                            Text("SSO extension backup").tag("2")
                            Text("Primary").tag("3")
                        }
                        Toggle("Pressure test (repeats every 5 minutes)", isOn: booleanBinding("pressureTest"))
                        Button("Stop test") { model.stopPressure() }
                    }
                    .padding(10)
                }
                HStack(spacing: 10)
                {
                    Button("Acquire interactively") { model.run("interactive") }
                        .buttonStyle(.borderedProminent)
                    Button("Acquire silently") { model.run("silent") }
                    Button("Cancel authentication") { model.cancel() }
                    Spacer()
                }
                if model.webViewVisible
                {
                    GroupBox("Authentication")
                    {
                        DashboardWebView(controller: model.acquire)
                            .frame(minHeight: 360)
                    }
                }
                GroupBox("Result & status")
                {
                    VStack(alignment: .leading, spacing: 10)
                    {
                        if !model.message.isEmpty
                        {
                            Label(model.message, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                        Text(model.result.isEmpty ? "No request has run yet." : model.result)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                }
                HStack
                {
                    Button("Sign out selected account") { model.run("signout") }
                    Button("Sign out and wipe all accounts") { model.run("wipe") }
                    Spacer()
                    Button("Clear cookies") { model.run("cookies") }
                    Button("Clear cache") { model.run("cache") }
                }
            }
            .padding(28)
            .frame(maxWidth: 1050, alignment: .leading)
        }
        .navigationTitle("Acquire token")
    }

    private var cachePage: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            HStack
            {
                VStack(alignment: .leading, spacing: 5)
                {
                    Text("Token cache").font(.largeTitle.weight(.semibold))
                    Text("Inspect account entries and expire, invalidate, or remove cached items.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") { model.refreshCache() }
                Button("Clear all") { model.run("cache") }
            }
            if model.rows.isEmpty
            {
                ContentUnavailableView("No cache entries", systemImage: "externaldrive",
                                       description: Text("Acquire a token to populate the cache."))
            }
            else
            {
                List
                {
                    ForEach(model.rows.indices, id: \.self)
                    { index in
                        let row = model.rows[index]
                        HStack(spacing: 16)
                        {
                            VStack(alignment: .leading, spacing: 5)
                            {
                                Text(row["title"] as? String ?? "Entry").font(.headline)
                                Text(row["section"] as? String ?? "")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(row["detail"] as? String ?? "")
                                    .font(.subheadline).textSelection(.enabled)
                            }
                            Spacer()
                            let action = row["action"] as? String ?? "Delete"
                            if action != "Delete"
                            {
                                Button(action) { model.cacheAction(action.lowercased(), index: index) }
                            }
                            Button("Delete", role: .destructive)
                            {
                                model.cacheAction("delete", index: index)
                            }
                        }
                        .padding(.vertical, 7)
                    }
                }
            }
        }
        .padding(28)
        .navigationTitle("Token cache")
        .onAppear { model.refreshCache() }
    }

    private func booleanBinding(_ key: String) -> Binding<Bool>
    {
        Binding(
            get: { model.values[key] == "true" },
            set: { model.values[key] = $0 ? "true" : "false" }
        )
    }
}

private struct DashboardWebView: NSViewRepresentable
{
    let controller: MSALAcquireTokenViewController

    func makeNSView(context: Context) -> WKWebView
    {
        controller.dashboardWebView()
    }

    func updateNSView(_ view: WKWebView, context: Context)
    {
        view.isHidden = false
    }
}

@objc(MSALMacDashboardFactory)
@MainActor
final class MSALMacDashboardFactory: NSObject
{
    @objc(rootControllerWithAcquireController:cacheController:)
    static func rootController(
        acquireController: MSALAcquireTokenViewController,
        cacheController: MSALCacheViewController
    ) -> NSViewController
    {
        let model = DashboardModel(acquire: acquireController, cache: cacheController)
        let host = NSHostingController(rootView: DashboardView(model: model))
        acquireController.dashboardPresentationController = host
        return host
    }
}
