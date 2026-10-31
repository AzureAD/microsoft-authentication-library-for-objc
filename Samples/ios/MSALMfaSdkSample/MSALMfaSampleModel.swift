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
    let username: String
    let source: Source
}

@MainActor
private final class MSALMfaSampleDeletionTokenProvider: MSALTokenProvider
{
    weak var model: MSALMfaSampleModel?
    private let provider: any MSALTokenProvider

    init(provider: any MSALTokenProvider)
    {
        self.provider = provider
    }

    func getAccessToken(parameters: MSALTokenProviderParameters) async throws -> MSALTokenProviderResult
    {
        guard let model else { throw CancellationError() }
        return try await model.acquireDeletionToken {
            try await self.provider.getAccessToken(parameters: parameters)
        }
    }
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
        case pushRegistration(MSALMfaSamplePushRegistration.Failure)
        case unexpectedResult
    }

    struct ChallengePrompt: Identifiable
    {
        let id = UUID()
        let session: MSALNativeAuthMFAAuthSession
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
    @Published private(set) var serviceFailure: String?
    @Published private(set) var deletingRegistrationId: String?
    @Published private(set) var deletionFailure: String?
    @Published private(set) var isAcquiringDeletionToken = false

    private(set) var registrationRevision = 0
    private let deleteRegistrationRequest: (String) async throws -> Void
    private var isApplicationActive = false
    private var isAccountsVisible = true
    private var queuedSessions: [MSALNativeAuthMFAAuthSession] = []
    private var receivedSessions: Set<String> = []
    private let loadRegistrations: () async throws -> [MSALNativeAuthMFARegistrationResult]
    private var activeOperation: UUID?
    private var challengeOperation: UUID?
    private var accountsRefresh: (id: UUID, task: Task<Void, Never>)?
    private var challengeResponse: (id: UUID, task: Task<Void, Never>)?
    private var deletionChallengeRefresh: (id: UUID, task: Task<Void, Never>)?
    private let waitForDeletionRefresh: @MainActor () async throws -> Void
    private let registerForPush: @MainActor () async throws -> MSALMfaSamplePushRegistration.Registration
    private let loadChallenges: () async throws -> [MSALNativeAuthMFAAuthSession]
    private let respond: (
        MSALNativeAuthMFAAuthSession, Bool, String
    ) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult
    private let activate: (MSALNativeAuthMFARegistrationParameters) async throws -> MSALNativeAuthMFARegistrationResult

    convenience init(
        sdk: MSALNativeAuthMFAManager,
        registerForPush: @escaping @MainActor () async throws -> MSALMfaSamplePushRegistration.Registration,
        tokenProvider: any MSALTokenProvider
    )
    {
        let deletionProvider = MSALMfaSampleDeletionTokenProvider(provider: tokenProvider)
        self.init(
            registerForPush: registerForPush,
            loadChallenges: { try await sdk.pullPendingNotifications() },
            respond: { session, approve, number in
                if approve
                {
                    return try await sdk.approve(authSession: session, number: number)
                }
                return try await sdk.deny(authSession: session)
            },
            activate: { try await sdk.registerAuthMethod(registrationParameters: $0) },
            loadRegistrations: { try await sdk.registeredAuthMethods() },
            deleteRegistration: { try await sdk.deleteAuthMethod(registrationId: $0, tokenProvider: deletionProvider) }
        )
        deletionProvider.model = self
    }

    init(
        registerForPush: @escaping @MainActor () async throws -> MSALMfaSamplePushRegistration.Registration,
        loadChallenges: @escaping () async throws -> [MSALNativeAuthMFAAuthSession],
        respond: @escaping (
            MSALNativeAuthMFAAuthSession, Bool, String
        ) async throws -> MSALNativeAuthMFAPendingAuthSessionCompletionResult,
        activate: @escaping (MSALNativeAuthMFARegistrationParameters) async throws -> MSALNativeAuthMFARegistrationResult,
        loadRegistrations: @escaping () async throws -> [MSALNativeAuthMFARegistrationResult] = { [] },
        deleteRegistration: @escaping (String) async throws -> Void = { _ in
            throw MSALMfaSampleWebTokenProvider.Failure.notConfigured
        },
        waitForDeletionRefresh: @escaping @MainActor () async throws -> Void = {
            try await Task.sleep(for: .seconds(3))
        }
    )
    {
        self.registerForPush = registerForPush
        self.loadChallenges = loadChallenges
        self.respond = respond
        self.activate = activate
        self.loadRegistrations = loadRegistrations
        self.deleteRegistrationRequest = deleteRegistration
        self.waitForDeletionRefresh = waitForDeletionRefresh
    }

    func restoreRegistrations() async
    {
        guard deletingRegistrationId == nil else { return }
        let revision = registrationRevision
        do
        {
            let saved = try await loadRegistrations()
            guard deletingRegistrationId == nil, revision == registrationRevision, !Task.isCancelled else { return }
            registrations = saved.map { result in
                MSALMfaSampleRegistration(id: result.registrationId, name: result.accountName, username: result.username,
                    source: registrations.first(where: { $0.id == result.registrationId })?.source ?? .qrCode)
            }
            serviceFailure = nil
        }
        catch
        {
            guard deletingRegistrationId == nil, revision == registrationRevision, !Task.isCancelled else { return }
            serviceFailure = "Unable to load saved accounts. Unlock your device and try again."
        }
    }

    var canDeleteRegistration: Bool
    {
        deletingRegistrationId == nil && !isRegistering && !isLoadingChallenge
            && !isRespondingToChallenge && challengePrompt == nil
    }

    func deleteRegistration(id: String) async
    {
        guard canDeleteRegistration, registrations.contains(where: { $0.id == id }), !Task.isCancelled else { return }
        deletingRegistrationId = id
        deletionFailure = nil
        registrationRevision += 1
        defer
        {
            deletingRegistrationId = nil
            registrationRevision += 1
            // Even a failed save can follow remote success. Refresh rather than presenting stale queued sessions.
            queuedSessions.removeAll()
            receivedSessions.removeAll()
        }
        do
        {
            try await deleteRegistrationRequest(id)
            registrations.removeAll { $0.id == id }
            challengeStatus = nil
        }
        catch is CancellationError
        {
            deletionFailure = "Deletion cancelled. The server may already have processed it; retry to reconcile this account."
        }
        catch MSALMfaSampleWebTokenProvider.Failure.notConfigured
        {
            deletionFailure = "Set MSAL_MFA_CLIENT_ID and register this app's redirect URI before deleting a registration."
        }
        catch MSALMfaSampleWebTokenProvider.Failure.userCancelled
        {
            deletionFailure = "Sign-in cancelled. The registration was not deleted."
        }
        catch MSALNativeAuthMFAServiceError.deletionAccountMismatch,
              MSALMfaSampleWebTokenProvider.Failure.accountMismatch
        {
            deletionFailure = "Sign in with the account being deleted. No deletion request was sent."
        }
        catch MSALNativeAuthMFAServiceError.unsupportedDeletionCloud
        {
            deletionFailure = "Server deletion currently supports commercial-cloud registrations only."
        }
        catch
        {
            deletionFailure = "Unable to finish deletion. Check sign-in, Graph permissions, and connectivity, then retry. "
                + "The server may already have removed the method."
        }
    }

    func acquireDeletionToken(
        using provider: () async throws -> MSALTokenProviderResult
    ) async throws -> MSALTokenProviderResult
    {
        guard deletingRegistrationId != nil, !isAcquiringDeletionToken else
        {
            throw MSALNativeAuthMFAServiceError.operationInProgress
        }
        try Task.checkCancellation()
        isAcquiringDeletionToken = true
        presentNextPush()
        startDeletionChallengeRefresh()
        let result: MSALTokenProviderResult
        do
        {
            result = try await provider()
        }
        catch
        {
            await finishDeletionTokenAcquisition()
            throw error
        }
        await finishDeletionTokenAcquisition()
        try Task.checkCancellation()
        return result
    }

    private func finishDeletionTokenAcquisition() async
    {
        isAcquiringDeletionToken = false
        stopDeletionChallengeRefresh()
        challengePrompt = nil
        // The token response can arrive before the approval HTTP response. Do not start deletion until both finish.
        if let response = challengeResponse { await response.task.value }
        cancelChallengeFlow()
        queuedSessions.removeAll()
        receivedSessions.removeAll()
    }

    private func startDeletionChallengeRefresh()
    {
        guard isAcquiringDeletionToken, isApplicationActive, deletionChallengeRefresh == nil else { return }
        let id = UUID()
        let task = Task { @MainActor [weak self, waitForDeletionRefresh] in
            defer
            {
                if self?.deletionChallengeRefresh?.id == id { self?.deletionChallengeRefresh = nil }
            }
            do
            {
                while !Task.isCancelled
                {
                    try await waitForDeletionRefresh()
                    try Task.checkCancellation()
                    guard let self, self.isAcquiringDeletionToken, self.isApplicationActive else { return }
                    await self.refreshChallenge(automatically: true)
                }
            }
            catch is CancellationError {}
            catch
            {
                guard !Task.isCancelled, self?.isAcquiringDeletionToken == true else { return }
                self?.serviceFailure = "Unable to refresh MFA requests during sign-in. Cancel sign-in and try again."
            }
        }
        deletionChallengeRefresh = (id, task)
    }

    private func stopDeletionChallengeRefresh()
    {
        deletionChallengeRefresh?.task.cancel()
        deletionChallengeRefresh = nil
    }

    private var canHandleChallenges: Bool
    {
        deletingRegistrationId == nil || isAcquiringDeletionToken
    }

    func reportPushFailure()
    {
        serviceFailure = "Unable to process the notification. Open Accounts and refresh to retrieve the request."
    }

    func setApplicationActive(_ active: Bool)
    {
        isApplicationActive = active
        if active { startDeletionChallengeRefresh() }
        else { stopDeletionChallengeRefresh() }
        presentNextPush()
    }

    func setAccountsVisible(_ visible: Bool)
    {
        isAccountsVisible = visible
        presentNextPush()
    }

    func receivePushSessions(_ sessions: [MSALNativeAuthMFAAuthSession])
    {
        for session in sessions where receivedSessions.insert(session.guid).inserted
        {
            queuedSessions.append(session)
        }
        presentNextPush()
    }

    private func presentNextPush()
    {
        guard isApplicationActive, isAccountsVisible, canHandleChallenges, !isRegistering, !isLoadingChallenge,
              !isRespondingToChallenge, challengePrompt == nil, !queuedSessions.isEmpty else { return }
        challengeStatus = nil
        challengePrompt = ChallengePrompt(session: queuedSessions.removeFirst())
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

    func refreshChallenge(automatically: Bool = false) async
    {
        guard canHandleChallenges, !isLoadingChallenge, !isRespondingToChallenge,
              challengePrompt == nil, !Task.isCancelled else { return }
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
                presentNextPush()
            }
        }
        do
        {
            let sessions = try await loadChallenges()
            guard challengeOperation == operation, !Task.isCancelled else { return }
            if automatically
            {
                receivePushSessions(sessions)
                if sessions.isEmpty { challengeStatus = .noPendingChallenge }
                return
            }
            guard let session = sessions.first else
            {
                challengeStatus = .noPendingChallenge
                return
            }
            queuedSessions.removeAll { $0.guid == session.guid }
            challengePrompt = ChallengePrompt(session: session)
            receivedSessions.insert(session.guid)
            for pending in sessions.dropFirst() where receivedSessions.insert(pending.guid).inserted
            {
                queuedSessions.append(pending)
            }
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
        presentNextPush()
    }

    func cancelChallengeFlow()
    {
        accountsRefresh?.task.cancel()
        accountsRefresh = nil
        challengeResponse?.task.cancel()
        challengeResponse = nil
        challengeOperation = nil
        challengePrompt = nil
        isLoadingChallenge = false
        isRespondingToChallenge = false
        challengeStatus = nil
    }

    // Consume the prompt before scheduling work so dismissal and repeated taps cannot submit it twice.
    func respondToChallenge(id: UUID, approve: Bool, number: String) -> Task<Void, Never>?
    {
        guard canHandleChallenges, let prompt = challengePrompt, prompt.id == id, !isRespondingToChallenge else { return nil }
        guard !approve || !prompt.session.requiresNumberMatching || Self.isValidChallengeNumber(number) else
        {
            challengeStatus = .invalidNumber
            return nil
        }
        let submittedNumber = approve && prompt.session.requiresNumberMatching
            ? number.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let operation = UUID()
        challengeOperation = operation
        challengePrompt = nil
        challengeStatus = nil
        isRespondingToChallenge = true
        let task = Task { @MainActor in
            defer
            {
                if self.challengeResponse?.id == operation { self.challengeResponse = nil }
                if self.challengeOperation == operation
                {
                    self.challengeOperation = nil
                    self.isRespondingToChallenge = false
                    self.presentNextPush()
                }
            }
            guard self.challengeOperation == operation, !Task.isCancelled else { return }
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
        challengeResponse = (operation, task)
        return task
    }

    static func canFinish(name: String, secret: String) -> Bool
    {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func registerQRCode(_ qrCode: String) async -> Bool
    {
        guard !isRegistering, deletingRegistrationId == nil else { return false }
        guard !qrCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else
        {
            validationError = .missingQRCode
            return false
        }
        return await register(source: .qrCode)
        {
            let operation = self.activeOperation
            _ = try await self.registerForPush()
            guard self.activeOperation == operation, !Task.isCancelled else { throw CancellationError() }
            return try await self.activate(
                MSALNativeAuthMFARegistrationParameters(qrCode: qrCode)
            )
        }
    }

    func finishManualEntry(name: String, secret: String) async -> Bool
    {
        guard !isRegistering, deletingRegistrationId == nil else { return false }
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
            let operation = self.activeOperation
            _ = try await self.registerForPush()
            guard self.activeOperation == operation, !Task.isCancelled else { throw CancellationError() }
            return try await self.activate(
                MSALNativeAuthMFARegistrationParameters(activationCode: secret, activationURL: name)
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
        request: () async throws -> MSALNativeAuthMFARegistrationResult
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
            let registration = MSALMfaSampleRegistration(
                id: result.registrationId, name: result.accountName, username: result.username, source: source
            )
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
            if let failure = error as? MSALMfaSamplePushRegistration.Failure
            {
                validationError = .pushRegistration(failure)
            }
            else
            {
                validationError = .registrationFailed
            }
            return false
        }
    }
}
