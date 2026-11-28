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
/// - Deletion: coordinating token acquisition, Graph token validation/deletion, and removal of local registration state.
/// - State: coordinating persistence, rejecting conflicting operations, and blocking replay of uncertain remote outcomes.
///
/// Actor isolation protects shared mutable state. Explicit operation and identity guards also account for
/// interleaving across suspension points, such as a validation push arriving while enrollment is waiting.
///
/// `MSALNativeAuthMFAManager` owns the public API, correlation IDs, and public error mapping. This service owns
/// orchestration; SAS/Graph clients own network operations, and the storage implementation owns Keychain access.
/// The Graph collaborator owns cloud-specific request configuration and token checks.
/// SAS endpoint-routing cache management remains in this service.
/// XML serialization, HTTP transport, UI presentation, and notification permission requests are outside its scope.
// swiftlint:disable:next type_body_length
internal actor MSALNativeAuthMFAService {
    private typealias Failure = MSALNativeAuthMFAError.Reason

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

    private let sasClient: any MSALNativeAuthSASClient
    private let graphClient: any MSALNativeAuthMFAGraphDeleting
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

    // MARK: - Public methods

    /// Creates the coordinator with injected network and persistence dependencies; state is loaded lazily.
    ///
    /// - Parameters:
    ///   - sasClient: SAS implementation used for enrollment, token updates, routing, and authentication.
    ///   - graphClient: Graph deletion configuration and request implementation.
    ///   - storage: Persistence for registrations and durable operation markers.
    ///   - deviceNameProvider: Supplies enrollment device metadata; defaults to the device hardware type.
    init(
        sasClient: any MSALNativeAuthSASClient,
        graphClient: any MSALNativeAuthMFAGraphDeleting,
        storage: any MSALNativeAuthMFAStoring,
        deviceNameProvider: (@Sendable () -> String?)? = nil
    ) {
        self.sasClient = sasClient
        self.graphClient = graphClient
        self.storage = storage
        self.deviceNameProvider = deviceNameProvider ?? { MSIDDeviceId.deviceHardwareType() }
    }

    /// Projects locally stored accounts into registration results without contacting a server.
    /// - Returns: The registrations in the current stored-state snapshot.
    /// - Throws: Cancellation or a storage-loading failure.
    func registrations() throws -> [MSALNativeAuthMFARegistrationResult] {
        try load().accounts.map {
            MSALNativeAuthMFARegistrationResult(registrationId: $0.id, accountName: $0.name, username: $0.username)
        }
    }

    /// Deletes a registration remotely, then invalidates its sessions and removes its local state.
    ///
    /// A previously confirmed remote deletion retries only local cleanup. Provider failures are wrapped for
    /// the manager to unwrap; a failed local save does not undo a confirmed remote deletion.
    /// - Parameters:
    ///   - registrationId: Identifier of the locally registered authentication method.
    ///   - tokenProvider: Acquires the delegated token required by the Graph deletion request.
    /// - Throws: Missing or changed registration, conflicting work, token/provider, network, storage, or cancellation errors.
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
        let request = try graphClient.prepareDeletion(for: account)
        let generation = registrationGenerations[registrationId]
        deletingRegistrationId = registrationId
        defer {
            deletingRegistrationId = nil
            deletionSubmitted = false
        }
        let result: MSALTokenProviderResult
        do {
            result = try await tokenProvider.getAccessToken(parameters: request.tokenParameters)
        } catch {
            throw MSALNativeAuthMFAProviderFailure(underlying: error)
        }
        try Task.checkCancellation()
        try request.validateToken(result)
        guard validation == nil, !updatingToken,
              !sessions.values.contains(where: { $0.account.id == registrationId && $0.submitting }) else {
            throw Failure.operationInProgress
        }
        guard generation == registrationGenerations[registrationId] else { throw Failure.unknownAccount }
        deletionSubmitted = true
        try await graphClient.deleteRegistration(endpoint: request.endpoint, accessToken: result.accessToken)
        // A confirmed remote deletion must invalidate sessions even if the local save fails or the caller cancels.
        remotelyDeletedRegistrationIds.insert(account.id)
        registrationGenerations[account.id] = UUID()
        try finishDeletion(account)
    }

    /// Persists the current APNs token and updates affected registrations sequentially through validation callbacks.
    ///
    /// The token is saved before conflict checks. Durable attempt markers prevent replay after uncertain outcomes;
    /// an unsettled validation context can outlive cancellation or timeout of this call.
    /// - Parameters:
    ///   - data: Raw APNs device-token bytes.
    ///   - environment: APNs environment used to encode and register the token.
    /// - Throws: Invalid token, conflicting work, uncertain prior outcome, validation, network, storage, or cancellation errors.
    func update(token data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) async throws {
        var current = try load()
        let token = try sasClient.deviceToken(data, environment: environment)
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
            try await sasClient.startDeviceTokenChange(
                account: account, token: token, environment: environment, endpoint: requestEndpoint
            )
            _ = try await awaitValidation(id)
            guard try load().currentToken == token else { throw Failure.operationInProgress }
        }
    }

    /// Activates, validates, confirms, and persists an MFA registration, resuming saved enrollment when safe.
    ///
    /// Requires a stored push token and rejects replacement or replay of an enrollment with an uncertain outcome.
    /// Server-confirmed enrollment is persisted even if cancellation occurs while confirmation is in flight.
    /// - Parameter parameters: Activation input interpreted by the configured SAS client.
    /// - Returns: The confirmed registration projected for the caller.
    /// - Throws: Invalid input, missing push registration, conflicting work, validation, network, storage, or cancellation errors.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func register(_ parameters: MSALNativeAuthMFARegistrationParameters) async throws -> MSALNativeAuthMFARegistrationResult {
        let input = try sasClient.activationInput(parameters)
        var current = try load()
        guard let token = current.currentToken else { throw Failure.missingPushRegistration }
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
                activation = try await sasClient.activate(input: input, token: token, deviceName: deviceName)
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
            registrationId = try await sasClient.confirmActivation(code: activation.confirmationCode, endpoint: input.endpoint)
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

    /// Handles a normalized SAS push by fetching a challenge or settling an enrollment/token-change validation.
    ///
    /// Validates callback identity and routing before changing the pending operation. Saved enrollment validation
    /// can be restored, and settled token-change contexts are released when no initiating waiter remains.
    /// - Parameter notification: Parsed push content, or `nil` for an unrelated notification.
    /// - Returns: One authentication session for a challenge push; otherwise an empty array.
    /// - Throws: Unexpected or untrusted callbacks, validation, challenge, network, storage, or cancellation errors.
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
                  try sasClient.endpoint(for: account.replicationScope, in: map).host == endpoint.host else {
                throw Failure.untrustedEndpoint
            }
        }
        guard !pending.processing else { return [] }
        validation?.processing = true
        do {
            let result: ValidationResult
            if scenario == .tokenChange, let account = pending.account, let counter = push.counter {
                try await sasClient.completeDeviceTokenChange(
                    account: account, token: pending.token, counter: counter, endpoint: endpoint
                )
                try finishTokenChange(account: account, token: pending.token, attemptId: pending.id)
                result = .tokenUpdated
            } else {
                guard scenario == .enrollment, pending.account == nil else { throw Failure.unexpectedNotification }
                let response = try await sasClient.validateDeviceToken(guid: push.guid, token: pending.token, endpoint: endpoint)
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

    /// Discovers pending challenges across local registrations and fetches their authoritative session details.
    ///
    /// Matches discovery results to registration identity and rechecks availability across suspension points.
    /// - Returns: Sessions deduplicated by challenge identifier; an empty array when no challenges are pending.
    /// - Throws: Unavailable or mismatched registrations, invalid sessions, routing, network, storage, or cancellation errors.
    func pull() async throws -> [MSALNativeAuthMFAAuthSession] {
        let current = try load()
        var found: [MSALNativeAuthMFAAuthSession] = []
        for account in current.accounts {
            try requireAvailableRegistration(account.id)
            let generation = registrationGenerations[account.id]
            let requestEndpoint = try await routedEndpoint(account)
            try requireAvailableRegistration(account.id)
            let response = try await sasClient.checkForAuthentication(
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

    /// Submits approval or denial for a session issued by this service, validating number matching when required.
    ///
    /// Persists the replay guard before submission and removes the in-memory session afterward, including on failure.
    /// An uncertain submission cannot be retried with a different decision.
    /// - Parameters:
    ///   - value: The exact session instance previously returned by this service.
    ///   - action: Approval with an optional matching number, or denial.
    /// - Returns: The submitted decision after the SAS operation succeeds.
    /// - Throws: Invalid/completed session, unavailable registration, unsupported policy, invalid number, or operation errors.
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
            try await sasClient.pinValidation(
                challenge: session.challenge, token: session.token, account: session.account, number: number, endpoint: session.endpoint
            )
        } else {
            try await sasClient.authenticationResult(
                challenge: session.challenge, token: session.token, account: session.account, approved: approve, endpoint: session.endpoint
            )
        }
        return approve ? .approved : .denied
    }

    // MARK: - Private methods

    /// Returns cached state or loads it from storage, checking task cancellation before either path.
    /// - Throws: Cancellation or a storage-loading failure.
    private func load() throws -> MSALNativeAuthMFAStoredState {
        try Task.checkCancellation()
        if let state { return state }
        let loaded = try storage.load()
        state = loaded
        return loaded
    }

    /// Persists a complete state snapshot and replaces the in-memory cache only after the save succeeds.
    /// - Throws: The storage write error; the cached state is unchanged on failure.
    private func save(_ newState: MSALNativeAuthMFAStoredState) throws {
        try storage.save(newState)
        state = newState
    }

    /// Invalidates sessions and routing cache, then removes a remotely deleted account and its token-change marker.
    /// Deliberately bypasses cancellation checks so confirmed remote deletion can be reconciled locally.
    /// - Throws: Storage errors; sessions and routing cache remain invalidated if persistence fails.
    private func finishDeletion(_ account: MSALNativeAuthMFAAccountRecord) throws {
        sessions = sessions.filter { $0.value.account.id != account.id }
        endpointMaps.removeValue(forKey: account.endpoint.absoluteString)
        var latest = try (state ?? storage.load())
        latest.accounts.removeAll { $0.id == account.id }
        latest.tokenChangeAttempts?.removeValue(forKey: account.id)
        try save(latest)
    }

    /// Rejects an identifier whose remote deletion is confirmed or whose deletion request is being submitted.
    /// This checks deletion guards only; it does not establish that the registration exists in storage.
    /// - Throws: `unknownAccount` for confirmed deletion or `operationInProgress` for an in-flight deletion.
    private func requireAvailableRegistration(_ id: String) throws {
        guard !remotelyDeletedRegistrationIds.contains(id) else { throw Failure.unknownAccount }
        guard !deletionSubmitted || deletingRegistrationId != id else { throw Failure.operationInProgress }
    }

    /// Commits a confirmed token update only when its registration, attempt identifier, and token match stored state.
    /// Updates the previous-token snapshot and removes the durable attempt marker without checking caller cancellation.
    /// - Throws: `outcomeUnknown` for a missing/mismatched attempt or registration, or a storage error.
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

    /// Clears retry-blocking enrollment state after a definitive SAS rejection, never after an ambiguous outcome.
    /// - Parameters:
    ///   - id: Pending enrollment identifier; a different pending enrollment is left unchanged.
    ///   - activating: Clears the enrollment when `true`; otherwise clears only its confirmation-in-progress marker.
    /// - Throws: A storage error while reading or saving the enrollment state.
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

    /// Waits up to 120 seconds for the matching validation context to settle, yielding between checks.
    /// - Parameter id: The enrollment or token-change attempt being awaited.
    /// - Returns: The successful validation result recorded by notification handling.
    /// - Throws: Cancellation, a missing/replaced context, the recorded failure, or `validationTimedOut`.
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

    /// Reuses an active session or fetches an authoritative challenge, validates its account, and caches the resulting session.
    ///
    /// Newly fetched challenges update persisted account routing metadata. Registration-generation and replay checks
    /// prevent responses from reviving deleted/replaced registrations or completed sessions.
    /// - Parameters:
    ///   - guid: Expected challenge identifier; may be empty when the SAS flow supplies an account instead.
    ///   - endpoint: SAS endpoint used to retrieve the challenge.
    ///   - account: Optional expected registration, also checked when reusing a cached session.
    ///   - counter: Optional SAS counter accompanying challenge discovery.
    /// - Returns: The existing or newly created session bound to the matched registration.
    /// - Throws: Invalid/completed challenge, mismatched/unavailable account, missing token, unsupported policy, or operation errors.
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
        guard let token = current.currentToken else { throw Failure.missingPushRegistration }
        let generations = registrationGenerations
        let response = try await sasClient.authentication(guid: guid, token: token, account: account, counter: counter, endpoint: endpoint)
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

    /// Selects a SAS endpoint from the cached map or discovers and caches a map for the account's replication scope.
    /// Without a cached map or replication scope, returns the account's existing endpoint without discovery.
    /// - Returns: The endpoint selected and validated by the SAS client, or the account endpoint on the no-scope path.
    /// - Throws: Endpoint-selection or discovery errors; a newly discovered map is cached only after selection succeeds.
    private func routedEndpoint(_ account: MSALNativeAuthMFAAccountRecord) async throws -> URL {
        let key = account.endpoint.absoluteString
        if let map = endpointMaps[key] {
            return try sasClient.endpoint(for: account.replicationScope, in: map)
        }
        guard !account.replicationScope.isEmpty else { return account.endpoint }
        let map = try await sasClient.getEndpoints(endpoint: account.endpoint)
        let endpoint = try sasClient.endpoint(for: account.replicationScope, in: map)
        endpointMaps[key] = map
        return endpoint
    }
}
