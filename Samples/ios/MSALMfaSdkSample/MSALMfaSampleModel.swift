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
        case qrCode
        case manualEntry
    }

    let id: String
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
        case missingQRCode
        case registrationFailed
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
        case requestFailed
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
    private let loadChallenges: () async throws -> [MSALNativeAuthMfaSdkAuthSession]
    private let respond: (
        MSALNativeAuthMfaSdkAuthSession, Bool, String
    ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult
    private let activate: (MSALNativeAuthMfaSdkRegistrationParameters) async throws -> MSALNativeAuthMfaSdkRegistrationResult
    private let addThirdPartyAccount: (
        MSALNativeAuthMfaSdkManualRegistrationParameters
    ) async throws -> MSALNativeAuthMfaSdkRegistrationResult

    init(
        loadChallenges: @escaping () async throws -> [MSALNativeAuthMfaSdkAuthSession] = {
            try await MSALNativeAuthMfaSdkManager().pullPendingNotificationsAsync()
        },
        respond: @escaping (
            MSALNativeAuthMfaSdkAuthSession, Bool, String
        ) async throws -> MSALNativeAuthMfaSdkPendingAuthSessionCompletionResult = { session, approve, number in
            let manager = MSALNativeAuthMfaSdkManager()
            if approve
            {
                return try await manager.approve(authSession: session, number: number)
            }
            return try await manager.deny(authSession: session)
        },
        activate: @escaping (MSALNativeAuthMfaSdkRegistrationParameters) async throws -> MSALNativeAuthMfaSdkRegistrationResult = {
            try await MSALNativeAuthMfaSdkManager().activateMfaAccount(registrationParameters: $0)
        },
        addThirdPartyAccount: @escaping (
            MSALNativeAuthMfaSdkManualRegistrationParameters
        ) async throws -> MSALNativeAuthMfaSdkRegistrationResult = {
            try await MSALNativeAuthMfaSdkManager().addThirdPartyAccount(registrationParameters: $0)
        }
    )
    {
        self.loadChallenges = loadChallenges
        self.respond = respond
        self.activate = activate
        self.addThirdPartyAccount = addThirdPartyAccount
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
        defer
        {
            if challengeOperation == operation
            {
                challengeOperation = nil
                isLoadingChallenge = false
            }
        }
        do
        {
            let sessions = try await loadChallenges()
            guard challengeOperation == operation, !Task.isCancelled else { return }
            guard let session = sessions.first else
            {
                challengeStatus = .noPendingChallenge
                return
            }
            challengePrompt = ChallengePrompt(session: session)
        }
        catch
        {
            guard challengeOperation == operation, !Task.isCancelled else { return }
            challengeStatus = .requestFailed
        }
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
            defer
            {
                if self.challengeOperation == operation
                {
                    self.challengeOperation = nil
                    self.isRespondingToChallenge = false
                }
            }
            do
            {
                let result = try await self.respond(prompt.session, approve, submittedNumber)
                guard self.challengeOperation == operation, !Task.isCancelled else { return }
                guard result.wasApproved == approve else
                {
                    self.challengeStatus = .unexpectedResult
                    return
                }
                self.challengeStatus = result.wasApproved ? .approved : .denied
            }
            catch
            {
                guard self.challengeOperation == operation, !Task.isCancelled else { return }
                self.challengeStatus = .requestFailed
            }
        }
    }

    static func canFinish(name: String, secret: String) -> Bool
    {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func registerQRCode(_ qrCode: String) async -> Bool
    {
        guard !isRegistering else { return false }
        guard !qrCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            validationError = .missingQRCode
            return false
        }
        return await register(source: .qrCode)
        {
            try await self.activate(MSALNativeAuthMfaSdkRegistrationParameters(qrCode: qrCode))
        }
    }

    func finishManualEntry(name: String, secret: String) async -> Bool
    {
        guard !isRegistering else { return false }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            validationError = .missingName
            return false
        }
        guard !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            validationError = .missingSecret
            return false
        }
        return await register(source: .manualEntry)
        {
            try await self.addThirdPartyAccount(
                MSALNativeAuthMfaSdkManualRegistrationParameters(accountName: name, secretKey: secret)
            )
        }
    }

    func cancelRegistration()
    {
        activeOperation = nil
        isRegistering = false
        validationError = nil
    }

    private func register(
        source: MSALMfaSampleRegistration.Source,
        request: () async throws -> MSALNativeAuthMfaSdkRegistrationResult
    ) async -> Bool
    {
        guard !isRegistering, !Task.isCancelled else { return false }
        let operation = UUID()
        activeOperation = operation
        isRegistering = true
        validationError = nil

        defer
        {
            if activeOperation == operation
            {
                activeOperation = nil
                isRegistering = false
            }
        }
        do
        {
            let result = try await request()
            guard activeOperation == operation, !Task.isCancelled else { return false }
            guard !result.registrationId.isEmpty, !result.accountName.isEmpty else
            {
                validationError = .unexpectedResult
                return false
            }
            let registration = MSALMfaSampleRegistration(id: result.registrationId, name: result.accountName, source: source)
            if let index = registrations.firstIndex(where: { $0.id == result.registrationId })
            {
                registrations[index] = registration
            }
            else
            {
                registrations.append(registration)
            }
            return true
        }
        catch
        {
            guard activeOperation == operation, !Task.isCancelled else { return false }
            validationError = .registrationFailed
            return false
        }
    }
}
