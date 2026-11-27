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

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
internal struct MSALNativeAuthSASLegacyClient: MSALNativeAuthSASClient {
    let isImplemented = true

    private typealias XML = MSALNativeAuthMFAXml
    private typealias Failure = MSALNativeAuthMFAFailure
    private typealias Policy = MSALNativeAuthMFAEndpoint.Policy

    private let transport: any MSALNativeAuthMFATransporting
    private let namespace = "http://www.phonefactor.com/PfPaWs"
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private var counter: String { String(UInt64(Date().timeIntervalSince1970 / 30)) }
    private var osVersion: String { ProcessInfo.processInfo.operatingSystemVersionString }

    init(transport: any MSALNativeAuthMFATransporting) {
        self.transport = transport
    }

    func activationInput(_ parameters: MSALNativeAuthMFARegistrationParameters) throws -> MSALNativeAuthMFAActivation {
        try parameters.validatedActivation()
    }

    func deviceToken(_ data: Data, environment: MSALNativeAuthMFAAPNsEnvironment) throws -> String {
        try MSALNativeAuthMFAProof.token(data, environment: environment)
    }

    func notification(_ payload: [AnyHashable: Any]) throws -> MSALNativeAuthSASNotification? {
        let fields = try MSALNativeAuthMFANotification.fields(payload)
        guard let type = fields["type"] else { return nil }
        guard let guid = fields["guid"], UUID(uuidString: guid) != nil, let url = fields["url"] else {
            throw Failure.unexpectedNotification
        }
        let endpoint = try MSALNativeAuthMFAEndpoint.notification(url)
        if type == "auth" { return .authentication(guid: guid, endpoint: endpoint) }
        let scenario: MSALNativeAuthSASValidationScenario?
        switch fields["validationScenario"] {
        case nil: scenario = nil
        case "QrRegistration": scenario = .enrollment
        case "DeviceTokenChangeV2": scenario = .tokenChange
        default: throw Failure.unexpectedNotification
        }
        return .validation(MSALNativeAuthSASValidationNotification(
            guid: guid, endpoint: endpoint, scenario: scenario,
            counter: fields["oathCounter"].flatMap { UInt64($0) }, tenantId: fields["tenantId"]
        ))
    }

    func endpoint(for scope: String, in endpoints: MSALNativeAuthSASEndpoints) throws -> URL {
        try MSALNativeAuthMFAEndpoint.phoneApp(endpoints.endpoints[scope] ?? endpoints.defaultURL)
    }

    func activate(input: MSALNativeAuthMFAActivation, token: String, deviceName: String) async throws -> MSALNativeAuthSASActivationResult {
        let result = try await activation(operation: "ActivateNew", endpoint: input.endpoint, fields: [
            XML(name: "activationParams", children: [
                XML(name: "ActivationCode", text: input.code),
                XML(name: "DeviceToken", text: token),
                XML(name: "DeviceName", text: deviceName),
                XML(name: "OathCounter", text: counter),
                XML(name: "Version", text: version)
            ])
        ])
        return try MSALNativeAuthSASActivationResult(legacyXML: result)
    }

    func confirmActivation(code: String, endpoint: URL) async throws -> String {
        let result = try await activation(operation: "ConfirmActivation", endpoint: endpoint, fields: [
            XML(name: "confirmationCode", text: code)
        ])
        let registrationId = try result.value("phoneAppDetailId")
        guard !registrationId.isEmpty else { throw Failure.invalidResponse }
        return registrationId
    }

    func validateDeviceToken(guid: String, token: String, endpoint: URL) async throws -> MSALNativeAuthSASValidationResult {
        let result = try await phoneApp(operation: "PhoneAppValidateDeviceToken", endpoint: endpoint, fields: [
            context(guid: guid, token: token, proof: "", needsDos: true),
            XML(name: "validationResult", text: "yes"), XML(name: "accounts")
        ])
        return try MSALNativeAuthSASValidationResult(legacyXML: result)
    }

