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
import MSAL

@main
struct MSALMfaSdkSampleApp: App
{
    var body: some Scene
    {
        WindowGroup
        {
            MSALMfaSdkSampleView()
        }
    }
}

@MainActor
private struct MSALMfaSdkSampleView: View
{
    private let manager = MSALNativeAuthMfaSdkManager()
    @State private var qrCode = "mock-qr-activation"
    @State private var registration: MSALNativeAuthMfaSdkRegistrationResult?
    @State private var session: MSALNativeAuthMfaSdkAuthSession?
    @State private var number = ""
    @State private var isBusy = false
    @State private var status: LocalizedStringKey = "MOCK: Ready. No real MFA will be performed."

    var body: some View
    {
        NavigationStack
        {
            Form
            {
                Section
                {
                    Text("MOCK ONLY - NOT REAL MFA")
                        .font(.headline)
                    Text("No sign-in, network, enrollment, push registration, or camera. Use synthetic input only.")
                }

                Section("QR activation")
                {
                    TextField("Synthetic QR text", text: $qrCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("mfa.qrInput")
                    Button("Activate mock registration", action: activate)
                        .disabled(isBusy || qrCode.isEmpty)
                        .accessibilityIdentifier("mfa.activate")
                    if let registration
                    {
                        Text("MOCK receipt: \(registration.registrationId)")
                    }
                }

                Section("Challenge and number")
                {
                    Button("Load mock challenge", action: loadChallenge)
                        .disabled(isBusy || registration == nil)
                        .accessibilityIdentifier("mfa.loadChallenge")
                    if let session
                    {
                        Text("MOCK challenge: \(session.guid)")
                        Text("Simulated sign-in number: \(session.firstEntropyNumber)")
                        TextField("Enter simulated number", text: $number)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("mfa.numberInput")
                        Text("Phase 1 ignores the number. Approval is a fixed mock response, not number verification.")
                        Button("Approve mock challenge")
                        {
                            respond(to: session, approve: true)
                        }
                        .disabled(isBusy || number.isEmpty)
                        .accessibilityIdentifier("mfa.approve")
                        Button("Deny mock challenge", role: .destructive)
                        {
                            respond(to: session, approve: false)
                        }
                        .disabled(isBusy)
                        .accessibilityIdentifier("mfa.deny")
                    }
                }

                Section("Mock outcome")
                {
                    Text(status)
                        .accessibilityIdentifier("mfa.status")
                }
            }
            .navigationTitle("MSAL MFA Sample")
        }
    }

    @MainActor
    private func activate()
    {
        isBusy = true
        let parameters = MSALNativeAuthMfaSdkRegistrationParameters(qrCode: qrCode)
        Task { @MainActor in
            registration = await manager.activateMfaAccount(registrationParameters: parameters)
            qrCode = ""
            session = nil
            number = ""
            status = "MOCK: Activation returned a receipt. Nothing was enrolled."
            isBusy = false
        }
    }

    @MainActor
    private func loadChallenge()
    {
        isBusy = true
        Task { @MainActor in
            session = await manager.pullPendingNotificationsAsync().first
            number = ""
            status = session == nil ? "MOCK: No challenge returned." : "MOCK: Challenge loaded without a network request."
            isBusy = false
        }
    }

    @MainActor
    private func respond(to session: MSALNativeAuthMfaSdkAuthSession, approve: Bool)
    {
        isBusy = true
        let enteredNumber = number
        Task { @MainActor in
            let result: MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult
            if approve
            {
                result = await manager.approve(authSession: session, number: enteredNumber)
            }
            else
            {
                result = await manager.deny(authSession: session)
            }
            status = result.wasApproved ? "MOCK: Approved locally. No sign-in was authorized." :
                "MOCK: Denied locally. No server was contacted."
            self.session = nil
            number = ""
            isBusy = false
        }
    }
}
