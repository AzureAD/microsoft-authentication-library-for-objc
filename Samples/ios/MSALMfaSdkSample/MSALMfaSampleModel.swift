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

import Foundation
import Combine
import MSAL

struct MSALMfaSampleRegistration: Identifiable
{
    enum Source: Equatable
    {
        case simulatedScan
        case manualEntry
    }

    let id = UUID()
    let name: String
    let source: Source
}

@MainActor
final class MSALMfaSampleModel: ObservableObject
{
    enum ValidationError: Error, Equatable
    {
        case missingName
        case missingSecret
        case unexpectedResult
    }

    @Published private(set) var registrations: [MSALMfaSampleRegistration] = []
    @Published private(set) var isRegistering = false
    @Published private(set) var validationError: ValidationError?

    private var activeOperation: UUID?
    private let activate: (MSALNativeAuthMfaSdkRegistrationParameters) async -> MSALNativeAuthMfaSdkRegistrationResult

    init(
        activate: @escaping (MSALNativeAuthMfaSdkRegistrationParameters) async -> MSALNativeAuthMfaSdkRegistrationResult = {
            await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: $0)
        }
    )
    {
        self.activate = activate
    }

    static func canFinish(name: String, secret: String) -> Bool
    {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func simulateScan() async -> Bool
    {
        await register(name: String(localized: "Demo account"), source: .simulatedScan)
    }

    func finishManualEntry(name: String, secret: String) async -> Bool
    {
        guard !isRegistering else { return false }
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else
        {
            validationError = .missingName
            return false
        }
        guard !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            validationError = .missingSecret
            return false
        }
        return await register(name: displayName, source: .manualEntry)
    }

    func cancelRegistration()
    {
        activeOperation = nil
        isRegistering = false
        validationError = nil
    }

    private func register(name: String, source: MSALMfaSampleRegistration.Source) async -> Bool
    {
        guard !isRegistering, !Task.isCancelled else { return false }
        let operation = UUID()
        activeOperation = operation
        isRegistering = true
        validationError = nil

        // Manual input is not a QR payload: both demo paths use this synthetic fixture, never the entered secret.
        let result = await activate(MSALNativeAuthMfaSdkRegistrationParameters(qrCode: "mock-qr-activation"))
        guard activeOperation == operation else { return false }
        activeOperation = nil
        isRegistering = false
        guard !Task.isCancelled else { return false }
        guard result.isMock else
        {
            validationError = .unexpectedResult
            return false
        }
        registrations.append(MSALMfaSampleRegistration(name: name, source: source))
        return true
    }
}
