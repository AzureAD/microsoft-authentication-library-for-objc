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

/// EEID SOAP/PFP adapter. Selecting it and isolating EEID registration storage are composition-root responsibilities.
/// The default manager continues to select legacy SAS. This client never falls back to legacy routes or result semantics.
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
internal struct MSALNativeAuthSASEEIDClient: MSALNativeAuthSASClient {
    private typealias XML = MSALNativeAuthMFAXml
    private typealias Failure = MSALNativeAuthMFAFailure
    private let transport: any MSALNativeAuthMFATransporting
    private let namespace = "http://www.phonefactor.com/PfPaWs"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    init(transport: any MSALNativeAuthMFATransporting) {
        self.transport = transport
    }

    func activationInput(_ parameters: MSALNativeAuthMFARegistrationParameters) throws -> MSALNativeAuthMFAActivation {
        if let qrCode = parameters.qrCode {
            guard qrCode.utf8.count <= 8192, let parts = URLComponents(string: qrCode),
                  parts.user == nil, parts.password == nil, parts.fragment == nil,
                  let items = parts.queryItems else { throw Failure.invalidActivationInput }
            let accountTypes = items.filter { $0.name == "accountType" }
            let isPhoneFactor = parts.scheme?.lowercased() == "phonefactor" && parts.host?.lowercased() == "activate_account"
            let isHTTPS = parts.scheme?.lowercased() == "https" && parts.host?.lowercased() == "login.microsoftonline.com"
                && (parts.port == nil || parts.port == 443) && parts.percentEncodedPath == "/authenticatorApp/activateAccount"
                && accountTypes.count == 1 && accountTypes.first?.value == "mfa"
            let codes = items.filter { $0.name == "code" }
            let urls = items.filter { $0.name == "url" }
            guard isPhoneFactor || isHTTPS, codes.count == 1, urls.count == 1,
                  let code = codes.first?.value, let url = urls.first?.value else { throw Failure.invalidActivationInput }
            return try activationInput(code: code, url: url)
        }
        guard let code = parameters.activationCode, let url = parameters.activationURL else { throw Failure.invalidActivationInput }
        return try activationInput(code: code, url: url)
    }

