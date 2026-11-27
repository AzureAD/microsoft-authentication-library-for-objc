// ------------------------------------------------------------------------------
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
// ------------------------------------------------------------------------------

import Foundation
@_implementationOnly import MSAL_Private

// swiftlint:disable file_length
/// Coordinates internal MFA workflows and safe state transitions, delegating wire protocols to network clients.
///
/// Responsibilities:
/// - Enrollment: activation, push validation, confirmation, and persistence of the resulting registration.
/// - Push-token updates: sequential account updates, durable attempt tracking, and delayed validation callbacks.
/// - Challenges: retrieval, registration identity checks, and management of in-memory authentication sessions.
/// - Decisions: approval/denial submission, replay prevention, and cleanup of completed sessions.
/// - Deletion: provider-token acquisition and validation, Graph deletion, and removal of local registration state.
/// - State: coordinating persistence, rejecting conflicting operations, and blocking replay of uncertain remote outcomes.
///
/// Actor isolation protects shared mutable state. Explicit operation and identity guards also account for
/// interleaving across suspension points, such as a validation push arriving while enrollment is waiting.
///
/// `MSALNativeAuthMFAManager` owns the public API, correlation IDs, and public error mapping. This service owns
/// orchestration; SAS/Graph clients own network operations, and the storage implementation owns Keychain access.
/// Graph URL construction and endpoint-routing cache management currently remain in this service.
/// XML serialization, HTTP transport, UI presentation, and notification permission requests are outside its scope.
// swiftlint:disable:next type_body_length
internal actor MSALNativeAuthMFAService {
    private typealias Failure = MSALNativeAuthMFAFailure

    private enum ValidationResult {
        case enrollment(MSALNativeAuthSASValidationResult, URL)
        case tokenUpdated
    }

    private struct Validation {
        let id: UUID
        let token: String
        let scenario: MSALNativeAuthSASValidationScenario
        let account: MSALNativeAuthMFAAccountRecord?
        var hasWaiter = false
        var processing = false
        var result: Result<ValidationResult, Failure>?
    }

    private struct Session {
        let publicValue: MSALNativeAuthMFAAuthSession
        let account: MSALNativeAuthMFAAccountRecord
        let endpoint: URL
        let token: String
        let challenge: MSALNativeAuthSASAuthenticationResult
        var submitting = false
    }

    private let client: any MSALNativeAuthSASClient
    private let graphClient: MSALNativeAuthMFAGraphClient
    private let storage: any MSALNativeAuthMFAStoring
    private let deviceNameProvider: @Sendable () -> String?
    private var state: MSALNativeAuthMFAStoredState?
    private var validation: Validation?
    private var updatingToken = false
    private var deletingRegistrationId: String?
    private var deletionSubmitted = false
    private var remotelyDeletedRegistrationIds: Set<String> = []
    private var registrationGenerations: [String: UUID] = [:]
    private var sessions: [String: Session] = [:]
    private var endpointMaps: [String: MSALNativeAuthSASEndpoints] = [:]

    init(
        sasClient: any MSALNativeAuthSASClient,
        graphClient: MSALNativeAuthMFAGraphClient,
        storage: any MSALNativeAuthMFAStoring,
        deviceNameProvider: (@Sendable () -> String?)? = nil
    ) {
        self.client = sasClient
        self.graphClient = graphClient
        self.storage = storage
        self.deviceNameProvider = deviceNameProvider ?? { MSIDDeviceId.deviceHardwareType() }
    }

    private func load() throws -> MSALNativeAuthMFAStoredState {
        try Task.checkCancellation()
        if let state { return state }
        let loaded = try storage.load()
        state = loaded
        return loaded
    }

    private func save(_ newState: MSALNativeAuthMFAStoredState) throws {
        try storage.save(newState)
        state = newState
    }

    func registrations() throws -> [MSALNativeAuthMFARegistrationResult] {
        try load().accounts.map {
            MSALNativeAuthMFARegistrationResult(registrationId: $0.id, accountName: $0.name, username: $0.username)
        }
    }

    // swiftlint:disable:next function_body_length
    func delete(
        registrationId: String,
        tokenProvider: any MSALTokenProvider
    ) async throws {
        let current = try load()
        guard deletingRegistrationId == nil else { throw Failure.operationInProgress }
        guard let account = current.accounts.first(where: { $0.id == registrationId }) else { throw Failure.registrationNotFound }
        if remotelyDeletedRegistrationIds.contains(registrationId) {
            try finishDeletion(account)
            return
        }
        let parameters = try deletionTokenParameters(account)
        let generation = registrationGenerations[registrationId]
        guard let endpoint = URL(string:
            "https://graph.microsoft.com/v1.0/users/\(account.objectId)/authentication/microsoftAuthenticatorMethods/\(account.id)"
        ) else { throw Failure.invalidResponse }
        try MSALNativeAuthMFAEndpoint.Policy.graphDeletion.validate(endpoint)
        deletingRegistrationId = registrationId
        defer {
            deletingRegistrationId = nil
            deletionSubmitted = false
        }
        let result: MSALTokenProviderResult
        do {
            result = try await tokenProvider.getAccessToken(parameters: parameters)
        } catch {
            throw MSALNativeAuthMFAProviderFailure(underlying: error)
        }
        try Task.checkCancellation()
        try validateDeletionToken(result, parameters: parameters)
        guard validation == nil, !updatingToken,
              !sessions.values.contains(where: { $0.account.id == registrationId && $0.submitting }) else {
            throw Failure.operationInProgress
        }
        guard generation == registrationGenerations[registrationId] else { throw Failure.unknownAccount }
        deletionSubmitted = true
        try await graphClient.deleteRegistration(endpoint: endpoint, accessToken: result.accessToken)
        // A confirmed remote deletion must invalidate sessions even if the local save fails or the caller cancels.
        remotelyDeletedRegistrationIds.insert(account.id)
        registrationGenerations[account.id] = UUID()
        try finishDeletion(account)
    }

    private func finishDeletion(_ account: MSALNativeAuthMFAAccountRecord) throws {
        sessions = sessions.filter { $0.value.account.id != account.id }
        endpointMaps.removeValue(forKey: account.endpoint.absoluteString)
        var latest = try (state ?? storage.load())
        latest.accounts.removeAll { $0.id == account.id }
        latest.tokenChangeAttempts?.removeValue(forKey: account.id)
        try save(latest)
    }

    private func deletionTokenParameters(_ account: MSALNativeAuthMFAAccountRecord) throws -> MSALTokenProviderParameters {
        guard let host = account.endpoint.host?.lowercased(),
              host.hasSuffix(".microsoft.com") || host.hasSuffix(".phonefactor.net") else {
            throw Failure.unsupportedDeletionCloud
        }
        guard UUID(uuidString: account.tenantId) != nil, UUID(uuidString: account.objectId) != nil,
              let authority = URL(string: "https://login.microsoftonline.com/" + account.tenantId) else {
            throw Failure.invalidResponse
        }
        return MSALTokenProviderParameters(
            authorityURL: authority,
            scopes: ["https://graph.microsoft.com/UserAuthenticationMethod.ReadWrite"],
            claimsRequestJSON: #"{"access_token":{"amr":{"essential":true,"values":["ngcmfa"]}}}"#,
            tenantId: account.tenantId, objectId: account.objectId, loginHint: account.username,
            correlationId: MSALNativeAuthMFARequestContext.correlationId ?? UUID()
        )
    }

    private func validateDeletionToken(_ result: MSALTokenProviderResult, parameters: MSALTokenProviderParameters) throws {
        guard let tenantId = parameters.tenantId, let objectId = parameters.objectId,
              result.tenantId.caseInsensitiveCompare(tenantId) == .orderedSame,
              result.objectId.caseInsensitiveCompare(objectId) == .orderedSame,
              result.authorityURL.scheme == "https", result.authorityURL.host == parameters.authorityURL.host else {
            throw Failure.deletionAccountMismatch
        }
        let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        guard !result.accessToken.isEmpty, result.accessToken.utf8.count <= 65_536,
              !result.accessToken.unicodeScalars.contains(where: { forbidden.contains($0) }),
              let expires = result.expiresOn, expires > Date(),
              result.authenticationScheme.caseInsensitiveCompare("Bearer") == .orderedSame,
              result.scopes.contains(where: {
                  $0.caseInsensitiveCompare("UserAuthenticationMethod.ReadWrite") == .orderedSame
                      || $0.caseInsensitiveCompare(parameters.scopes[0]) == .orderedSame
              }) else { throw Failure.invalidDeletionToken }
    }

    private func requireAvailableRegistration(_ id: String) throws {
        guard !remotelyDeletedRegistrationIds.contains(id) else { throw Failure.unknownAccount }
        guard !deletionSubmitted || deletingRegistrationId != id else { throw Failure.operationInProgress }
    }

    func update(token data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) async throws {
        var current = try load()
        let token = try client.deviceToken(data, environment: environment)
        current.currentToken = token
        try save(current)
        guard validation == nil, !updatingToken, !deletionSubmitted else { throw Failure.operationInProgress }
        updatingToken = true
        defer { updatingToken = false }
        let accounts = current.accounts.filter { $0.activatedToken != token || current.tokenChangeAttempts?[$0.id] != nil }
        for account in accounts {
            try requireAvailableRegistration(account.id)
            var pendingState = try load()
            guard pendingState.tokenChangeAttempts?[account.id] == nil else { throw Failure.outcomeUnknown }
            guard pendingState.currentToken == token else { throw Failure.operationInProgress }
            guard !account.id.isEmpty else { throw Failure.invalidResponse }
            guard !account.secret.isEmpty else { throw Failure.missingSecretKey }
            let requestEndpoint = try await routedEndpoint(account)
            guard try load().currentToken == token else { throw Failure.operationInProgress }
            let id = UUID()
            pendingState = try load()
            var attempts = pendingState.tokenChangeAttempts ?? [:]
            attempts[account.id] = MSALNativeAuthMFATokenChangeAttempt(id: id, token: token)
            pendingState.tokenChangeAttempts = attempts
            try save(pendingState)
            validation = Validation(
                id: id, token: token, scenario: .tokenChange, account: account, hasWaiter: true
            )
            defer {
                if validation?.id == id {
                    validation?.hasWaiter = false
                    if validation?.result != nil { validation = nil }
                }
            }
            try await client.startDeviceTokenChange(
                account: account, token: token, environment: environment, endpoint: requestEndpoint
            )
            _ = try await awaitValidation(id)
            guard try load().currentToken == token else { throw Failure.operationInProgress }
        }
    }

    private func finishTokenChange(account: MSALNativeAuthMFAAccountRecord, token: String, attemptId: UUID) throws {
        // A confirmed server update must survive cancellation of the initiating task.
        var latest = try (state ?? storage.load())
        guard let attempt = latest.tokenChangeAttempts?[account.id], attempt.id == attemptId, attempt.token == token,
              let index = latest.accounts.firstIndex(where: { $0.id == account.id }) else { throw Failure.outcomeUnknown }
        latest.previousToken = latest.accounts[index].activatedToken
        latest.accounts[index].activatedToken = token
        latest.tokenChangeAttempts?.removeValue(forKey: account.id)
        try save(latest)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func register(_ parameters: MSALNativeAuthMFARegistrationParameters) async throws -> MSALNativeAuthMFARegistrationResult {
        let input = try client.activationInput(parameters)
        var current = try load()
        guard let token = current.currentToken else { throw MSALNativeAuthMFAFailure.missingPushRegistration }
        guard validation == nil, !updatingToken, !deletionSubmitted else { throw Failure.operationInProgress }
        let digest = MSALNativeAuthMFAProof.digest(input.endpoint.absoluteString + "\n" + input.code)
        let previous = current.pendingEnrollment
        if let previous, previous.inputDigest != digest { throw Failure.outcomeUnknown }
        if let previous, previous.confirming || previous.activation == nil {
            throw Failure.outcomeUnknown
        }
        let id = previous?.id ?? UUID()
        validation = Validation(id: id, token: token, scenario: .enrollment, account: nil)
        defer { if validation?.id == id { validation = nil } }
        if let previous {
            guard previous.token == token else { throw Failure.outcomeUnknown }
            if let response = previous.validation, let endpoint = previous.validationEndpoint {
                validation?.result = .success(.enrollment(response, endpoint))
            }
        }
        let activation: MSALNativeAuthSASActivationResult
        if let saved = previous?.activation {
            activation = saved
        } else {
            guard let deviceName = deviceNameProvider(),
                  !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Failure.invalidResponse
            }
            current.pendingEnrollment = MSALNativeAuthMFAPendingEnrollment(id: id, inputDigest: digest, token: token)
            try save(current)
            do {
                activation = try await client.activate(input: input, token: token, deviceName: deviceName)
            } catch Failure.enrollmentRejected(let code) {
                try resetRejectedEnrollment(id: id, activating: true)
                throw Failure.enrollmentRejected(code: code)
            }
            var latest = try (state ?? storage.load())
            latest.pendingEnrollment?.activation = activation
            try save(latest)
        }
        guard case .enrollment(let validated, let endpoint) = try await awaitValidation(id) else {
            throw Failure.unexpectedNotification
        }
        // SAS can leave the validation username empty; activation remains the identity source.
        guard validated.username.isEmpty || validated.username.caseInsensitiveCompare(activation.username) == .orderedSame else {
            throw Failure.invalidResponse
        }
        var pendingState = try load()
        pendingState.pendingEnrollment?.confirming = true
        try save(pendingState)
        let registrationId: String
        do {
            registrationId = try await client.confirmActivation(code: activation.confirmationCode, endpoint: input.endpoint)
        } catch Failure.enrollmentRejected(let code) {
            try resetRejectedEnrollment(id: id, activating: false)
            throw Failure.enrollmentRejected(code: code)
        }
        let account = MSALNativeAuthMFAAccountRecord(
            id: registrationId, name: validated.accountName, username: activation.username, secret: activation.secret,
            groupKey: validated.groupKey,
            tenantId: activation.tenantId, objectId: activation.objectId,
            endpoint: endpoint, replicationScope: "", routingHint: "", countryCode: "",
            activatedToken: token, dosPreventer: validated.dosPreventer
        )
        // Persist a server-confirmed enrollment even if the UI was cancelled while the response arrived.
        var latest = try (state ?? storage.load())
        latest.accounts.removeAll { $0.id == account.id }
        latest.accounts.append(account)
        latest.pendingEnrollment = nil
        try save(latest)
        remotelyDeletedRegistrationIds.remove(account.id)
        registrationGenerations[account.id] = UUID()
        return MSALNativeAuthMFARegistrationResult(registrationId: account.id, accountName: account.name, username: account.username)
    }

    private func resetRejectedEnrollment(id: UUID, activating: Bool) throws {
        // The client must distinguish definitive rejection from an unknown remote outcome.
        var latest = try (state ?? storage.load())
        if latest.pendingEnrollment?.id == id {
            if activating {
                latest.pendingEnrollment = nil
            } else {
                latest.pendingEnrollment?.confirming = false
            }
            try save(latest)
        }
    }

    private func awaitValidation(_ id: UUID) async throws -> ValidationResult {
        let deadline = ContinuousClock.now.advanced(by: .seconds(120))
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard let validation, validation.id == id else { throw Failure.unexpectedNotification }
            if let result = validation.result { return try result.get() }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw Failure.validationTimedOut
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func notification(_ notification: MSALNativeAuthSASNotification?) async throws -> [MSALNativeAuthMFAAuthSession] {
        _ = try load()
        guard let notification else { return [] }
        let push: MSALNativeAuthSASValidationNotification
        switch notification {
        case .authentication(let guid, let endpoint):
            return [try await fetch(guid: guid, endpoint: endpoint, account: nil, counter: nil)]
        case .validation(let value):
            push = value
        }
        let endpoint = push.endpoint
        let restoredValidation = validation == nil
        defer {
            if restoredValidation {
                validation = nil
            } else if let pending = validation, pending.scenario == .tokenChange,
                      !pending.hasWaiter, pending.result != nil {
                validation = nil
            }
        }
        if validation == nil, !updatingToken, let saved = try load().pendingEnrollment, !saved.confirming {
            validation = Validation(id: saved.id, token: saved.token, scenario: .enrollment, account: nil)
        }
        guard let pending = validation, pending.result == nil else { throw Failure.unexpectedNotification }
        let scenario = push.scenario ?? pending.scenario
        guard scenario == pending.scenario else { throw Failure.unexpectedNotification }
        if scenario == .tokenChange {
            guard let account = pending.account, push.counter != nil,
                  push.tenantId == account.tenantId else { throw Failure.unexpectedNotification }
        }
        if let account = pending.account, account.endpoint.host != endpoint.host {
            guard let map = endpointMaps[account.endpoint.absoluteString],
                  try client.endpoint(for: account.replicationScope, in: map).host == endpoint.host else {
                throw Failure.untrustedEndpoint
            }
        }
        guard !pending.processing else { return [] }
        validation?.processing = true
        do {
            let result: ValidationResult
            if scenario == .tokenChange, let account = pending.account, let counter = push.counter {
                try await client.completeDeviceTokenChange(
                    account: account, token: pending.token, counter: counter, endpoint: endpoint
                )
                try finishTokenChange(account: account, token: pending.token, attemptId: pending.id)
                result = .tokenUpdated
            } else {
                guard scenario == .enrollment, pending.account == nil else { throw Failure.unexpectedNotification }
                let response = try await client.validateDeviceToken(guid: push.guid, token: pending.token, endpoint: endpoint)
                result = .enrollment(response, endpoint)
            }
            guard validation?.id == pending.id else { throw Failure.unexpectedNotification }
            validation?.result = .success(result)
            if case .enrollment(let response, let endpoint) = result {
                var latest = try (state ?? storage.load())
                if latest.pendingEnrollment?.id == pending.id {
                    latest.pendingEnrollment?.validation = response
                    latest.pendingEnrollment?.validationEndpoint = endpoint
                    try save(latest)
                }
            }
        } catch let error as Failure {
            if validation?.id == pending.id { validation?.result = .failure(error) }
            throw error
        } catch {
            if validation?.id == pending.id { validation?.result = .failure(.transportFailure) }
            throw error
        }
        return []
    }

    func pull() async throws -> [MSALNativeAuthMFAAuthSession] {
        let current = try load()
        var found: [MSALNativeAuthMFAAuthSession] = []
        for account in current.accounts {
            try requireAvailableRegistration(account.id)
            let generation = registrationGenerations[account.id]
            let requestEndpoint = try await routedEndpoint(account)
            try requireAvailableRegistration(account.id)
            let response = try await client.checkForAuthentication(
                account: account, previousToken: current.previousToken, endpoint: requestEndpoint
            )
            guard generation == registrationGenerations[account.id] else { throw Failure.unknownAccount }
            try requireAvailableRegistration(account.id)
            guard let response else { continue }
            let candidates = try load().accounts.filter { $0.id == response.registrationId }
            guard candidates.count == 1, let matched = candidates.first,
                  matched.username.caseInsensitiveCompare(response.username) == .orderedSame,
                  matched.groupKey == response.groupKey else {
                throw Failure.unknownAccount
            }
            let session = try await fetch(guid: response.guid, endpoint: response.endpoint, account: matched, counter: response.counter)
            if !found.contains(where: { $0.guid == session.guid }) { found.append(session) }
        }
        for value in found {
            guard let session = sessions[value.guid], !session.submitting else { throw Failure.invalidSession }
            try requireAvailableRegistration(session.account.id)
        }
        return found
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func fetch(guid: String, endpoint: URL, account: MSALNativeAuthMFAAccountRecord?,
                       counter: UInt64?) async throws -> MSALNativeAuthMFAAuthSession {
        guard !guid.isEmpty || account != nil else { throw Failure.invalidSession }
        let current = try load()
        if let account { try requireAvailableRegistration(account.id) }
        guard !current.completedSessionIds.contains(guid) else { throw Failure.completedSession }
        if let existing = sessions[guid] {
            try requireAvailableRegistration(existing.account.id)
            guard !existing.submitting else { throw Failure.completedSession }
            guard account == nil || account?.id == existing.account.id else { throw Failure.unknownAccount }
            return existing.publicValue
        }
        guard let token = current.currentToken else { throw MSALNativeAuthMFAFailure.missingPushRegistration }
        let generations = registrationGenerations
        let response = try await client.authentication(guid: guid, token: token, account: account, counter: counter, endpoint: endpoint)
        let id = response.guid
        guard UUID(uuidString: id) != nil, guid.isEmpty || guid == id else { throw Failure.invalidResponse }
        let registrationId = response.registrationId
        guard generations[registrationId] == registrationGenerations[registrationId] else { throw Failure.unknownAccount }
        var latest = try load()
        guard !latest.completedSessionIds.contains(id) else { throw Failure.completedSession }
        if let existing = sessions[id] {
            try requireAvailableRegistration(existing.account.id)
            guard !existing.submitting else { throw Failure.completedSession }
            guard account == nil || account?.id == existing.account.id else { throw Failure.unknownAccount }
            return existing.publicValue
        }
        let tenant = response.tenantId
        let object = response.objectId
        guard var matched = latest.accounts.first(where: { $0.id == registrationId && $0.tenantId == tenant && $0.objectId == object }) else {
            throw Failure.unknownAccount
        }
        guard account == nil || account?.id == matched.id else { throw Failure.unknownAccount }
        try requireAvailableRegistration(matched.id)
        matched.replicationScope = response.replicationScope
        matched.routingHint = response.routingHint
        matched.countryCode = response.countryCode
        matched.endpoint = endpoint
        matched.dosPreventer = response.dosPreventer
        guard response.policySupported else { throw Failure.unsupportedPolicy }
        let publicValue = MSALNativeAuthMFAAuthSession(
            guid: id, registrationId: matched.id, accountName: matched.name, username: matched.username,
            requiresNumberMatching: response.requiresNumberMatching
        )
        guard let index = latest.accounts.firstIndex(where: { $0.id == matched.id }) else { throw Failure.unknownAccount }
        latest.accounts[index] = matched
        try save(latest)
        sessions[id] = Session(
            publicValue: publicValue, account: matched, endpoint: endpoint, token: token,
            challenge: response
        )
        return publicValue
    }

    func respond(_ value: MSALNativeAuthMFAAuthSession, action: MSALNativeAuthMFAAction) async throws -> MSALNativeAuthMFADecision {
        let current = try load()
        guard !current.completedSessionIds.contains(value.guid) else { throw Failure.completedSession }
        guard var session = sessions[value.guid], session.publicValue === value else { throw Failure.invalidSession }
        guard !session.submitting else { throw Failure.completedSession }
        try requireAvailableRegistration(session.account.id)
        let approve: Bool
        let number: String
        switch action {
        case .approve(let value):
            approve = true
            number = value ?? ""
        case .deny:
            approve = false
            number = ""
        }
        if approve {
            guard session.challenge.policySupported else { throw Failure.unsupportedPolicy }
            if session.challenge.requiresNumberMatching {
                guard !number.isEmpty, number.utf8.count <= 10, number.utf8.allSatisfy({ (48...57).contains($0) }) else {
                    throw Failure.invalidNumber
                }
            }
        }
        var pendingState = try load()
        pendingState.completedSessionIds.insert(value.guid)
        try save(pendingState)
        session.submitting = true
        sessions[value.guid] = session
        // Once submitted, an ambiguous transport failure must not enable a second, conflicting decision.
        defer { sessions.removeValue(forKey: value.guid) }
        if approve && session.challenge.requiresNumberMatching {
            try await client.pinValidation(
                challenge: session.challenge, token: session.token, account: session.account, number: number, endpoint: session.endpoint
            )
        } else {
            try await client.authenticationResult(
                challenge: session.challenge, token: session.token, account: session.account, approved: approve, endpoint: session.endpoint
            )
        }
        return approve ? .approved : .denied
    }

    private func routedEndpoint(_ account: MSALNativeAuthMFAAccountRecord) async throws -> URL {
        let key = account.endpoint.absoluteString
        if let map = endpointMaps[key] {
            return try client.endpoint(for: account.replicationScope, in: map)
        }
        guard !account.replicationScope.isEmpty else { return account.endpoint }
        let map = try await client.getEndpoints(endpoint: account.endpoint)
        let endpoint = try client.endpoint(for: account.replicationScope, in: map)
        endpointMaps[key] = map
        return endpoint
    }
}
