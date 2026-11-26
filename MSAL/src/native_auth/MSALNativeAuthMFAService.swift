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
// swiftlint:disable:next type_body_length
internal actor MSALNativeAuthMFAService {
    private typealias XML = MSALNativeAuthMFAXml
    private typealias Failure = MSALNativeAuthMFAFailure

    private struct Validation {
        let id: UUID
        let token: String
        let scenario: String
        let account: MSALNativeAuthMFAAccountRecord?
        let endpoint: URL
        var processing = false
        var result: Result<(XML, URL), Failure>?
    }

    private struct Session {
        let publicValue: MSALNativeAuthMFAAuthSession
        let account: MSALNativeAuthMFAAccountRecord
        let endpoint: URL
        let token: String
        let counter: String
        let serverContext: XML
        var submitting = false
        var complete = false
    }

    private let client: MSALNativeAuthMFAServiceClient
    private let storage: any MSALNativeAuthMFAStoring
    private let deviceNameProvider: @Sendable () -> String?
    private let bundleIdProvider: @Sendable () -> String?
    private let validationTimeout: Duration
    private var state: MSALNativeAuthMFAStoredState?
    private var validation: Validation?
    private var updatingToken = false
    private var deletingRegistrationId: String?
    private var deletionSubmitted = false
    private var remotelyDeletedRegistrationIds: Set<String> = []
    private var registrationGenerations: [String: UUID] = [:]
    private var sessions: [String: Session] = [:]
    private var submittedActivations: Set<String> = []
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    init(
        transport: any MSALNativeAuthMFATransporting,
        storage: any MSALNativeAuthMFAStoring,
        deviceNameProvider: (@Sendable () -> String?)? = nil,
        bundleIdProvider: (@Sendable () -> String?)? = nil,
        validationTimeout: Duration = .seconds(120)
    ) {
        self.client = MSALNativeAuthMFAServiceClient(transport: transport)
        self.storage = storage
        self.deviceNameProvider = deviceNameProvider ?? { MSIDDeviceId.deviceHardwareType() }
        self.bundleIdProvider = bundleIdProvider ?? { Bundle.main.bundleIdentifier }
        self.validationTimeout = validationTimeout
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
              !sessions.values.contains(where: { $0.account.id == registrationId && $0.submitting && !$0.complete }) else {
            throw Failure.operationInProgress
        }
        guard generation == registrationGenerations[registrationId] else { throw Failure.unknownAccount }
        var pending = try load()
        let previouslyUnresolved = pending.unresolvedDeletions.contains(registrationId)
        pending.unresolvedDeletions.insert(registrationId)
        try save(pending)
        deletionSubmitted = true
        do {
            try await client.deleteRegistration(endpoint: endpoint, accessToken: result.accessToken)
        } catch Failure.httpFailure(let statusCode) where statusCode == 401 || statusCode == 403 {
            // A rejected retry cannot resolve an earlier request whose outcome is still unknown.
            if !previouslyUnresolved {
                var latest = try (state ?? storage.load())
                latest.unresolvedDeletions.remove(registrationId)
                try save(latest)
            }
            throw Failure.httpFailure(statusCode: statusCode)
        }
        // A confirmed remote deletion must invalidate sessions even if the local save fails or the caller cancels.
        remotelyDeletedRegistrationIds.insert(account.id)
        registrationGenerations[account.id] = UUID()
        try finishDeletion(account)
    }

    private func finishDeletion(_ account: MSALNativeAuthMFAAccountRecord) throws {
        sessions = sessions.filter { $0.value.account.id != account.id }
        var latest = try (state ?? storage.load())
        latest.accounts.removeAll { $0.id == account.id }
        latest.unresolvedDeletions.remove(account.id)
        latest.unresolvedTokenUpdates.remove(account.id)
        try save(latest)
    }

    private func deletionTokenParameters(_ account: MSALNativeAuthMFAAccountRecord) throws -> MSALTokenProviderParameters {
        guard let host = account.endpoint.host?.lowercased(),
              host.hasSuffix(".microsoft.com") else {
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
        guard !(state?.unresolvedDeletions.contains(id) ?? false) else { throw Failure.outcomeUnknown }
    }

    func update(token data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) async throws {
        var current = try load()
        let token = try MSALNativeAuthMFAProof.token(data, environment: environment)
        current.currentToken = token
        try save(current)
        guard validation == nil, !updatingToken, !deletionSubmitted else { throw Failure.operationInProgress }
        updatingToken = true
        defer { updatingToken = false }
        let accounts = current.accounts.filter { $0.activatedToken != token }
        for account in accounts {
            try requireAvailableRegistration(account.id)
            guard try load().currentToken == token else { throw Failure.operationInProgress }
            guard !account.id.isEmpty else { throw Failure.invalidResponse }
            guard !account.secret.isEmpty else { throw Failure.missingSecretKey }
            guard !account.bundleId.isEmpty, account.bundleId == bundleIdProvider() else { throw Failure.invalidResponse }
            let tokenPrefix = environment == .sandbox ? "sb-apns2-" : "apns2-"
            guard account.activatedToken.hasPrefix(tokenPrefix) else { throw Failure.invalidResponse }
            guard !current.unresolvedTokenUpdates.contains(account.id) else { throw Failure.outcomeUnknown }
            let requestEndpoint = try MSALNativeAuthMFAEndpoint.phoneApp(account.endpoint.absoluteString)
            let id = UUID()
            validation = Validation(
                id: id, token: token, scenario: "DeviceTokenChangeV2", account: account, endpoint: requestEndpoint
            )
            defer { if validation?.id == id { validation = nil } }
            var pending = try load()
            pending.unresolvedTokenUpdates.insert(account.id)
            try save(pending)
            let response = try await client.phoneApp(
                operation: "PhoneAppStartDeviceTokenChangeV2Request", endpoint: requestEndpoint,
                fields: [
                    XML(name: "newDeviceToken", text: token),
                    XML(name: "version", text: version), XML(name: "osVersion", text: osVersion),
                    XML(name: "appPackageName", text: account.bundleId),
                    XML(name: "notificationType", text: environment == .sandbox ? "APNS_SANDBOX" : "APNS2")
                ], headers: headers(account)
            )
            try requireSuccess(response, field: "deviceTokenChangeResult", operation: "DeviceTokenChange")
            _ = try await awaitValidation(id)
            let latest = try load()
            guard latest.currentToken == token else { throw Failure.operationInProgress }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func register(_ input: MSALNativeAuthMFAActivation) async throws -> MSALNativeAuthMFARegistrationResult {
        let current = try load()
        guard let token = current.currentToken else { throw MSALNativeAuthMFAFailure.missingPushRegistration }
        guard validation == nil, !updatingToken, !deletionSubmitted else { throw Failure.operationInProgress }
        let digest = MSALNativeAuthMFAProof.digest(input.endpoint.absoluteString + "\n" + input.code)
        guard !submittedActivations.contains(digest) else { throw Failure.outcomeUnknown }
        guard let bundleId = bundleIdProvider(), !bundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let deviceName = deviceNameProvider(), !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.invalidResponse
        }
        let id = UUID()
        validation = Validation(
            id: id, token: token, scenario: "QrRegistration", account: nil,
            endpoint: try MSALNativeAuthMFAEndpoint.macEndpoint(for: input.endpoint)
        )
        defer { if validation?.id == id { validation = nil } }
        submittedActivations.insert(digest)
        let activation = try await client.activation(operation: "ActivateNew", endpoint: input.endpoint, fields: [
                XML(name: "activationParams", children: [
                    XML(name: "ActivationCode", text: input.code),
                    XML(name: "BundleId", text: bundleId),
                    XML(name: "DeviceToken", text: token),
                    XML(name: "DeviceName", text: deviceName),
                    XML(name: "OathCounter", text: counter),
                    XML(name: "Version", text: version)
                ])
            ])
        let info = try activation.child("activationInfo")
        let username = try info.value("Username")
        let secret = try info.value("OathTokenSecretKey")
        let confirmation = try info.value("ConfirmationCode")
        guard !username.isEmpty, !secret.isEmpty, !confirmation.isEmpty else { throw Failure.invalidResponse }
        let (validated, endpoint) = try await awaitValidation(id)
        // SAS can leave the validation username empty; activation remains the identity source.
        let validationUsername = try validated.value("username")
        guard validationUsername.isEmpty || validationUsername.caseInsensitiveCompare(username) == .orderedSame else {
            throw Failure.invalidResponse
        }
        let name = try validated.value("accountName")
        guard !name.isEmpty else { throw Failure.invalidResponse }
        let tenant = try info.value("TenantId")
        let object = try info.value("AzureObjectId")
        guard !tenant.isEmpty, !object.isEmpty else { throw Failure.invalidResponse }
        _ = try MSALNativeAuthMFAProof.validation(secret: secret, counter: 0)
        try Task.checkCancellation()
        let confirmed = try await client.activation(operation: "ConfirmActivation", endpoint: input.endpoint, fields: [
            XML(name: "confirmationCode", text: confirmation)
        ])
        let registrationId = try confirmed.value("phoneAppDetailId")
        guard !registrationId.isEmpty else { throw Failure.invalidResponse }
        let account = MSALNativeAuthMFAAccountRecord(
            id: registrationId, name: name, username: username, secret: secret,
            groupKey: try validated.optionalValue("groupKey") ?? "",
            tenantId: tenant, objectId: object,
            endpoint: endpoint, replicationScope: try info.optionalValue("ReplicationScope") ?? "",
            routingHint: try info.optionalValue("RoutingHint") ?? "", countryCode: try info.optionalValue("CountryCode") ?? "",
            activatedToken: token, dosPreventer: try validated.value("dosPreventer"), bundleId: bundleId
        )
        // Persist a server-confirmed enrollment even if the UI was cancelled while the response arrived.
        var latest = try (state ?? storage.load())
        latest.accounts.removeAll { $0.id == account.id }
        latest.accounts.append(account)
        try save(latest)
        remotelyDeletedRegistrationIds.remove(account.id)
        registrationGenerations[account.id] = UUID()
        return MSALNativeAuthMFARegistrationResult(registrationId: account.id, accountName: account.name, username: account.username)
    }

    private func awaitValidation(_ id: UUID) async throws -> (XML, URL) {
        let deadline = ContinuousClock.now.advanced(by: validationTimeout)
        while ContinuousClock.now < deadline {
            try Task.checkCancellation()
            guard let validation, validation.id == id else { throw Failure.unexpectedNotification }
            if let result = validation.result { return try result.get() }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw Failure.validationTimedOut
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func notification(_ payload: [String: String]) async throws -> [MSALNativeAuthMFAAuthSession] {
        _ = try load()
        guard let type = payload["type"], ["auth", "validate"].contains(type) else { return [] }
        guard let guid = payload["guid"], UUID(uuidString: guid) != nil, let notificationURL = payload["url"] else {
            throw Failure.unexpectedNotification
        }
        let endpoint = try MSALNativeAuthMFAEndpoint.notification(notificationURL)
        if type == "auth" {
            return [try await fetch(guid: guid, endpoint: endpoint, account: nil, proof: "")]
        }
        guard let pending = validation, pending.result == nil else { throw Failure.unexpectedNotification }
        guard !pending.processing else { return [] }
        let scenario = payload["validationScenario"] ?? pending.scenario
        guard scenario == pending.scenario else { throw Failure.unexpectedNotification }
        guard endpoint == pending.endpoint else { throw Failure.untrustedEndpoint }
        if let token = payload["deviceToken"], token != pending.token { throw Failure.unexpectedNotification }
        validation?.processing = true
        do {
            let result: XML
            if scenario == "DeviceTokenChangeV2" {
                guard let account = pending.account, let counterText = payload["oathCounter"], let counter = UInt64(counterText),
                      payload["tenantId"] == account.tenantId else { throw Failure.unexpectedNotification }
                let generation = registrationGenerations[account.id]
                result = try await client.phoneApp(
                    operation: "PhoneAppCompleteDeviceTokenChangeV2Request", endpoint: endpoint,
                    fields: [
                        XML(name: "newDeviceToken", text: pending.token),
                        XML(name: "version", text: version), XML(name: "osVersion", text: osVersion),
                        XML(name: "accounts", children: [
                            XML(name: "account", children: [
                                XML(name: "azureObjectId", text: account.objectId),
                                XML(name: "azureTenantId", text: account.tenantId),
                                XML(name: "groupKey", text: account.groupKey),
                                XML(name: "username", text: account.username),
                                XML(name: "phoneAppDetailId", text: account.id),
                                XML(name: "oathCode", text: try MSALNativeAuthMFAProof.validation(secret: account.secret, counter: counter))
                            ])
                        ])
                    ], headers: headers(account)
                )
                try requireSuccess(result, field: "deviceTokenChangeResult", operation: "CompleteDeviceTokenChange")
                let results = try result.child("accountValidationResults").children
                guard results.count == 1, let entry = results.first, entry.name == "accountValidationResult",
                      try entry.value("phoneAppDetailId") == account.id,
                      try entry.value("azureObjectId") == account.objectId,
                      try entry.value("azureTenantId") == account.tenantId,
                      try entry.value("groupKey") == account.groupKey,
                      try entry.value("username").caseInsensitiveCompare(account.username) == .orderedSame else {
                    throw Failure.invalidResponse
                }
                let outcome = try entry.value("validationResult")
                let known = ["Success", "UnknownFailure", "TransientFailure", "TransientFailureSkipped", "FinalFailureUserNotFound",
                             "FinalFailureUserUpdateFailure", "FinalFailureDeviceNotFound", "FinalFailureBadRequest"]
                guard known.contains(outcome) else { throw Failure.invalidResponse }
                guard outcome == "Success" else {
                    throw Failure.serviceFailure(operation: "CompleteDeviceTokenChangeAccount", code: outcome)
                }
                // Persist a bound, confirmed outcome even if cancellation cleared the initiating validation.
                guard generation == registrationGenerations[account.id] else { throw Failure.unknownAccount }
                try requireAvailableRegistration(account.id)
                var latest = try (state ?? storage.load())
                guard let index = latest.accounts.firstIndex(where: { $0.id == account.id }),
                      latest.accounts[index].tenantId == account.tenantId,
                      latest.accounts[index].objectId == account.objectId,
                      latest.accounts[index].groupKey == account.groupKey,
                      latest.accounts[index].secret == account.secret,
                      latest.accounts[index].bundleId == account.bundleId,
                      latest.accounts[index].username == account.username,
                      latest.accounts[index].activatedToken == account.activatedToken,
                      latest.unresolvedTokenUpdates.contains(account.id) else { throw Failure.unknownAccount }
                latest.previousToken = latest.accounts[index].activatedToken
                latest.accounts[index].activatedToken = pending.token
                latest.unresolvedTokenUpdates.remove(account.id)
                try save(latest)
            } else {
                guard scenario == "QrRegistration", pending.account == nil else { throw Failure.unexpectedNotification }
                result = try await client.phoneApp(operation: "PhoneAppValidateDeviceToken", endpoint: endpoint, fields: [
                    XML(name: "accounts"),
                    XML(name: "phoneAppContext", children: [
                        XML(name: "guid", text: guid), XML(name: "deviceToken", text: pending.token)
                    ]),
                    XML(name: "validationResult", text: "yes")
                ])
                guard !(try result.value("accountName")).isEmpty,
                      !(try result.value("dosPreventer")).isEmpty,
                      !(try result.value("groupKey")).isEmpty else { throw Failure.invalidResponse }
                _ = try result.value("username")
                guard try result.child("accountValidationResults").children.isEmpty else { throw Failure.invalidResponse }
            }
            guard validation?.id == pending.id else { throw Failure.unexpectedNotification }
            validation?.result = .success((result, endpoint))
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
            let requestEndpoint = try MSALNativeAuthMFAEndpoint.phoneApp(account.endpoint.absoluteString)
            try requireAvailableRegistration(account.id)
            let response = try await client.phoneApp(operation: "PhoneAppCheckForAuthentication", endpoint: requestEndpoint, fields: [
                XML(name: "dosPreventer", text: account.dosPreventer),
                XML(name: "deviceToken", text: account.activatedToken, attributes: ["notificationType": "apns"]),
                XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
            ], headers: headers(account))
            guard generation == registrationGenerations[account.id] else { throw Failure.unknownAccount }
            try requireAvailableRegistration(account.id)
            try requireSuccess(response, field: "checkForAuthenticationResult", operation: "CheckForAuthentication")
            let host = try response.value("padUrl")
            guard !host.isEmpty else { throw Failure.invalidResponse }
            guard let counter = UInt64(try response.value("oathCounter")) else { throw Failure.invalidResponse }
            let endpoint = try MSALNativeAuthMFAEndpoint.notification(host)
            let username = try response.value("username")
            guard try response.value("phoneAppDetailId") == account.id,
                  account.username.caseInsensitiveCompare(username) == .orderedSame else {
                throw Failure.unknownAccount
            }
            let proof = try MSALNativeAuthMFAProof.validation(secret: account.secret, counter: counter)
            let session = try await fetch(guid: "", endpoint: endpoint, account: account, proof: proof)
            if !found.contains(where: { $0.guid == session.guid }) { found.append(session) }
        }
        for value in found {
            guard let session = sessions[value.guid], !session.submitting, !session.complete else { throw Failure.invalidSession }
            try requireAvailableRegistration(session.account.id)
        }
        return found
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetch(guid: String, endpoint: URL, account: MSALNativeAuthMFAAccountRecord?,
                       proof: String) async throws -> MSALNativeAuthMFAAuthSession {
        guard !guid.isEmpty || account != nil else { throw Failure.invalidSession }
        let current = try load()
        if let account { try requireAvailableRegistration(account.id) }
        guard !current.completedSessionIds.contains(guid) else { throw Failure.completedSession }
        if let existing = sessions[guid] {
            try requireAvailableRegistration(existing.account.id)
            guard !existing.submitting, !existing.complete else { throw Failure.completedSession }
            guard existing.endpoint == endpoint else { throw Failure.invalidSession }
            return existing.publicValue
        }
        guard let token = account?.activatedToken ?? current.currentToken else { throw MSALNativeAuthMFAFailure.missingPushRegistration }
        let generations = registrationGenerations
        let response = try await client.phoneApp(operation: "PhoneAppAuthentication", endpoint: endpoint, fields: [
            context(guid: guid, token: token, proof: proof, needsDos: true)
        ], headers: account.map(headers) ?? [:])
        let id = try response.value("guid")
        guard UUID(uuidString: id) != nil, guid.isEmpty || guid == id else { throw Failure.invalidResponse }
        let info = try response.child("phoneAppInfo")
        let registrationId = try info.value("phoneAppDetailId")
        guard generations[registrationId] == registrationGenerations[registrationId] else { throw Failure.unknownAccount }
        var latest = try load()
        guard !latest.completedSessionIds.contains(id) else { throw Failure.completedSession }
        let tenant = try info.value("tenantId")
        let object = try info.value("azureObjectId")
        guard var matched = latest.accounts.first(where: { $0.id == registrationId && $0.tenantId == tenant && $0.objectId == object }) else {
            throw Failure.unknownAccount
        }
        guard account == nil || account?.id == matched.id else { throw Failure.unknownAccount }
        try requireAvailableRegistration(matched.id)
        matched.replicationScope = try info.optionalValue("replicationScope") ?? matched.replicationScope
        matched.routingHint = try info.optionalValue("routingHint") ?? matched.routingHint
        matched.countryCode = try info.optionalValue("countryCode") ?? matched.countryCode
        matched.endpoint = endpoint
        matched.dosPreventer = try response.value("dosPreventer")
        let challengeCounter = try response.value("oathCounter")
        guard UInt64(challengeCounter) != nil, !matched.dosPreventer.isEmpty,
              !(try info.value("sasSessionId")).isEmpty else { throw Failure.invalidResponse }
        if let mode = info.attributes["mode"], mode != "standard" { throw Failure.unsupportedPolicy }
        for key in ["returnLocationData", "isSilent", "isAppLockRequired"] {
            if let value = try info.optionalValue(key), value != "no" { throw Failure.unsupportedPolicy }
        }
        let credentialPolicy = try MSALNativeAuthMFACredentialPolicy(encoded: info.value("userCredentialPolicy"))
        if let existing = sessions[id] {
            guard !existing.submitting, !existing.complete else { throw Failure.completedSession }
            guard existing.endpoint == endpoint, existing.account.id == matched.id else { throw Failure.invalidSession }
            return existing.publicValue
        }
        let publicValue = MSALNativeAuthMFAAuthSession(
            guid: id, registrationId: matched.id, accountName: matched.name, username: matched.username,
            requiresNumberMatching: credentialPolicy.requiresNumberMatching
        )
        guard let index = latest.accounts.firstIndex(where: { $0.id == matched.id }) else { throw Failure.unknownAccount }
        latest.accounts[index] = matched
        try save(latest)
        sessions[id] = Session(
            publicValue: publicValue, account: matched, endpoint: endpoint, token: token,
            counter: challengeCounter, serverContext: info
        )
        return publicValue
    }

    func respond(_ value: MSALNativeAuthMFAAuthSession, action: MSALNativeAuthMFAAction) async throws -> MSALNativeAuthMFADecision {
        _ = try load()
        guard var session = sessions[value.guid], session.publicValue === value else { throw Failure.invalidSession }
        guard !session.submitting, !session.complete else { throw Failure.completedSession }
        try requireAvailableRegistration(session.account.id)
        let number: String?
        switch action {
        case .approve(let input):
            guard let input, !input.isEmpty, input.utf8.count <= 10, input.utf8.allSatisfy({ (48...57).contains($0) }) else {
                throw Failure.invalidNumber
            }
            number = input
        case .deny:
            number = nil
        }
        var pendingState = try load()
        pendingState.completedSessionIds.insert(value.guid)
        try save(pendingState)
        session.submitting = true
        sessions[value.guid] = session
        // Once submitted, an ambiguous transport failure must not enable a second, conflicting decision.
        defer { sessions[value.guid]?.complete = true }
        let operation: String
        let resultField: String
        let success: String
        var fields = [
            context(guid: value.guid, token: session.token, proof: "", needsDos: false),
            XML(name: "oathCounter", text: session.counter), XML(name: "completedInteractively", text: "yes"),
            XML(name: "isAppLockUsed", text: "no")
        ]
        if let number {
            operation = "PhoneAppPinValidation"
            resultField = "validationResult"
            success = "6"
            fields += [
                XML(name: "authenticate", text: "no"), XML(name: "selectedEntropyNumber", text: number)
            ]
        } else {
            operation = "PhoneAppAuthenticationResult"
            resultField = "authenticationResultResult"
            success = "1"
            fields += [
                XML(name: "authenticationResult", text: "2")
            ]
        }
        let response = try await client.phoneApp(
            operation: operation, endpoint: session.endpoint, fields: fields, headers: headers(session.account)
        )
        let code = try response.value(resultField)
        guard Int(code) != nil, code.count <= 10 else { throw Failure.invalidResponse }
        if operation == "PhoneAppPinValidation", code == "5" { throw Failure.completedSession }
        guard code == success else { throw Failure.serviceFailure(operation: operation, code: code) }
        guard try response.value("azureObjectId") == session.account.objectId,
              try response.value("tenantId") == session.account.tenantId,
              try response.value("username").caseInsensitiveCompare(session.account.username) == .orderedSame else {
            throw Failure.invalidResponse
        }
        return number == nil ? .denied : .approved
    }

    private var counter: String { String(UInt64(Date().timeIntervalSince1970 / 30)) }
    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    private func context(guid: String, token: String, proof: String, needsDos: Bool) -> XML {
        XML(name: "phoneAppContext", children: [
            XML(name: "guid", text: guid), XML(name: "oathCode", text: proof),
            XML(name: "needDosPreventer", text: needsDos ? "yes" : "no"),
            XML(name: "deviceToken", text: token),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
        ])
    }

    private func headers(_ account: MSALNativeAuthMFAAccountRecord) -> [String: String] {
        [
            "x-ms-client-tenant-id": account.tenantId, "x-ms-client-replication-scope": account.replicationScope,
            "x-ms-routing-hint": account.routingHint, "x-ms-client-tenant-country-code": account.countryCode
        ]
    }

    private func requireSuccess(_ xml: XML, field: String, operation: String) throws {
        let code = try xml.value(field)
        guard Int(code) != nil, code.count <= 10 else { throw Failure.invalidResponse }
        guard code == "1" else { throw Failure.serviceFailure(operation: operation, code: code) }
    }
}
