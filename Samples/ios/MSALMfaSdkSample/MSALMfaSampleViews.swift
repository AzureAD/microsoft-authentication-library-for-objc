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

private let sampleBlue = Color(red: 0, green: 0.47, blue: 0.83)

private enum MSALMfaSampleRoute: Hashable
{
    case scanner
    case manualEntry
}

@MainActor
struct MSALMfaSampleAccountsView: View
{
    @StateObject private var model = MSALMfaSampleModel()
    @State private var path: [MSALMfaSampleRoute] = []

    var body: some View
    {
        NavigationStack(path: $path)
        {
            VStack(spacing: 0)
            {
                Text("MOCK REGISTRATIONS - No real MFA")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding()
                if model.registrations.isEmpty
                {
                    ContentUnavailableView(
                        "No registrations",
                        systemImage: "person.crop.rectangle",
                        description: Text("Use the QR button to add a mock account. Accounts reset when the app closes.")
                    )
                    .accessibilityIdentifier("mfa.emptyState")
                }
                else
                {
                    ScrollView
                    {
                        LazyVStack(spacing: 0)
                        {
                            ForEach(model.registrations)
                            { registration in
                                registrationRow(registration)
                                Divider().padding(.leading, 16)
                            }
                        }
                        .background(Color(uiColor: .secondarySystemBackground))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom)
            {
                HStack
                {
                    Spacer()
                    Button
                    {
                        path.append(.scanner)
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(sampleBlue, in: Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    }
                    .accessibilityLabel("Scan QR code")
                    .accessibilityHint("Opens a simulated scanner. No camera is used.")
                    .accessibilityIdentifier("mfa.openScanner")
                }
                .padding()
            }
            .navigationTitle("Accounts")
            .modifier(MSALMfaSampleNavigationStyle())
            .navigationDestination(for: MSALMfaSampleRoute.self)
            { route in
                switch route
                {
                case .scanner:
                    MSALMfaSampleScannerView(model: model, path: $path)
                case .manualEntry:
                    MSALMfaSampleManualEntryView(model: model, path: $path)
                }
            }
        }
        .tint(.white)
    }

    private func registrationRow(_ registration: MSALMfaSampleRegistration) -> some View
    {
        HStack(spacing: 16)
        {
            Image(systemName: "person.crop.rectangle")
                .font(.title)
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
                .background(Color(uiColor: .systemGray5), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6)
            {
                Text(verbatim: registration.name)
                    .font(.title3)
                Text(registration.source == .simulatedScan ? "MOCK - Simulated QR scan" : "MOCK - Manual entry")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mfa.registrationRow")
    }
}

@MainActor
private struct MSALMfaSampleScannerView: View
{
    @ObservedObject var model: MSALMfaSampleModel
    @Binding var path: [MSALMfaSampleRoute]
    @State private var operation: Task<Void, Never>?

    var body: some View
    {
        ScrollView
        {
            VStack(spacing: 24)
            {
                ZStack
                {
                    Rectangle().fill(.white.opacity(0.08))
                    MSALMfaSampleScanCorners()
                        .stroke(sampleBlue, lineWidth: 3)
                        .padding(16)
                    Image(systemName: "qrcode")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 320)
                .padding(.vertical, 24)
                .accessibilityHidden(true)

                Text("Your account provider will display a QR code")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                Text("SIMULATED SCANNER - No camera is active. This demo only creates mock registrations.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button
                {
                    guard operation == nil else { return }
                    operation = Task { @MainActor in
                        if await model.simulateScan()
                        {
                            path.removeAll()
                        }
                        operation = nil
                    }
                } label: {
                    Text(model.isRegistering ? "Adding mock account..." : "Simulate scan")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(model.isRegistering)
                .accessibilityIdentifier("mfa.simulateScan")

                NavigationLink(value: MSALMfaSampleRoute.manualEntry)
                {
                    Text("Enter code manually")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(sampleBlue, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(model.isRegistering)
                .accessibilityIdentifier("mfa.openManualEntry")
                MSALMfaSampleErrorView(error: model.validationError)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .background(Color(white: 0.08))
        .navigationTitle("Scan QR code")
        .modifier(MSALMfaSampleNavigationStyle())
        .onDisappear
        {
            operation?.cancel()
            operation = nil
            model.cancelRegistration()
        }
    }
}

@MainActor
private struct MSALMfaSampleManualEntryView: View
{
    @ObservedObject var model: MSALMfaSampleModel
    @Binding var path: [MSALMfaSampleRoute]
    @State private var accountName = ""
    @State private var secret = ""
    @State private var operation: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable
    {
        case name
        case secret
    }

    var body: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 0)
            {
                Text("OTHER ACCOUNT")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 32)
                    .padding(.bottom, 8)

                VStack(spacing: 0)
                {
                    TextField("Account name", text: $accountName)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .secret }
                        .accessibilityIdentifier("mfa.accountName")
                        .padding(16)
                    Divider().padding(.leading, 16)
                    SecureField("Secret key", text: $secret)
                        .focused($focusedField, equals: .secret)
                        .submitLabel(.done)
                        .onSubmit { finish() }
                        .accessibilityIdentifier("mfa.secretKey")
                        .padding(16)
                }
                .font(.title3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(sampleBlue)
                .background(Color(uiColor: .systemBackground))
                .disabled(model.isRegistering)

                Button(action: finish)
                {
                    Text(model.isRegistering ? "Adding mock account..." : "Finish")
                        .font(.title3)
                        .foregroundStyle(canFinish ? Color.white : Color(uiColor: .secondaryLabel))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(canFinish ? sampleBlue : Color(uiColor: .systemGray4))
                }
                .disabled(!canFinish)
                .padding(.top, 36)
                .accessibilityIdentifier("mfa.finishManualEntry")

                Text("MOCK ONLY. Enter a synthetic name and key. The key is ignored and discarded; no key is validated or stored and no account is enrolled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                MSALMfaSampleErrorView(error: model.validationError)
                    .padding(.horizontal, 16)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Add account")
        .modifier(MSALMfaSampleNavigationStyle())
        .onDisappear
        {
            operation?.cancel()
            operation = nil
            model.cancelRegistration()
            secret = ""
            accountName = ""
        }
    }

    private var canFinish: Bool
    {
        operation == nil && !model.isRegistering && MSALMfaSampleModel.canFinish(name: accountName, secret: secret)
    }

    private func finish()
    {
        guard canFinish else { return }
        focusedField = nil
        let enteredName = accountName
        let enteredSecret = secret
        secret = ""
        operation = Task { @MainActor in
            if await model.finishManualEntry(name: enteredName, secret: enteredSecret)
            {
                path.removeAll()
            }
            operation = nil
        }
    }
}

private struct MSALMfaSampleNavigationStyle: ViewModifier
{
    func body(content: Content) -> some View
    {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(sampleBlue, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct MSALMfaSampleErrorView: View
{
    let error: MSALMfaSampleModel.ValidationError?

    var body: some View
    {
        if let error
        {
            Text(message(for: error))
                .font(.footnote)
                .accessibilityIdentifier("mfa.registrationError")
        }
    }

    private func message(for error: MSALMfaSampleModel.ValidationError) -> LocalizedStringKey
    {
        switch error
        {
        case .missingName: return "Enter a synthetic account name."
        case .missingSecret: return "Enter a synthetic secret key."
        case .unexpectedResult: return "The demo expected a mock result. No account was added."
        }
    }
}

private struct MSALMfaSampleScanCorners: Shape
{
    func path(in rect: CGRect) -> Path
    {
        let length = min(rect.width, rect.height) * 0.16
        return Path
        { path in
            for (x, y, dx, dy) in [
                (rect.minX, rect.minY, length, length),
                (rect.maxX, rect.minY, -length, length),
                (rect.minX, rect.maxY, length, -length),
                (rect.maxX, rect.maxY, -length, -length)
            ]
            {
                path.move(to: CGPoint(x: x + dx, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + dy))
            }
        }
    }
}