    private func activationInput(code: String, url: String) throws -> MSALNativeAuthMFAActivation {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, code.utf8.count <= 1024,
              !code.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw Failure.invalidActivationInput
        }
        return try MSALNativeAuthMFAActivation(
            code: code, endpoint: Route.activation.url(url.trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    func deviceToken(_ data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) throws -> String {
        try MSALNativeAuthMFAProof.token(data, environment: environment)
    }

    func notification(_ payload: [AnyHashable: Any]) throws -> MSALNativeAuthSASNotification? {
        let fields = try MSALNativeAuthMFANotification.fields(payload)
        guard let type = fields["type"] else { return nil }
        guard let value = fields["guid"], let identifier = UUID(uuidString: value), let url = fields["url"] else {
            throw Failure.unexpectedNotification
        }
        let guid = identifier.uuidString.lowercased()
        let endpoint = try Route.phoneApp.url(url.contains("://") ? url : "https://" + url)
        if type == "auth" { return .authentication(guid: guid, endpoint: endpoint) }
        let scenario: MSALNativeAuthSASValidationScenario?
        switch fields["validationScenario"] {
        case nil: scenario = nil
        case "QrRegistration": scenario = .enrollment
        case "DeviceTokenChangeV2": scenario = .tokenChange
        default: throw Failure.unexpectedNotification
        }
        var counter: UInt64?
        if let value = fields["oathCounter"] { counter = try unsigned(value) }
        if let tenant = fields["tenantId"], UUID(uuidString: tenant) == nil { throw Failure.unexpectedNotification }
        if scenario == .tokenChange, counter == nil || fields["tenantId"] == nil { throw Failure.unexpectedNotification }
        return .validation(MSALNativeAuthSASValidationNotification(
            guid: guid, endpoint: endpoint, scenario: scenario, counter: counter,
            tenantId: fields["tenantId"]?.lowercased()
        ))
    }

    func endpoint(for _: String, in endpoints: MSALNativeAuthSASEndpoints) throws -> URL {
        guard endpoints.endpoints.isEmpty else { throw Failure.invalidResponse }
        return try Route.phoneApp.url(endpoints.defaultURL)
    }

    func activate(input: MSALNativeAuthMFAActivation, token: String, deviceName: String) async throws -> MSALNativeAuthSASActivationResult {
        let bundleId = try nativeBundleId()
        try validateToken(token)
        let input = try activationInput(code: input.code, url: input.endpoint.absoluteString)
        guard !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.invalidActivationInput }
        let result = try await activation(operation: "ActivateNew", endpoint: input.endpoint, fields: [
            XML(name: "activationParams", children: [
                XML(name: "ActivationCode", text: input.code), XML(name: "BundleId", text: bundleId),
                XML(name: "DeviceToken", text: token), XML(name: "DeviceName", text: deviceName),
                XML(name: "OathCounter", text: String(UInt64(Date().timeIntervalSince1970 / 30))),
                XML(name: "Version", text: version)
            ])
        ])
        let info = try result.child("activationInfo")
        let secret = try requiredText(info, "OathTokenSecretKey")
        _ = try MSALNativeAuthMFAProof.validation(secret: secret, counter: 0)
        return try MSALNativeAuthSASActivationResult(
            username: requiredText(info, "Username"), secret: secret, confirmationCode: requiredText(info, "ConfirmationCode"),
            tenantId: identifier(info, "TenantId"), objectId: identifier(info, "AzureObjectId"),
            bundleId: bundleId, replicationScope: info.optionalValue("ReplicationScope"),
            routingHint: info.optionalValue("RoutingHint"), countryCode: info.optionalValue("CountryCode")
        )
    }

    func confirmActivation(code: String, endpoint: URL) async throws -> String {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.invalidActivationInput }
        let result = try await activation(
            operation: "ConfirmActivation", endpoint: endpoint, fields: [XML(name: "confirmationCode", text: code)]
        )
        return try requiredText(result, "phoneAppDetailId")
    }

    func validateDeviceToken(guid: String, token: String, endpoint: URL) async throws -> MSALNativeAuthSASValidationResult {
        guard UUID(uuidString: guid) != nil else { throw Failure.unexpectedNotification }
        try validateToken(token)
        let result = try await phoneApp(operation: "PhoneAppValidateDeviceToken", endpoint: endpoint, fields: [
            XML(name: "accounts"),
            XML(name: "phoneAppContext", children: [XML(name: "guid", text: guid), XML(name: "deviceToken", text: token)]),
            XML(name: "validationResult", text: "yes")
        ])
        guard try result.child("accountValidationResults").children.isEmpty else { throw Failure.invalidResponse }
        return try MSALNativeAuthSASValidationResult(
            username: requiredText(result, "username"), accountName: requiredText(result, "accountName"),
            groupKey: requiredText(result, "groupKey"), dosPreventer: requiredText(result, "dosPreventer")
        )
    }