    func startDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, environment: MSALNativeAuthMFAAPNsEnvironment, endpoint: URL
    ) async throws {
        let result = try await phoneApp(operation: "PhoneAppStartDeviceTokenChangeV2Request", endpoint: endpoint, fields: [
            XML(name: "newDeviceToken", text: token),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion),
            XML(name: "appPackageName", text: Bundle.main.bundleIdentifier ?? ""),
            XML(name: "notificationType", text: environment == .sandbox ? "APNS_SANDBOX" : "APNS2")
        ], headers: headers(account))
        try requireSuccess(result, field: "deviceTokenChangeResult", operation: "DeviceTokenChange")
    }

    func completeDeviceTokenChange(
        account: MSALNativeAuthMFAAccountRecord, token: String, counter: UInt64, endpoint: URL
    ) async throws {
        let result = try await phoneApp(operation: "PhoneAppCompleteDeviceTokenChangeV2Request", endpoint: endpoint, fields: [
            XML(name: "newDeviceToken", text: token),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion),
            XML(name: "accounts", children: [
                XML(name: "account", children: [
                    XML(name: "azureObjectId", text: account.objectId),
                    XML(name: "azureTenantId", text: account.tenantId),
                    XML(name: "phoneAppDetailId", text: account.id),
                    XML(name: "oathCode", text: try MSALNativeAuthMFAProof.validation(secret: account.secret, counter: counter))
                ])
            ])
        ], headers: headers(account))
        try requireSuccess(result, field: "deviceTokenChangeResult", operation: "CompleteDeviceTokenChange")
        let results = try result.child("accountValidationResults").children
        guard try results.contains(where: {
            try $0.value("phoneAppDetailId") == account.id && $0.value("validationResult") == "Success"
        }) else { throw Failure.serviceFailure(operation: "CompleteDeviceTokenChange", code: "AccountRejected") }
    }

    func checkForAuthentication(
        account: MSALNativeAuthMFAAccountRecord, previousToken: String?, endpoint: URL
    ) async throws -> MSALNativeAuthSASPendingAuthentication? {
        let result = try await phoneApp(operation: "PhoneAppCheckForAuthentication", endpoint: endpoint, fields: [
            XML(name: "dosPreventer", text: account.dosPreventer),
            XML(name: "deviceToken", text: account.activatedToken, attributes: ["notificationType": "apns"]),
            XML(name: "previousDeviceToken", text: previousToken ?? ""),
            XML(name: "version", text: version), XML(name: "osVersion", text: osVersion)
        ], headers: headers(account))
        try requireSuccess(result, field: "checkForAuthenticationResult", operation: "CheckForAuthentication")
        let host = try result.value("padUrl")
        if host.isEmpty { return nil }
        let registrationId = try result.value("phoneAppDetailId")
        guard !registrationId.isEmpty else { throw Failure.invalidResponse }
        guard let counter = UInt64(try result.value("oathCounter")) else { throw Failure.invalidResponse }
        return try MSALNativeAuthSASPendingAuthentication(
            guid: "", registrationId: registrationId, groupKey: result.value("groupKey"),
            endpoint: MSALNativeAuthMFAEndpoint.notification(host), username: result.value("username"), counter: counter
        )
    }

    func authentication(
        guid: String, token: String, account: MSALNativeAuthMFAAccountRecord?, counter: UInt64?, endpoint: URL
    ) async throws -> MSALNativeAuthSASAuthenticationResult {
        let proof: String
        if let account, let counter {
            proof = try MSALNativeAuthMFAProof.validation(secret: account.secret, counter: counter)
        } else {
            proof = ""
        }
        let result = try await phoneApp(operation: "PhoneAppAuthentication", endpoint: endpoint, fields: [
            context(guid: guid, token: token, proof: proof, needsDos: true)
        ], headers: account.map(headers) ?? [:])
        let id = try result.value("guid")
        guard UUID(uuidString: id) != nil, guid.isEmpty || guid == id else { throw Failure.invalidResponse }
        let info = try result.child("phoneAppInfo")
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
        return try MSALNativeAuthSASAuthenticationResult(
            guid: id, registrationId: info.value("phoneAppDetailId"),
            tenantId: info.value("tenantId"), objectId: info.value("azureObjectId"),
            replicationScope: info.value("replicationScope"), routingHint: info.optionalValue("routingHint") ?? "",
            countryCode: info.optionalValue("countryCode") ?? "", dosPreventer: result.value("dosPreventer"),
            requiresNumberMatching: requiresNumber, policySupported: policySupported, serverContext: nil
        )
    }

    func pinValidation(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, number: String, endpoint: URL
    ) async throws {
        let result = try await phoneApp(operation: "PhoneAppPinValidation", endpoint: endpoint, fields: [
            context(guid: challenge.guid, token: token, proof: "", needsDos: false),
            XML(name: "oathCounter", text: counter), XML(name: "completedInteractively", text: "yes"),
            XML(name: "pin", attributes: ["stored": "no"]),
            XML(name: "authenticate", text: "yes"), XML(name: "selectedEntropyNumber", text: number)
        ], headers: headers(account))
        let code = try result.value("validationResult")
        guard Int(code) != nil, code.count <= 10 else { throw Failure.invalidResponse }
        if code == "5" { throw Failure.completedSession }
        guard code == "6" else { throw Failure.serviceFailure(operation: "PhoneAppPinValidation", code: code) }
    }

    func authenticationResult(
        challenge: MSALNativeAuthSASAuthenticationResult, token: String,
        account: MSALNativeAuthMFAAccountRecord, approved: Bool, endpoint: URL
    ) async throws {
        let result = try await phoneApp(operation: "PhoneAppAuthenticationResult", endpoint: endpoint, fields: [
            context(guid: challenge.guid, token: token, proof: "", needsDos: false),
            XML(name: "oathCounter", text: counter), XML(name: "completedInteractively", text: "yes"),
            XML(name: "authenticationResult", text: approved ? "1" : "2"),
            XML(name: "newDeviceToken", attributes: ["notificationType": "apns"])
        ], headers: headers(account))
        try requireSuccess(result, field: "authenticationResultResult", operation: "PhoneAppAuthenticationResult")
    }

    func getEndpoints(endpoint: URL) async throws -> MSALNativeAuthSASEndpoints {
        let result = try await phoneApp(operation: "PhoneAppGetEndpoints", endpoint: endpoint, fields: [])
        _ = try result.value("version")
        let defaultURL = try result.value("defaultUrl")
        guard !defaultURL.isEmpty else { throw Failure.invalidResponse }
        var endpoints: [String: String] = [:]
        for item in try result.child("endpoints").children {
            let url = try item.value("url")
            let scopes = try item.value("replicationScopes").split(separator: ",", omittingEmptySubsequences: false)
            for scope in scopes {
                let scope = scope.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !scope.isEmpty, endpoints[scope] == nil else { throw Failure.invalidResponse }
                endpoints[scope] = url
            }
        }
        return MSALNativeAuthSASEndpoints(defaultURL: defaultURL, endpoints: endpoints)
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

    private func activation(operation: String, endpoint: URL, fields: [XML]) async throws -> XML {
        let method = XML(name: operation, attributes: ["xmlns": namespace], children: fields)
        let envelope = XML(
            name: "soap:Envelope", attributes: ["xmlns:soap": "http://schemas.xmlsoap.org/soap/envelope/"],
            children: [XML(name: "soap:Body", children: [method])]
        )
        var request = try request(endpoint: endpoint, body: envelope, endpointPolicy: .activation)
        request.setValue(namespace + "/" + operation, forHTTPHeaderField: "SOAPAction")
        let response = try XML.parse(await transport.send(request, endpointPolicy: Policy.activation))
        let body = try response.child("Body")
        if body.children.contains(where: { $0.name == "Fault" }) {
            throw Failure.serviceFailure(operation: operation, code: "SOAPFault")
        }
        let result = try body.child(operation + "Response")
        let outcome = try result.value(operation + "Result").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ["true", "1", "false", "0"].contains(outcome) else { throw Failure.invalidResponse }
        if outcome == "false" || outcome == "0" {
            var code = "Rejected"
            if result.children.contains(where: { $0.name == "error" }),
               let value = try result.child("error").optionalValue("Code") {
                let numericCode = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !numericCode.isEmpty, numericCode.utf8.count <= 10,
                   numericCode.utf8.allSatisfy({ (48...57).contains($0) }) {
                    code = numericCode
                }
            }
            throw Failure.enrollmentRejected(code: code)
        }
        return result
    }

    private func phoneApp(operation: String, endpoint: URL, fields: [XML], headers: [String: String] = [:]) async throws -> XML {
        let tag = operation.prefix(1).lowercased() + operation.dropFirst()
        let body = XML(
            name: "pfpMessage", attributes: ["version": "1.6"],
            children: [
                XML(name: "header", children: [
                    XML(name: "source", children: [
                        XML(name: "component", attributes: ["type": "pfsvc", "role": "master"], children: [
                            XML(name: "host", attributes: ["ip": "", "hostname": "", "serverId": ""])
                        ])
                    ])
                ]),
                XML(name: "request", attributes: [
                    "request-id": UUID().uuidString.lowercased(), "async": "0", "response-url": "", "language": "en"
                ], children: [
                    XML(name: tag.hasSuffix("Request") ? tag : tag + "Request", children: fields)
                ])
            ]
        )
        var request = try request(endpoint: endpoint, body: body, endpointPolicy: .phoneApp)
        request.setValue(operation, forHTTPHeaderField: "x-ms-mac-action")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let result = try XML.parse(await transport.send(request, endpointPolicy: Policy.phoneApp))
        let response = try result.child("response")
        guard try response.child("status").attributes["disposition"] == "success" else {
            throw Failure.serviceFailure(operation: operation, code: "Rejected")
        }
        let expected = tag.hasSuffix("Request") ? String(tag.dropLast(7)) + "Response" : tag + "Response"
        return try response.child(expected)
    }

    private func request(endpoint: URL, body: XML, endpointPolicy: Policy) throws -> URLRequest {
        try endpointPolicy.validate(endpoint)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = Data(body.encoded.utf8)
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        MSALNativeAuthMFARequestHeaders.apply(to: &request)
        return request
    }
}
