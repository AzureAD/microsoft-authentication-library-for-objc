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

    struct ChallengePrompt: Identifiable
    {
        let id = UUID()
        let session: MSALNativeAuthMfaSdkAuthSession
    }

    enum ChallengeStatus: Equatable
    {
        case noPendingChallenge
        case approved
        case denied
        case invalidNumber
        case unexpectedResult
    }

    @Published private(set) var registrations: [MSALMfaSampleRegistration] = []
    @Published private(set) var isRegistering = false
    @Published private(set) var validationError: ValidationError?
    @Published private(set) var challengePrompt: ChallengePrompt?
    @Published private(set) var isLoadingChallenge = false
    @Published private(set) var isRespondingToChallenge = false
    @Published private(set) var challengeStatus: ChallengeStatus?

    private var activeOperation: UUID?
    private var challengeOperation: UUID?
    private var accountsRefresh: (id: UUID, task: Task<Void, Never>)?
    private let loadChallenges: () async -> [MSALNativeAuthMfaSdkAuthSession]
    private let respond: (
        MSALNativeAuthMfaSdkAuthSession, Bool, String
    ) async -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult
    private let activate: (MSALNativeAuthMfaSdkRegistrationParameters) async -> MSALNativeAuthMfaSdkRegistrationResult

    init(
        loadChallenges: @escaping () async -> [MSALNativeAuthMfaSdkAuthSession] = {
            await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        },
        respond: @escaping (
            MSALNativeAuthMfaSdkAuthSession, Bool, String
        ) async -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult = { session, approve, number in
            let manager = MSALNativeAuthMfaSdkManager()
            if approve
            {
                return await manager.approve(authSession: session, number: number)
            }
            return await manager.deny(authSession: session)
        },
        activate: @escaping (MSALNativeAuthMfaSdkRegistrationParameters) async -> MSALNativeAuthMfaSdkRegistrationResult = {
            await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: $0)
        }
    )
    {
        self.loadChallenges = loadChallenges
        self.respond = respond
        self.activate = activate
    }

    static func isValidChallengeNumber(_ number: String) -> Bool
    {
        let value = number.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.allSatisfy { $0 >= "0" && $0 <= "9" } && Int(value) != nil
    }

    func refreshChallengeFromAccounts() async
    {
        if let refresh = accountsRefresh
        {
            await refresh.task.value
            return
        }
        // SwiftUI's refresh task lifetime must not determine whether a challenge is shown.
        // Own the request separately; navigation cancels it through cancelChallengeFlow().
        let id = UUID()
        let task = Task { @MainActor in await self.refreshChallenge() }
        accountsRefresh = (id, task)
        await task.value
        if accountsRefresh?.id == id
        {
            accountsRefresh = nil
        }
    }

    func refreshChallenge() async
    {
        guard !isLoadingChallenge, !isRespondingToChallenge, challengePrompt == nil, !Task.isCancelled else { return }
        let operation = UUID()
        challengeOperation = operation
        isLoadingChallenge = true
        challengeStatus = nil
        let sessions = await loadChallenges()
        guard challengeOperation == operation else { return }
        challengeOperation = nil
        isLoadingChallenge = false
        guard !Task.isCancelled else { return }
        guard let session = sessions.first else
        {
            challengeStatus = .noPendingChallenge
            return
        }
        guard session.isMock else
        {
            challengeStatus = .unexpectedResult
            return
        }
        challengePrompt = ChallengePrompt(session: session)
    }

    func dismissChallenge()
    {
        challengePrompt = nil
    }

    func cancelChallengeFlow()
    {
        accountsRefresh?.task.cancel()
        accountsRefresh = nil
        challengeOperation = nil
        challengePrompt = nil
        isLoadingChallenge = false
        isRespondingToChallenge = false
        challengeStatus = nil
    }

    // Consume the prompt before scheduling work so dismissal and repeated taps cannot submit it twice.
    func respondToChallenge(id: UUID, approve: Bool, number: String) -> Task<Void, Never>?
    {
        guard let prompt = challengePrompt, prompt.id == id, !isRespondingToChallenge else { return nil }
        guard !approve || Self.isValidChallengeNumber(number) else
        {
            challengeStatus = .invalidNumber
            return nil
        }
        let submittedNumber = approve ? number.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let operation = UUID()
        challengeOperation = operation
        challengePrompt = nil
        challengeStatus = nil
        isRespondingToChallenge = true
        return Task { @MainActor in
            guard self.challengeOperation == operation, !Task.isCancelled else
            {
                if self.challengeOperation == operation
                {
                    self.challengeOperation = nil
                    self.isRespondingToChallenge = false
                }
                return
            }
            let result = await self.respond(prompt.session, approve, submittedNumber)
            guard self.challengeOperation == operation else { return }
            self.challengeOperation = nil
            self.isRespondingToChallenge = false
            guard !Task.isCancelled else { return }
            guard result.isMock, result.wasApproved == approve else
            {
                self.challengeStatus = .unexpectedResult
                return
            }
            self.challengeStatus = result.wasApproved ? .approved : .denied
        }
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
