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
    private typealias Failure = MSALNativeAuthMFAServiceError

    private struct Validation {
        let id: UUID
        let token: String
        let scenario: String
        let account: MSALNativeAuthMFAAccountRecord?
        var processing = false
        var result: Result<(XML, URL), Failure>?
    }

    private struct Session {
        let publicValue: MSALNativeAuthMFAAuthSession
        let account: MSALNativeAuthMFAAccountRecord
        let endpoint: URL
        let token: String
        let requiresNumber: Bool
        let policySupported: Bool
        var submitting = false
        var complete = false
    }

    private struct EndpointMap {
        let defaultURL: String
        let endpoints: [String: String]

        func endpoint(for scope: String) throws -> URL {
            try MSALNativeAuthMFAEndpoint.phoneApp(endpoints[scope] ?? defaultURL)
        }
    }

    private let client: MSALNativeAuthMFAServiceClient
    private let storage: any MSALNativeAuthMFAStoring
    private let deviceNameProvider: @Sendable () -> String?
    private var state: MSALNativeAuthMFAStoredState?
    private var validation: Validation?
    private var updatingToken = false
    private var sessions: [String: Session] = [:]
    private var endpointMaps: [String: EndpointMap] = [:]
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    init(
        transport: any MSALNativeAuthMFATransporting,
        storage: any MSALNativeAuthMFAStoring,
        deviceNameProvider: (@Sendable () -> String?)? = nil
    ) {
        self.client = MSALNativeAuthMFAServiceClient(transport: transport)
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
            MSALNativeAuthMFARegistrationResult(registrationId: $0.id, accountName: $0.name)
        }
    }

    func update(token data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) async throws {
        var current = try load()
        let token = try MSALNativeAuthMFAProof.token(data, environment: environment)
        current.currentToken = token
        try save(current)
        guard validation == nil, !updatingToken else { throw Failure.operationInProgress }
        updatingToken = true
        defer { updatingToken = false }
        let accounts = current.accounts.filter { $0.activatedToken != token }
        for account in accounts {
            guard try load().currentToken == token else { throw Failure.operationInProgress }
            guard !account.id.isEmpty, !account.secret.isEmpty else { throw Failure.invalidResponse }
            let requestEndpoint = try await routedEndpoint(account)
            guard try load().currentToken == token else { throw Failure.operationInProgress }
            let id = UUID()
            validation = Validation(
                id: id, token: token, scenario: "DeviceTokenChangeV2", account: account
            )
            defer { if validation?.id == id { validation = nil } }
            let response = try await client.phoneApp(
                operation: "PhoneAppStartDeviceTokenChangeV2Request", endpoint: requestEndpoint,
                fields: [
                    XML(name: "newDeviceToken", text: token),
                    XML(name: "version", text: version), XML(name: "osVersion", text: osVersion),
                    XML(name: "appPackageName", text: Bundle.main.bundleIdentifier ?? ""),
                    XML(name: "notificationType", text: environment == .sandbox ? "APNS_SANDBOX" : "APNS2")
                ], headers: headers(account)
            )
            try requireSuccess(response, field: "deviceTokenChangeResult", operation: "DeviceTokenChange")
            _ = try await awaitValidation(id)
            var latest = try load()
            guard let index = latest.accounts.firstIndex(where: { $0.id == account.id }) else { throw Failure.unknownAccount }
            latest.previousToken = latest.accounts[index].activatedToken
            latest.accounts[index].activatedToken = token
            try save(latest)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func register(_ input: MSALNativeAuthMFAActivation) async throws -> MSALNativeAuthMFARegistrationResult {
        var current = try load()
        guard let token = current.currentToken else { throw MSALNativeAuthMFAPushRegistrationError.missingPushRegistration }
        guard validation == nil, !updatingToken else { throw Failure.operationInProgress }
        let digest = MSALNativeAuthMFAProof.digest(input.endpoint.absoluteString + "\n" + input.code)
        let previous = current.pendingEnrollment.flatMap { $0.inputDigest == digest ? $0 : nil }
        if let previous, previous.confirming || previous.activation == nil {
            throw Failure.outcomeUnknown
        }
        let id = previous?.id ?? UUID()
        validation = Validation(id: id, token: token, scenario: "QrRegistration", account: nil)
        defer { if validation?.id == id { validation = nil } }
        if let previous {
            guard previous.token == token else { throw Failure.outcomeUnknown }
            if let response = previous.validation, let endpoint = previous.validationEndpoint {
                validation?.result = .success((response, endpoint))
            }
        }
        let activation: XML
        if let saved = previous?.activation {
            activation = saved
        } else {
            guard let deviceName = deviceNameProvider(),
                  !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Failure.invalidResponse
            }
            current.pendingEnrollment = MSALNativeAuthMFAPendingEnrollment(id: id, inputDigest: digest, token: token)
            try save(current)
            activation = try await sendEnrollmentOperation(operation: "ActivateNew", endpoint: input.endpoint, id: id, fields: [
                XML(name: "activationParams", children: [
                    XML(name: "ActivationCode", text: input.code),
                    XML(name: "DeviceToken", text: token),
                    XML(name: "DeviceName", text: deviceName),
                    XML(name: "OathCounter", text: counter),
                    XML(name: "Version", text: version)
                ])
            ])
            var latest = try (state ?? storage.load())
            latest.pendingEnrollment?.activation = activation
            try save(latest)
        }
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
        var pendingState = try load()
        pendingState.pendingEnrollment?.confirming = true
        try save(pendingState)
        let confirmed = try await sendEnrollmentOperation(operation: "ConfirmActivation", endpoint: input.endpoint, id: id, fields: [
            XML(name: "confirmationCode", text: confirmation)
        ])
        let registrationId = try confirmed.value("phoneAppDetailId")
        guard !registrationId.isEmpty else { throw Failure.invalidResponse }
        let account = MSALNativeAuthMFAAccountRecord(
            id: registrationId, name: name, username: username, secret: secret,
            groupKey: try validated.optionalValue("groupKey") ?? "",
            tenantId: try info.value("TenantId"), objectId: try info.value("AzureObjectId"),
            endpoint: endpoint, replicationScope: "", routingHint: "", countryCode: "",
            activatedToken: token, dosPreventer: try validated.value("dosPreventer")
        )
        // Persist a server-confirmed enrollment even if the UI was cancelled while the response arrived.
        var latest = try (state ?? storage.load())
        latest.accounts.removeAll { $0.id == account.id }
        latest.accounts.append(account)
        latest.pendingEnrollment = nil
        try save(latest)
        return MSALNativeAuthMFARegistrationResult(registrationId: account.id, accountName: account.name)
    }

    private func sendEnrollmentOperation(operation: String, endpoint: URL, id: UUID, fields: [XML]) async throws -> XML {
        do {
            return try await client.activation(operation: operation, endpoint: endpoint, fields: fields)
        } catch Failure.serviceFailure(let failedOperation, let code)
            where failedOperation == operation
                && (code == "Rejected" || (!code.isEmpty && code.utf8.count <= 10 && code.utf8.allSatisfy({ (48...57).contains($0) }))) {
            // Only an explicit false SOAP result permits retry; faults and transport failures remain ambiguous.
            var latest = try (state ?? storage.load())
            if latest.pendingEnrollment?.id == id {
                if operation == "ActivateNew" {
                    latest.pendingEnrollment = nil
                } else {
                    latest.pendingEnrollment?.confirming = false
                }
                try save(latest)
            }
            throw Failure.serviceFailure(operation: failedOperation, code: code)
        }
    }

    private func awaitValidation(_ id: UUID) async throws -> (XML, URL) {
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
        let restoredValidation = validation == nil
        defer { if restoredValidation { validation = nil } }
        if validation == nil, !updatingToken, let saved = try load().pendingEnrollment, !saved.confirming {
            validation = Validation(id: saved.id, token: saved.token, scenario: "QrRegistration", account: nil)
        }
        guard let pending = validation, pending.result == nil else { throw Failure.unexpectedNotification }
        guard !pending.processing else { return [] }
        let scenario = payload["validationScenario"] ?? pending.scenario
        guard scenario == pending.scenario else { throw Failure.unexpectedNotification }
        if let account = pending.account, account.endpoint.host != endpoint.host {
            guard let map = endpointMaps[account.endpoint.absoluteString],
                  try map.endpoint(for: account.replicationScope).host == endpoint.host else {
                throw Failure.untrustedEndpoint
            }
        }
        validation?.processing = true
        do {
            let result: XML
            if scenario == "DeviceTokenChangeV2" {
                guard let account = pending.account, let counterText = payload["oathCounter"], let counter = UInt64(counterText),
                      payload["tenantId"] == account.tenantId else { throw Failure.unexpectedNotification }
                result = try await client.phoneApp(
                    operation: "PhoneAppCompleteDeviceTokenChangeV2Request", endpoint: endpoint,
                    fields: [
                        XML(name: "newDeviceToken", text: pending.token),
                        XML(name: "version", text: version), XML(name: "osVersion", text: osVersion),
                        XML(name: "accounts", children: [
                            XML(name: "account", children: [
                                XML(name: "azureObjectId", text: account.objectId),
                                XML(name: "azureTenantId", text: account.tenantId),
                                XML(name: "phoneAppDetailId", text: account.id),
                                XML(name: "oathCode", text: try MSALNativeAuthMFAProof.validation(secret: account.secret, counter: counter))
                            ])
                        ])
                    ], headers: headers(account)
                )
                try requireSuccess(result, field: "deviceTokenChangeResult", operation: "CompleteDeviceTokenChange")
                let results = try result.child("accountValidationResults").children
                guard try results.contains(where: {
                    try $0.value("phoneAppDetailId") == account.id && $0.value("validationResult") == "Success"
                }) else { throw Failure.serviceFailure(operation: "CompleteDeviceTokenChange", code: "AccountRejected") }
            } else {
                guard scenario == "QrRegistration", pending.account == nil else { throw Failure.unexpectedNotification }
                result = try await client.phoneApp(operation: "PhoneAppValidateDeviceToken", endpoint: endpoint, fields: [
                    context(guid: guid, token: pending.token, proof: "", needsDos: true),
                    XML(name: "validationResult", text: "yes"), XML(name: "accounts")
                ])
            }
            guard validation?.id == pending.id else { throw Failure.unexpectedNotification }
            validation?.result = .success((result, endpoint))
            if pending.scenario == "QrRegistration" {
                var latest = try (state ?? storage.load())
                if latest.pendingEnrollment?.id == pending.id {
                    latest.pendingEnrollment?.validation = result
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
            let requestEndpoint = try await routedEndpoint(account)
            let response = try await client.phoneApp(operation: "PhoneAppCheckForAuthentication", endpoint: requestEndpoint, fields: [
                XML(name: "dosPreventer", text: account.dosPreventer),
                XML(name: "deviceToken", text: account.activatedToken, attributes: ["notificationType": "apns"]),
                XML(name: "previousDeviceToken", text: current.previousToken ?? ""),
                XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
            ], headers: headers(account))
            let result = try response.value("checkForAuthenticationResult")
            if result == "101" { continue }
            try requireSuccess(response, field: "checkForAuthenticationResult", operation: "CheckForAuthentication")
            let host = try response.value("padUrl")
            if host.isEmpty { continue }
            guard let counter = UInt64(try response.value("oathCounter")) else { throw Failure.invalidResponse }
            let endpoint = try MSALNativeAuthMFAEndpoint.notification(host)
            let username = try response.value("username")
            guard let matched = current.accounts.first(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame }) else {
                throw Failure.unknownAccount
            }
            let proof = try MSALNativeAuthMFAProof.validation(secret: matched.secret, counter: counter)
            let session = try await fetch(guid: "", endpoint: endpoint, account: matched, proof: proof)
            if !found.contains(where: { $0.guid == session.guid }) { found.append(session) }
        }
        return found
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func fetch(guid: String, endpoint: URL, account: MSALNativeAuthMFAAccountRecord?,
                       proof: String) async throws -> MSALNativeAuthMFAAuthSession {
        guard !guid.isEmpty || account != nil else { throw Failure.invalidSession }
        if let existing = sessions[guid] {
            guard !existing.complete else { throw Failure.invalidSession }
            return existing.publicValue
        }
        let current = try load()
        guard let token = current.currentToken else { throw MSALNativeAuthMFAPushRegistrationError.missingPushRegistration }
        let response = try await client.phoneApp(operation: "PhoneAppAuthentication", endpoint: endpoint, fields: [
            context(guid: guid, token: token, proof: proof, needsDos: true)
        ], headers: account.map(headers) ?? [:])
        let id = try response.value("guid")
        guard UUID(uuidString: id) != nil, guid.isEmpty || guid == id else { throw Failure.invalidResponse }
        guard !current.completedSessionIds.contains(id) else { throw Failure.invalidSession }
        if let existing = sessions[id] {
            guard !existing.complete else { throw Failure.invalidSession }
            return existing.publicValue
        }
        let info = try response.child("phoneAppInfo")
        let registrationId = try info.value("phoneAppDetailId")
        let tenant = try info.value("tenantId")
        let object = try info.value("azureObjectId")
        guard var matched = current.accounts.first(where: { $0.id == registrationId && $0.tenantId == tenant && $0.objectId == object }) else {
            throw Failure.unknownAccount
        }
        guard account == nil || account?.id == matched.id else { throw Failure.unknownAccount }
        matched.replicationScope = try info.value("replicationScope")
        matched.routingHint = try info.optionalValue("routingHint") ?? ""
        matched.countryCode = try info.optionalValue("countryCode") ?? ""
        matched.endpoint = endpoint
        matched.dosPreventer = try response.value("dosPreventer")
        var requiresNumber = !(try info.value("firstEntropyChallenge")).isEmpty
        let policy = try info.optionalValue("userCredentialPolicy") ?? ""
        var policySupported = try info.attributes["mode"] == "standard"
            && info.value("returnLocationData") == "no"
            && info.value("isSilent") == "no"
            && (info.optionalValue("isAppLockRequired") ?? "no") == "no"
        do {
            let credentialPolicy = try MSALNativeAuthMFACredentialPolicy(encoded: policy)
            requiresNumber = requiresNumber || credentialPolicy.requiresNumberMatching
        } catch Failure.unsupportedPolicy {
            policySupported = false
        }
        let publicValue = MSALNativeAuthMFAAuthSession(
            guid: id, accountName: matched.name, username: matched.username,
            requiresNumberMatching: requiresNumber
        )
        var latest = try load()
        guard let index = latest.accounts.firstIndex(where: { $0.id == matched.id }) else { throw Failure.unknownAccount }
        latest.accounts[index] = matched
        try save(latest)
        sessions[id] = Session(
            publicValue: publicValue, account: matched, endpoint: endpoint, token: token,
            requiresNumber: requiresNumber, policySupported: policySupported
        )
        return publicValue
    }

    func respond(_ value: MSALNativeAuthMFAAuthSession, approve: Bool, number: String) async throws
        -> MSALNativeAuthMFAPendingAuthSessionCompletionResult {
        _ = try load()
        guard var session = sessions[value.guid], session.publicValue === value,
              !session.submitting, !session.complete else { throw Failure.invalidSession }
        if approve {
            guard session.policySupported else { throw Failure.unsupportedPolicy }
            if session.requiresNumber {
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
        defer { sessions[value.guid]?.complete = true }
        let operation: String
        let resultField: String
        let success: String
        var fields = [
            context(guid: value.guid, token: session.token, proof: "", needsDos: false),
            XML(name: "oathCounter", text: counter), XML(name: "completedInteractively", text: "yes")
        ]
        if approve && session.requiresNumber {
            operation = "PhoneAppPinValidation"
            resultField = "validationResult"
            success = "6"
            fields += [
                XML(name: "pin", attributes: ["stored": "no"]),
                XML(name: "authenticate", text: "yes"), XML(name: "selectedEntropyNumber", text: number)
            ]
        } else {
            operation = "PhoneAppAuthenticationResult"
            resultField = "authenticationResultResult"
            success = "1"
            fields += [
                XML(name: "authenticationResult", text: approve ? "1" : "2"),
                XML(name: "newDeviceToken", attributes: ["notificationType": "apns"])
            ]
        }
        let response = try await client.phoneApp(
            operation: operation, endpoint: session.endpoint, fields: fields, headers: headers(session.account)
        )
        let code = try response.value(resultField)
        guard Int(code) != nil, code.count <= 10 else { throw Failure.invalidResponse }
        guard code == success else { throw Failure.serviceFailure(operation: operation, code: code) }
        return MSALNativeAuthMFAPendingAuthSessionCompletionResult(wasApproved: approve)
    }

    private var counter: String { String(UInt64(Date().timeIntervalSince1970 / 30)) }
    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    private func routedEndpoint(_ account: MSALNativeAuthMFAAccountRecord) async throws -> URL {
        let key = account.endpoint.absoluteString
        if let map = endpointMaps[key] {
            return try map.endpoint(for: account.replicationScope)
        }
        guard !account.replicationScope.isEmpty else { return account.endpoint }
        let response = try await client.phoneApp(operation: "PhoneAppGetEndpoints", endpoint: account.endpoint, fields: [])
        _ = try response.value("version")
        let defaultURL = try response.value("defaultUrl")
        guard !defaultURL.isEmpty else { throw Failure.invalidResponse }
        var endpoints: [String: String] = [:]
        for item in try response.child("endpoints").children {
            let url = try item.value("url")
            let scopes = try item.value("replicationScopes").split(separator: ",", omittingEmptySubsequences: false)
            for scope in scopes {
                let scope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !scope.isEmpty, endpoints[scope] == nil else { throw Failure.invalidResponse }
                endpoints[scope] = url
            }
        }
        let map = EndpointMap(defaultURL: defaultURL, endpoints: endpoints)
        let endpoint = try map.endpoint(for: account.replicationScope)
        endpointMaps[key] = map
        return endpoint
    }

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