    func startDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, environment: MSALNativeAuthMFAAPNsEnvironment, endpoint: URL
    ) async throws {
        try validateBinding(account)
        try validateToken(token)
        let prefix = environment == .sandbox ? "sb-apns2-" : "apns2-"
        guard token.hasPrefix(prefix), account.activatedToken.hasPrefix(prefix),
              let bundleId = account.bundleId else { throw Failure.invalidDeviceToken }
        let result = try await phoneApp(operation: "PhoneAppStartDeviceTokenChangeV2Request", endpoint: endpoint, fields: [
            XML(name: "newDeviceToken", text: token), XML(name: "appPackageName", text: bundleId),
            XML(name: "notificationType", text: environment == .sandbox ? "APNS_SANDBOX" : "APNS2"),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
        ], headers: headers(account))
        try requireSuccess(result, field: "deviceTokenChangeResult", operation: "StartDeviceTokenChangeV2")
    }

    func completeDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, counter: UInt64, endpoint: URL
    ) async throws {
        try validateBinding(account)
        try validateToken(token)
        guard token.hasPrefix("sb-apns2-") == account.activatedToken.hasPrefix("sb-apns2-") else {
            throw Failure.invalidDeviceToken
        }
        let result = try await phoneApp(operation: "PhoneAppCompleteDeviceTokenChangeV2Request", endpoint: endpoint, fields: [
            XML(name: "accounts", children: [XML(name: "account", children: [
                XML(name: "azureObjectId", text: account.objectId), XML(name: "azureTenantId", text: account.tenantId),
                XML(name: "groupKey", text: account.groupKey),
                XML(name: "oathCode", text: try MSALNativeAuthMFAProof.validation(secret: account.secret, counter: counter)),
                XML(name: "phoneAppDetailId", text: account.id), XML(name: "username", text: account.username)
            ])]),
            XML(name: "newDeviceToken", text: token),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
        ], headers: headers(account))
        try requireSuccess(result, field: "deviceTokenChangeResult", operation: "CompleteDeviceTokenChangeV2")
        let results = try result.child("accountValidationResults").children
        guard results.count == 1, let entry = results.first, entry.name == "accountValidationResult",
              try entry.value("phoneAppDetailId") == account.id, try entry.value("groupKey") == account.groupKey,
              try identifier(entry, "azureTenantId") == account.tenantId.lowercased(),
              try identifier(entry, "azureObjectId") == account.objectId.lowercased(),
              try entry.value("username").caseInsensitiveCompare(account.username) == .orderedSame else { throw Failure.invalidResponse }
        let code = try entry.value("validationResult")
        let knownResults: Set<String> = [
            "Success", "UnknownFailure", "TransientFailure", "TransientFailureSkipped", "FinalFailureUserNotFound",
            "FinalFailureUserUpdateFailure", "FinalFailureDeviceNotFound", "FinalFailureBadRequest"
        ]
        guard knownResults.contains(code) else { throw Failure.invalidResponse }
        guard code == "Success" else { throw Failure.serviceFailure(operation: "CompleteDeviceTokenChangeV2Account", code: code) }
    }

    func checkForAuthentication(
        account: MSALNativeAuthMFAAccountRecord, previousToken _: String?, endpoint: URL
    ) async throws -> MSALNativeAuthSASPendingAuthentication? {
        try validateBinding(account)
        guard !account.dosPreventer.isEmpty else { throw Failure.invalidResponse }
        let result = try await phoneApp(operation: "PhoneAppCheckForAuthentication", endpoint: endpoint, fields: [
            XML(name: "dosPreventer", text: account.dosPreventer),
            XML(name: "deviceToken", text: account.activatedToken, attributes: ["notificationType": "apns"]),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
        ], headers: headers(account))
        try requireSuccess(result, field: "checkForAuthenticationResult", operation: "CheckForAuthentication")
        let username = try requiredText(result, "username")
        guard try result.value("phoneAppDetailId") == account.id, try result.value("groupKey") == account.groupKey,
              username.caseInsensitiveCompare(account.username) == .orderedSame else { throw Failure.invalidResponse }
        let discoveredEndpoint = try Route.phoneApp.url(requiredText(result, "padUrl"))
        let counter = try unsigned(result.value("oathCounter"))
        // The draft discovery response omits GUID, but EEID context retrieval requires it. Never invent one or report no work.
        guard let value = try result.optionalValue("guid"), let identifier = UUID(uuidString: value) else {
            throw Failure.serviceFailure(operation: "CheckForAuthentication", code: "MissingChallengeGUID")
        }
        let guid = identifier.uuidString.lowercased()
        return MSALNativeAuthSASPendingAuthentication(guid: guid, endpoint: discoveredEndpoint, username: username, counter: counter)
    }

    // swiftlint:disable:next function_body_length
    func authentication(
        guid: String, token: String, account: MSALNativeAuthMFAAccountRecord?, counter: UInt64?, endpoint: URL
    ) async throws -> MSALNativeAuthSASAuthenticationResult {
        guard let guid = UUID(uuidString: guid)?.uuidString.lowercased() else { throw Failure.invalidSession }
        try validateToken(token)
        let proof: String
        if let account {
            try validateBinding(account)
            guard let counter else { throw Failure.invalidSession }
            proof = try MSALNativeAuthMFAProof.validation(secret: account.secret, counter: counter)
        } else {
            guard counter == nil else { throw Failure.invalidSession }
            proof = ""
        }
        let result = try await phoneApp(operation: "PhoneAppAuthentication", endpoint: endpoint, fields: [
            context(guid: guid, token: token, proof: proof, needsDos: true)
        ], headers: account.map { try headers($0) } ?? [:])
        let id = try requiredText(result, "guid")
        guard UUID(uuidString: id) == UUID(uuidString: guid) else { throw Failure.invalidResponse }
        let info = try result.child("phoneAppInfo")
        let tenantId = try identifier(info, "tenantId")
        let objectId = try identifier(info, "azureObjectId")
        let registrationId = try requiredText(info, "phoneAppDetailId")
        let sessionId = try requiredText(info, "sasSessionId")
        let serverCounter = try unsigned(result.value("oathCounter"))
        let dosPreventer = try requiredText(result, "dosPreventer")
        if let account {
            guard registrationId == account.id, tenantId == account.tenantId.lowercased(),
                  objectId == account.objectId.lowercased() else { throw Failure.invalidResponse }
        }
        if let mode = info.attributes["mode"], mode != "standard" { throw Failure.unsupportedPolicy }
        for name in ["returnLocationData", "isSilent"] {
            if let value = try info.optionalValue(name), value != "no" { throw Failure.unsupportedPolicy }
        }
        guard try info.value("isAppLockRequired") == "no" else { throw Failure.unsupportedPolicy }
        let policy = try MSALNativeAuthMFACredentialPolicy(
            encoded: requiredText(info, "userCredentialPolicy"), allowsDeviceBasedPush: true
        )
        guard policy.requiresNumberMatching else { throw Failure.unsupportedPolicy }
        let serverContext = ChallengeContext(
            guid: guid, registrationId: registrationId, tenantId: tenantId, objectId: objectId,
            sasSessionId: sessionId, counter: serverCounter, endpoint: endpoint,
            tokenDigest: MSALNativeAuthMFAProof.digest(token)
        )
        return try MSALNativeAuthSASAuthenticationResult(
            guid: guid, registrationId: registrationId, tenantId: tenantId, objectId: objectId,
            replicationScope: info.optionalValue("replicationScope"), routingHint: info.optionalValue("routingHint"),
            countryCode: info.optionalValue("countryCode"), dosPreventer: dosPreventer,
            requiresNumberMatching: true, policySupported: true, serverContext: JSONEncoder().encode(serverContext)
        )
    }

    func pinValidation(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, number: String, endpoint: URL
    ) async throws {
        guard !number.isEmpty, number.utf8.count <= 10, number.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw Failure.invalidNumber
        }
        let fields = try decisionFields(challenge: challenge, token: token, account: account, endpoint: endpoint) + [
            XML(name: "authenticate", text: "no"), XML(name: "selectedEntropyNumber", text: number)
        ]
        let result = try await phoneApp(operation: "PhoneAppPinValidation", endpoint: endpoint, fields: fields, headers: headers(account))
        let code = try numericCode(result, "validationResult")
        if code == "5" { throw Failure.completedSession }
        guard code == "6" else { throw Failure.serviceFailure(operation: "PhoneAppPinValidation", code: code) }
        try validateDecisionIdentity(result, account: account)
    }

    func authenticationResult(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, approved: Bool, endpoint: URL
    ) async throws {
        guard !approved else { throw Failure.unsupportedPolicy }
        let fields = try decisionFields(challenge: challenge, token: token, account: account, endpoint: endpoint) + [
            XML(name: "authenticationResult", text: "2")
        ]
        let result = try await phoneApp(
            operation: "PhoneAppAuthenticationResult", endpoint: endpoint, fields: fields, headers: headers(account)
        )
        try requireSuccess(result, field: "authenticationResultResult", operation: "PhoneAppAuthenticationResult")
        try validateDecisionIdentity(result, account: account)
    }

    func getEndpoints(endpoint: URL) async throws -> MSALNativeAuthSASEndpoints {
        try Task.checkCancellation()
        // EEID has no GetEndpoints operation. Keep the validated gateway and its routing query, without a discovery request.
        let endpoint = try Route.phoneApp.url(endpoint.absoluteString)
        return MSALNativeAuthSASEndpoints(defaultURL: endpoint.absoluteString, endpoints: [:])
    }

    private struct ChallengeContext: Codable, Sendable {
        let guid: String
        let registrationId: String
        let tenantId: String
        let objectId: String
        let sasSessionId: String
        let counter: UInt64
        let endpoint: URL
        let tokenDigest: String
    }

    private func decisionFields(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String, account: MSALNativeAuthMFAAccountRecord, endpoint: URL
    ) throws -> [XML] {
        try validateBinding(account)
        try validateToken(token)
        guard challenge.policySupported, challenge.requiresNumberMatching,
              let data = challenge.serverContext, data.count <= 32_768 else { throw Failure.invalidSession }
        let stored: ChallengeContext
        do {
            stored = try JSONDecoder().decode(ChallengeContext.self, from: data)
        } catch {
            throw Failure.invalidSession
        }
        guard UUID(uuidString: stored.guid) != nil, stored.guid == challenge.guid,
              stored.registrationId == challenge.registrationId, stored.registrationId == account.id,
              stored.tenantId == challenge.tenantId, stored.tenantId == account.tenantId.lowercased(),
              stored.objectId == challenge.objectId, stored.objectId == account.objectId.lowercased(),
              !stored.sasSessionId.isEmpty, stored.endpoint == endpoint,
              stored.tokenDigest == MSALNativeAuthMFAProof.digest(token) else { throw Failure.invalidSession }
        // The counter belongs to the retrieved challenge, not the device clock. Do not fabricate appState/integrity evidence.
        return [
            context(guid: stored.guid, token: token, proof: "", needsDos: false),
            XML(name: "oathCounter", text: String(stored.counter)),
            XML(name: "completedInteractively", text: "yes"), XML(name: "isAppLockUsed", text: "no")
        ]
    }

    private func validateDecisionIdentity(_ response: XML, account: MSALNativeAuthMFAAccountRecord) throws {
        guard try identifier(response, "azureObjectId") == account.objectId.lowercased(),
              try identifier(response, "tenantId") == account.tenantId.lowercased(),
              try response.value("username").caseInsensitiveCompare(account.username) == .orderedSame else {
            throw Failure.invalidResponse
        }
    }

    private func nativeBundleId() throws -> String {
        guard let value = Bundle.main.bundleIdentifier, !value.isEmpty, value.utf8.count <= 255,
              !value.unicodeScalars.contains(where: {
                  CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0)
              }) else { throw Failure.invalidActivationInput }
        return value
    }

    private func validateBinding(_ account: MSALNativeAuthMFAAccountRecord) throws {
        _ = try Route.phoneApp.url(account.endpoint.absoluteString)
        guard let bundleId = account.bundleId, try bundleId == nativeBundleId(),
              UUID(uuidString: account.tenantId) != nil, UUID(uuidString: account.objectId) != nil,
              !account.id.isEmpty, !account.username.isEmpty, !account.groupKey.isEmpty else {
            throw Failure.serviceFailure(operation: "EEIDRegistrationBinding", code: "InvalidBinding")
        }
        try validateToken(account.activatedToken)
    }

    private func validateToken(_ token: String) throws {
        let prefix = token.hasPrefix("sb-apns2-") ? "sb-apns2-" : "apns2-"
        guard token.hasPrefix(prefix) else { throw Failure.invalidDeviceToken }
        let hex = token.dropFirst(prefix.count)
        guard !hex.isEmpty, hex.utf8.count <= 8192, hex.utf8.count.isMultiple(of: 2),
              hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else {
            throw Failure.invalidDeviceToken
        }
    }

    private func context(guid: String, token: String, proof: String, needsDos: Bool) -> XML {
        XML(name: "phoneAppContext", children: [
            XML(name: "guid", text: guid), XML(name: "oathCode", text: proof),
            XML(name: "needDosPreventer", text: needsDos ? "yes" : "no"), XML(name: "deviceToken", text: token),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
        ])
    }

    private func headers(_ account: MSALNativeAuthMFAAccountRecord) throws -> [String: String] {
        let values = [
            "x-ms-client-tenant-id": account.tenantId, "x-ms-client-replication-scope": account.replicationScope,
            "x-ms-routing-hint": account.routingHint, "x-ms-client-tenant-country-code": account.countryCode
        ].filter { !$0.value.isEmpty }
        guard values.values.allSatisfy({
            $0.utf8.count <= 4096 && $0.utf8.allSatisfy { (33...126).contains($0) }
        }) else { throw Failure.invalidResponse }
        return values
    }

    private func requiredText(_ xml: XML, _ name: String) throws -> String {
        let value = try xml.value(name)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.utf8.count <= 4096,
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw Failure.invalidResponse
        }
        return value
    }

    private func identifier(_ xml: XML, _ name: String) throws -> String {
        guard let value = UUID(uuidString: try requiredText(xml, name)) else { throw Failure.invalidResponse }
        return value.uuidString.lowercased()
    }

    private func unsigned(_ value: String) throws -> UInt64 {
        guard !value.isEmpty, value.utf8.count <= 20, value.utf8.allSatisfy({ (48...57).contains($0) }),
              let number = UInt64(value) else { throw Failure.invalidResponse }
        return number
    }

    private func numericCode(_ xml: XML, _ name: String) throws -> String {
        let value = try xml.value(name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count <= 10 else { throw Failure.invalidResponse }
        return String(try unsigned(value))
    }

    private func requireSuccess(_ xml: XML, field: String, operation: String) throws {
        let code = try numericCode(xml, field)
        guard code == "1" else { throw Failure.serviceFailure(operation: operation, code: code) }
    }

    private func activation(operation: String, endpoint: URL, fields: [XML]) async throws -> XML {
        let envelope = XML(
            name: "soap:Envelope", attributes: ["xmlns:soap": "http://schemas.xmlsoap.org/soap/envelope/"],
            children: [XML(name: "soap:Body", children: [XML(name: operation, attributes: ["xmlns": namespace], children: fields)])]
        )
        // SOAPAction and installation-proof headers are not defined by the EEID binding; do not guess their values.
        let request = try request(endpoint: endpoint, body: envelope, route: .activation)
        let response = try parse(await transport.send(request, endpointPolicy: Route.activation))
        guard response.name == "Envelope" else { throw Failure.invalidResponse }
        let body = try response.child("Body")
        if body.children.contains(where: { $0.name == "Fault" }) {
            throw Failure.serviceFailure(operation: operation, code: "SOAPFault")
        }
        guard body.children.count == 1 else { throw Failure.invalidResponse }
        let result = try body.child(operation + "Response")
        let outcome = try result.value(operation + "Result").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["true", "1", "false", "0"].contains(outcome) else { throw Failure.invalidResponse }
        let code = try numericCode(result.child("error"), "Code")
        // False/15 does not prove rollback. Keep the orchestration's uncertain-enrollment guard instead of enabling replay.
        guard (outcome == "true" || outcome == "1"), code == "0" else {
            throw Failure.serviceFailure(operation: operation, code: code)
        }
        return result
    }

    private func phoneApp(operation: String, endpoint: URL, fields: [XML], headers: [String: String] = [:]) async throws -> XML {
        let tag = operation.prefix(1).lowercased() + operation.dropFirst()
        let requestId = (MSALNativeAuthMFARequestContext.correlationId ?? UUID()).uuidString.lowercased()
        let body = XML(name: "pfpMessage", attributes: ["version": "1.6"], children: [
            XML(name: "header"),
            // The EEID receiver's PfpBoolean encoding is no/yes, unlike the draft's illustrative 0/1 attributes.
            XML(name: "request", attributes: [
                "request-id": requestId, "language": "en_us", "async": "no", "response-url": "", "synthetic": "no"
            ], children: [XML(name: tag.hasSuffix("Request") ? tag : tag + "Request", children: fields)])
        ])
        var request = try request(endpoint: endpoint, body: body, route: .phoneApp)
        request.setValue(operation, forHTTPHeaderField: "x-ms-mac-action")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let result = try parse(await transport.send(request, endpointPolicy: Route.phoneApp))
        guard result.name == "pfpMessage", result.attributes["version"] == "1.6" else { throw Failure.invalidResponse }
        let response = try result.child("response")
        let status = try response.child("status")
        let code = try numericCode(status, "error-id")
        guard let disposition = status.attributes["disposition"], ["success", "fail"].contains(disposition) else {
            throw Failure.invalidResponse
        }
        guard disposition == "success", code == "0" else { throw Failure.serviceFailure(operation: "PFPEnvelope", code: code) }
        guard response.attributes["request-id"] == requestId, response.children.count == 2 else { throw Failure.invalidResponse }
        let expected = tag.hasSuffix("Request") ? String(tag.dropLast(7)) + "Response" : tag + "Response"
        return try response.child(expected)
    }

    private func parse(_ data: Data) throws -> XML {
        let xml = try XML.parse(data)
        if xml.name == "eeidContractValidation" { throw Failure.validationOnlyEndpoint }
        return xml
    }

    private func request(endpoint: URL, body: XML, route: Route) throws -> URLRequest {
        try Task.checkCancellation()
        _ = try route.url(endpoint.absoluteString)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = Data(body.encoded.utf8)
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        MSALNativeAuthMFARequestHeaders.apply(to: &request)
        return request
    }

    private enum Route: MSALNativeAuthMFARequestPolicy {
        case activation
        case phoneApp

        private static let macPath = "/eeid/mac/MobileAppCommunicator.svc"

        func validate(_ request: URLRequest) throws {
            guard let endpoint = request.url, request.httpMethod == "POST", request.httpBody != nil else {
                throw Failure.untrustedEndpoint
            }
            _ = try url(endpoint.absoluteString)
        }

        func acceptsEmptyResponse(_ response: HTTPURLResponse) throws -> Bool {
            guard response.statusCode == 200 else { throw Failure.httpFailure(statusCode: response.statusCode) }
            if let value = response.value(forHTTPHeaderField: "X-MS-EEID-Validation-Only") {
                let value = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if value == "true" || value == "1" { throw Failure.validationOnlyEndpoint }
                guard value == "false" || value == "0" else { throw Failure.invalidResponse }
            }
            guard let mime = response.mimeType?.lowercased(), ["text/xml", "application/xml"].contains(mime) else {
                throw Failure.invalidResponse
            }
            return false
        }

        // swiftlint:disable:next cyclomatic_complexity
        func url(_ value: String) throws -> URL {
            guard value.utf8.count <= 4096, !value.contains("\\"),
                  !value.unicodeScalars.contains(where: {
                      CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0)
                  }),
                  let parts = URLComponents(string: value), parts.scheme?.lowercased() == "https",
                  parts.host?.lowercased() == "mobileappcommunicator.auth.microsoft.com",
                  parts.user == nil, parts.password == nil, parts.fragment == nil,
                  parts.port == nil || parts.port == 443,
                  let url = parts.url, url.absoluteString == value else { throw Failure.untrustedEndpoint }
            if let items = parts.queryItems {
                guard !items.isEmpty, Set(items.map(\.name)).count == items.count,
                      items.allSatisfy({ item in
                          guard let value = item.value, !value.isEmpty, value.utf8.count <= 256 else { return false }
                          if item.name == "ts" { return value == "true" || value == "false" }
                          return item.name == "su" && Self.isPathSegment(value)
                      }) else { throw Failure.untrustedEndpoint }
            }
            switch self {
            case .phoneApp:
                guard parts.percentEncodedPath == Self.macPath else { throw Failure.untrustedEndpoint }
            case .activation:
                let segments = parts.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
                guard segments.count == 7, segments[0].isEmpty,
                      "/" + segments[1...3].joined(separator: "/") == Self.macPath,
                      Self.isPathSegment(String(segments[4])), Self.isPathSegment(String(segments[5])),
                      segments[6] == "PfPaWs.asmx" else { throw Failure.untrustedEndpoint }
            }
            return url
        }

        private static func isPathSegment(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 1024 && value.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
            }
        }
    }
}
