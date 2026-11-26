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

import XCTest
@testable import MSAL
@_implementationOnly import MSAL_Private

private struct MfaTestTokenProvider: MSALTokenProvider
{
    let acquire: @Sendable (MSALTokenProviderParameters) async throws -> MSALTokenProviderResult

    func getAccessToken(parameters: MSALTokenProviderParameters) async throws -> MSALTokenProviderResult
    {
        try await acquire(parameters)
    }
}

private extension MSALNativeAuthMFAManager
{
    func deleteAuthMethod(
        registrationId: String,
        tokenProvider: @escaping @Sendable (MSALTokenProviderParameters) async throws -> MSALTokenProviderResult
    ) async throws
    {
        try await deleteAuthMethod(registrationId: registrationId, tokenProvider: MfaTestTokenProvider(acquire: tokenProvider))
    }
}

final class MSALNativeAuthMFATests: XCTestCase
{
    private typealias XML = MSALNativeAuthMFAXml
    private typealias Failure = MSALNativeAuthMFAFailure

    private func assertFailure(_ error: Error, _ expected: Failure, file: StaticString = #filePath, line: UInt = #line)
    {
        if let internalFailure = error as? Failure
        {
            XCTAssertEqual(internalFailure, expected, file: file, line: line)
            return
        }
        guard let error = error as? MSALNativeAuthMFAError else
        {
            XCTFail("Expected the unified MFA error", file: file, line: line)
            return
        }
        let mapped = MSALNativeAuthMFAError.from(expected, correlationId: error.correlationId)
        XCTAssertEqual(Self.classifiers(error), Self.classifiers(mapped), file: file, line: line)
        XCTAssertEqual(error.errorDescription, mapped.errorDescription, file: file, line: line)
    }

    func testManagerPropagatesCorrelationThroughProviderHTTPAndError() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let captured = MfaCorrelationCapture()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            let header = try XCTUnwrap(request.value(forHTTPHeaderField: "client-request-id"))
            await captured.record(try XCTUnwrap(UUID(uuidString: header)))
            throw Failure.httpFailure(statusCode: 403)
        }, storage: storage)
        do
        {
            try await manager.deleteAuthMethod(registrationId: "registration") { request in
                await captured.record(request.correlationId)
                return try Self.deletionToken()
            }
            XCTFail("Expected Graph rejection")
        }
        catch
        {
            let error = try XCTUnwrap(error as? MSALNativeAuthMFAError)
            let ids = await captured.values
            XCTAssertEqual(ids, [error.correlationId, error.correlationId])
            XCTAssertTrue(error.isGeneralError)
        }
    }

    func testFinalErrorClassifiersAreExclusiveAndDiagnosticsAreSanitized()
    {
        let failures: [Failure] = [
            .missingPushRegistration, .registrationNotFound, .completedSession, .invalidNumber,
            .deletionAccountMismatch, .unknownAccount, .invalidSession, .invalidResponse, .unsupportedPolicy,
            .transportFailure, .storageFailure(status: -50), .outcomeUnknown, .validationOnlyEndpoint,
            .serviceFailure(operation: "sensitive-fixture", code: "sensitive-fixture")
        ]
        for failure in failures
        {
            let correlation = UUID()
            let error = MSALNativeAuthMFAError.from(failure, correlationId: correlation)
            XCTAssertEqual(Self.classifiers(error).filter { $0 }.count, 1)
            XCTAssertEqual(error.correlationId, correlation)
            XCTAssertFalse(error.errorDescription?.contains("sensitive-fixture") == true)
            XCTAssertNil((error as NSError).userInfo[NSUnderlyingErrorKey])
        }
        XCTAssertTrue(MSALNativeAuthMFAError.from(Failure.invalidNumber, correlationId: UUID()).isInvalidCode)
        XCTAssertTrue(MSALNativeAuthMFAError.from(Failure.unknownAccount, correlationId: UUID()).isGeneralError)
        XCTAssertTrue(MSALNativeAuthMFAError.from(Failure.completedSession, correlationId: UUID()).isInvalidChallenge)
    }

    func testProviderErrorsPropagateUnchangedIncludingSDKShapedErrors() async throws
    {
        let errors: [Error] = [
            NSError(domain: "provider-fixture", code: 1),
            MSALNativeAuthMFAError(type: .invalidCode, errorDescription: "provider-owned", correlationId: UUID()),
            Failure.invalidNumber, CancellationError()
        ]
        for expected in errors
        {
            let storage = MfaTestStorage()
            try storage.save(Self.deletionState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("A provider failure must never submit DELETE")
                return Data()
            }, storage: storage)
            do
            {
                try await manager.deleteAuthMethod(registrationId: "registration") { _ in throw expected }
                XCTFail("Expected unchanged provider error")
            }
            catch
            {
                if let expected = expected as? MSALNativeAuthMFAError { XCTAssertTrue((error as? MSALNativeAuthMFAError) === expected) }
                else if let expected = expected as? Failure { XCTAssertEqual(error as? Failure, expected) }
                else if expected is CancellationError { XCTAssertTrue(error is CancellationError) }
                else { XCTAssertTrue((error as NSError) === (expected as NSError)) }
            }
            XCTAssertTrue(try storage.load().unresolvedDeletions.isEmpty)
        }
    }

    func testEEIDRoutesPreserveActivationAndMACQueriesAndRejectLegacy() throws
    {
        let activation = try MSALNativeAuthMFAActivation(code: "synthetic", url: Self.activationURL)
        XCTAssertEqual(activation.endpoint.absoluteString, Self.activationURL)
        XCTAssertEqual(try MSALNativeAuthMFAEndpoint.macEndpoint(for: activation.endpoint).absoluteString, Self.macURL)
        XCTAssertEqual(try MSALNativeAuthMFAEndpoint.notification(String(Self.macURL.dropFirst(8))).absoluteString, Self.macURL)
        let query = Self.activationURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let qr = try MSALNativeAuthMFAActivation(
            qrCode: "https://login.microsoftonline.com/authenticatorApp/activateAccount?accountType=mfa&code=synthetic&url=\(query)"
        )
        XCTAssertEqual(qr, activation)
        for url in [
            "https://activation.auth.microsoft.com/pad", "https://activation.auth.microsoft.com/mac/MobileAppCommunicator.svc",
            Self.macURL + "&su=other", Self.macURL + "&ignored=value", Self.macURL + "#fragment",
            Self.macURL.replacingOccurrences(of: "https:", with: "http:"),
            Self.macURL.replacingOccurrences(of: "activation.auth.microsoft.com", with: "microsoft.com.evil.test"),
            Self.macURL.replacingOccurrences(of: "https://", with: "https://user@"),
            Self.macURL.replacingOccurrences(of: "ts=true", with: "ts=1"),
            Self.macURL.replacingOccurrences(of: "MobileAppCommunicator.svc", with: "MobileAppCommunicator.svc/../other")
        ]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.phoneApp(url))
        }
        XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.validate(Self.macURL))
        XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.phoneApp(Self.activationURL))
        XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.validate(Self.activationURL.replacingOccurrences(of: "/synthetic/", with: "/%2F/")))
    }

    func testEnvelopeLayersRejectDefaultsFaultsDuplicatesAndValidationOnly() async throws
    {
        let soapBodies = [
            Self.soap("ConfirmActivation", fields: "<error><Code>17</Code></error><phoneAppDetailId>id</phoneAppDetailId>"),
            Self.soap("ConfirmActivation", fields: "<error><Code>0</Code></error>", result: "false"),
            Self.soap("ConfirmActivation", fields: "<error><Code>0</Code><Code>0</Code></error>"),
            Self.soap("ConfirmActivation", fields: "<error><Code>0</Code></error><ConfirmActivationResult>true</ConfirmActivationResult>"),
            Data("<Envelope><Body><Fault><faultstring>sensitive-fixture</faultstring></Fault></Body></Envelope>".utf8),
            Data("<eeidContractValidation contractValid=\"true\" workflowExecuted=\"false\"/>".utf8)
        ]
        for body in soapBodies
        {
            let client = MSALNativeAuthMFAServiceClient(transport: MfaTestTransport { _ in body })
            do
            {
                _ = try await client.activation(operation: "ConfirmActivation", endpoint: XCTUnwrap(URL(string: Self.activationURL)), fields: [])
                XCTFail("Rejected SOAP response must not become success")
            }
            catch { XCTAssertTrue(error is Failure) }
        }
        for status in ["<status disposition=\"fail\"><error-id>9</error-id></status>",
                       "<status disposition=\"success\"><error-id>10</error-id></status>",
                       "<status disposition=\"success\"/>",
                       "<status disposition=\"success\"><error-id>0</error-id><error-id>0</error-id></status>"]
        {
            let client = MSALNativeAuthMFAServiceClient(transport: MfaTestTransport { _ in
                Data("<pfpMessage version=\"1.6\"><response>\(status)</response></pfpMessage>".utf8)
            })
            do
            {
                _ = try await client.phoneApp(operation: "PhoneAppCheckForAuthentication", endpoint: XCTUnwrap(URL(string: Self.macURL)), fields: [])
                XCTFail("Status-only failure must not become success")
            }
            catch { XCTAssertTrue(error is Failure) }
        }
    }

    func testXMLAndCryptoBoundsRemainEnforced() throws
    {
        let escaped = XML(name: "value", text: "<&\"'")
        XCTAssertEqual(try XML.parse(Data(escaped.encoded.utf8)).text, escaped.text)
        XCTAssertThrowsError(try XML.parse(Data("<!DOCTYPE a [<!ENTITY x 'y'>]><a>&x;</a>".utf8)))
        XCTAssertThrowsError(try XML.parse(Data("<a><v>1</v><v>2</v></a>".utf8)).value("v"))
        XCTAssertEqual(try MSALNativeAuthMFAProof.token(Data([0, 1]), environment: .sandbox), "sb-apns2-0001")
        XCTAssertEqual(try MSALNativeAuthMFAProof.token(Data([0, 1]), environment: .production), "apns2-0001")
        XCTAssertThrowsError(try MSALNativeAuthMFAProof.token(Data(), environment: .sandbox))
        XCTAssertEqual(try MSALNativeAuthMFAProof.validation(secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", counter: 1),
                       "75A48A19D4CBE100644E8AC1397EEA747A2D33AB")
    }

    func testMinimalEEIDPolicyAndUnsupportedRequirements() throws
    {
        XCTAssertTrue(try MSALNativeAuthMFACredentialPolicy(encoded: "EgIoAg==").requiresNumberMatching)
        for policy in ["", "not-base64", Self.credentialPolicy(phone: [0x28, 0x01]),
                       Self.credentialPolicy(phone: [0x28, 0x02, 0x20, 0x02]),
                       Self.credentialPolicy(phone: [0x28, 0x02, 0x40, 0x01]),
                       Self.credentialPolicy(phone: [0x28, 0x02, 0x28, 0x02]),
                       Self.credentialPolicy(phone: [0x28, 0x02, 0x10, 0x7f])]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFACredentialPolicy(encoded: policy))
        }
    }

    func testRawPushProjectionIgnoresUnrelatedValuesButRejectsMalformedRecognizedFields() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            let body = try XML.parse(XCTUnwrap(request.httpBody)).child("request")
            XCTAssertEqual(body.attributes["async"], "no")
            XCTAssertEqual(body.attributes["synthetic"], "no")
            XCTAssertEqual(body.attributes["language"], "en_us")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthentication")
            return Self.authentication(guid: guid, appLock: "no")
        }, storage: storage)
        let payload: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "fixture"], "badge": 1],
            "data": ["type": "auth", "guid": guid, "url": Self.macURL], "unrelated": [1, 2]
        ]
        let sessions = try await manager.handlePushNotification(payload: payload)
        XCTAssertEqual(sessions.first?.registrationId, "registration")
        XCTAssertTrue(sessions.first?.requiresNumberMatching == true)
        do
        {
            _ = try await manager.handlePushNotification(payload: ["type": "auth", "guid": 123, "url": Self.macURL])
            XCTFail("Recognized values must not be stringified")
        }
        catch { assertFailure(error, .unexpectedNotification) }
        let unrelated = try await manager.handlePushNotification(payload: ["type": "unrelated", "guid": [1]])
        XCTAssertTrue(unrelated.isEmpty)
    }

    func testEnrollmentArmsValidationBeforeSOAPAndKeepsProvisionalStateInMemory() async throws
    {
        for validationUsername in ["", "FIXTURE@EXAMPLE.TEST", "wrong@example.test", nil] as [String?]
        {
            let storage = MfaTestStorage()
            try storage.save(MSALNativeAuthMFAStoredState(currentToken: "sb-apns2-01"))
            let gate = MfaRequestGate()
            let started = expectation(description: "ActivateNew is waiting for validation")
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                let xml = try XML.parse(XCTUnwrap(request.httpBody))
                if request.value(forHTTPHeaderField: "SOAPAction")?.hasSuffix("/ActivateNew") == true
                {
                    let params = try xml.child("Body").child("ActivateNew").child("activationParams")
                    XCTAssertEqual(try params.value("BundleId"), "com.microsoft.azureauthenticator")
                    XCTAssertNil(try params.optionalValue("PackageName"))
                    XCTAssertNil(try params.optionalValue("authenticatorFlavor"))
                    XCTAssertEqual(request.url?.absoluteString, Self.activationURL)
                    started.fulfill()
                    await gate.wait()
                    return Self.activationSuccess()
                }
                if request.value(forHTTPHeaderField: "SOAPAction") != nil
                {
                    XCTAssertTrue(validationUsername == "" || validationUsername == "FIXTURE@EXAMPLE.TEST")
                    XCTAssertTrue(try storage.load().accounts.isEmpty)
                    let method = try xml.child("Body").child("ConfirmActivation")
                    XCTAssertEqual(method.children.map(\.name), ["confirmationCode"])
                    return Self.soap("ConfirmActivation", fields: "<error><Code>0</Code></error><phoneAppDetailId>registration</phoneAppDetailId>")
                }
                XCTAssertEqual(request.url?.absoluteString, Self.macURL)
                let callback = try xml.child("request").child("phoneAppValidateDeviceTokenRequest")
                XCTAssertEqual(try callback.value("validationResult"), "yes")
                XCTAssertEqual(try callback.child("phoneAppContext").value("deviceToken"), "sb-apns2-01")
                return Self.validationSuccess(username: validationUsername)
            }, storage: storage, deviceNameProvider: { "iPhone-fixture" }, bundleIdProvider: { "com.microsoft.azureauthenticator" })
            let enrollment = Task { try await manager.registerAuthMethod(registrationParameters: Self.parameters()) }
            await fulfillment(of: [started], timeout: 2)
            do
            {
                let result = try await manager.handlePushNotification(payload: Self.validationPush())
                XCTAssertTrue(result.isEmpty)
            }
            catch
            {
                XCTAssertNil(validationUsername)
                assertFailure(error, .invalidResponse)
            }
            let encoded = try JSONEncoder().encode(storage.load())
            XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("pendingEnrollment"))
            XCTAssertTrue(try storage.load().accounts.isEmpty)
            await gate.release()
            do
            {
                let result = try await enrollment.value
                XCTAssertTrue(validationUsername == "" || validationUsername == "FIXTURE@EXAMPLE.TEST")
                XCTAssertEqual(result.username, "fixture@example.test")
                let saved = try XCTUnwrap(storage.load().accounts.first)
                XCTAssertEqual(saved.bundleId, "com.microsoft.azureauthenticator")
                XCTAssertEqual(saved.endpoint.absoluteString, Self.macURL)
                XCTAssertEqual(saved.replicationScope, "NA")
            }
            catch
            {
                XCTAssertTrue(validationUsername == nil || validationUsername == "wrong@example.test")
                XCTAssertTrue(try storage.load().accounts.isEmpty)
            }
        }
    }

    func testEnrollmentCancellationReleasesGuardAndRestartDoesNotResume() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(MSALNativeAuthMFAStoredState(currentToken: "sb-apns2-01"))
        let started = expectation(description: "Activation submitted")
        let gate = MfaRequestGate()
        let transport = MfaTestTransport { _ in
            started.fulfill()
            await gate.wait()
            return Self.activationSuccess()
        }
        let manager = MSALNativeAuthMFAManager(transport: transport, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
        let task = Task { try await manager.registerAuthMethod(registrationParameters: Self.parameters()) }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        await gate.release()
        do { _ = try await task.value; XCTFail("Cancelled enrollment must not confirm") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox)
        let restarted = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
            XCTFail("Late enrollment validation must not restore an attempt")
            return Data()
        }, storage: storage)
        do { _ = try await restarted.handlePushNotification(payload: Self.validationPush()); XCTFail("No durable enrollment") }
        catch { assertFailure(error, .unexpectedNotification) }
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testEmptyValidationAndRejectedConfirmationNeverPersistRegistration() async throws
    {
        for rejectConfirmation in [false, true]
        {
            let storage = MfaTestStorage()
            try storage.save(MSALNativeAuthMFAStoredState(currentToken: "sb-apns2-01"))
            let started = expectation(description: "Activation submitted")
            let gate = MfaRequestGate()
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                if request.value(forHTTPHeaderField: "SOAPAction")?.hasSuffix("/ActivateNew") == true
                {
                    started.fulfill()
                    await gate.wait()
                    return Self.activationSuccess()
                }
                if request.value(forHTTPHeaderField: "SOAPAction") != nil
                {
                    XCTAssertTrue(rejectConfirmation)
                    return Self.soap("ConfirmActivation", fields: "<error><Code>17</Code></error>", result: "false")
                }
                return rejectConfirmation ? Self.validationSuccess() : Self.phone("phoneAppValidateDeviceTokenResponse", fields: "")
            }, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
            let task = Task { try await manager.registerAuthMethod(registrationParameters: Self.parameters()) }
            await fulfillment(of: [started], timeout: 2)
            do { _ = try await manager.handlePushNotification(payload: Self.validationPush()) }
            catch { XCTAssertFalse(rejectConfirmation) }
            await gate.release()
            do { _ = try await task.value; XCTFail("Enrollment must fail") }
            catch { XCTAssertTrue(error is MSALNativeAuthMFAError) }
            XCTAssertTrue(try storage.load().accounts.isEmpty)
            try await manager.updatePushRegistration(deviceToken: Data([1]), apnsEnvironment: .sandbox)
        }
    }

    func testValidationTimeoutReleasesInMemoryAttemptWithoutResumingIt() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(MSALNativeAuthMFAStoredState(currentToken: "sb-apns2-01"))
        let service = MSALNativeAuthMFAService(
            transport: MfaTestTransport { _ in Self.activationSuccess() }, storage: storage,
            bundleIdProvider: { "com.microsoft.azureauthenticator" }, validationTimeout: .zero
        )
        do
        {
            _ = try await service.register(MSALNativeAuthMFAActivation(code: "synthetic", url: Self.activationURL))
            XCTFail("Validation never arrived")
        }
        catch { XCTAssertEqual(error as? Failure, .validationTimedOut) }
        try await service.update(token: Data([2]), environment: .sandbox)
        do { _ = try await service.notification(Self.validationPush()); XCTFail("Timed-out attempt must not resume") }
        catch { XCTAssertEqual(error as? Failure, .unexpectedNotification) }
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testDiscovery101AndUnknownResultsNeverBecomeAnEmptyInbox() async throws
    {
        for result in ["101", "102", "103", "0", "unknown"]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppCheckForAuthentication")
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields: "<checkForAuthenticationResult>\(result)</checkForAuthenticationResult>")
            }, storage: storage)
            do { _ = try await manager.pullPendingNotifications(); XCTFail("Unconfirmed no-work must fail") }
            catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isGeneralError == true) }
        }
    }

    func testPullUsesDiscoveryProofAndRetrievesAuthoritativeContextWithoutGetEndpoints() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppCheckForAuthentication"
            {
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields: """
                    <checkForAuthenticationResult>1</checkForAuthenticationResult><padUrl>\(Self.macURL.replacingOccurrences(of: "&", with: "&amp;"))</padUrl>
                    <oathCounter>123</oathCounter><username>fixture@example.test</username><phoneAppDetailId>registration</phoneAppDetailId>
                    """)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthentication")
            let context = try XML.parse(XCTUnwrap(request.httpBody)).child("request").child("phoneAppAuthenticationRequest").child("phoneAppContext")
            XCTAssertEqual(try context.value("oathCode"), try MSALNativeAuthMFAProof.validation(secret: "GEZDGNBVGY3TQOJQ", counter: 123))
            return try Self.authenticationRespondingTo(request, guid: guid)
        }, storage: storage)
        let sessions = try await manager.pullPendingNotifications()
        XCTAssertEqual(sessions.map(\.registrationId), ["registration"])
        XCTAssertEqual(try storage.load().accounts[0].dosPreventer, "refreshed-proof")
    }

    func testPushRetrievalRequestsAndPersistsFreshDosPreventer() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            try Self.authenticationRespondingTo(request, guid: guid)
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: Self.authPush(guid))
        XCTAssertEqual(sessions.map(\.registrationId), ["registration"])
        XCTAssertEqual(try storage.load().accounts[0].dosPreventer, "refreshed-proof")
    }

    func testPullDoesNotReturnPartialResultsAfterAnAccountFailure() async throws
    {
        let storage = MfaTestStorage()
        var state = Self.registeredState()
        var other = state.accounts[0]
        other.id = "other"
        other.tenantId = "other-tenant"
        state.accounts.append(other)
        try storage.save(state)
        let guid = UUID().uuidString
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-client-tenant-id") == "other-tenant"
            {
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields: "<checkForAuthenticationResult>102</checkForAuthenticationResult>")
            }
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppCheckForAuthentication"
            {
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields: """
                    <checkForAuthenticationResult>1</checkForAuthenticationResult><oathCounter>123</oathCounter>
                    <username>fixture@example.test</username><phoneAppDetailId>registration</phoneAppDetailId>
                    <padUrl>\(Self.macURL.replacingOccurrences(of: "&", with: "&amp;"))</padUrl>
                    """)
            }
            return Self.authentication(guid: guid, appLock: "no")
        }, storage: storage)
        do { _ = try await manager.pullPendingNotifications(); XCTFail("Must not return first account's partial result") }
        catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isGeneralError == true) }
    }

    func testUnsupportedPolicyAndMismatchedIdentityFailDuringRetrieval() async throws
    {
        for mutation in ["policy", "tenant", "method", "counter", "session"]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let guid = UUID().uuidString
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                var response = String(decoding: Self.authentication(guid: guid, appLock: mutation == "policy" ? "yes" : "no"), as: UTF8.self)
                if mutation == "tenant" { response = response.replacingOccurrences(of: "<tenantId>tenant", with: "<tenantId>other") }
                if mutation == "method" { response = response.replacingOccurrences(of: "<phoneAppDetailId>registration", with: "<phoneAppDetailId>other") }
                if mutation == "counter" { response = response.replacingOccurrences(of: "<oathCounter>123</oathCounter>", with: "") }
                if mutation == "session" { response = response.replacingOccurrences(of: "<sasSessionId>session</sasSessionId>", with: "") }
                return Data(response.utf8)
            }, storage: storage)
            do { _ = try await manager.handlePushNotification(payload: Self.authPush(guid)); XCTFail("No deny-only session") }
            catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isGeneralError == true) }
        }
    }

    func testFinalActionsPreserveCounterAndNumberMatchingNoAndReplayProtection() async throws
    {
        for approve in [true, false]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let guid = UUID().uuidString
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                let action = request.value(forHTTPHeaderField: "x-ms-mac-action")
                if action == "PhoneAppAuthentication" { return Self.authentication(guid: guid, appLock: "no") }
                XCTAssertTrue(try storage.load().completedSessionIds.contains(guid))
                let xml = try XML.parse(XCTUnwrap(request.httpBody)).child("request")
                let body = try xml.child(approve ? "phoneAppPinValidationRequest" : "phoneAppAuthenticationResultRequest")
                XCTAssertEqual(try body.value("oathCounter"), "123")
                XCTAssertEqual(try body.value("completedInteractively"), "yes")
                XCTAssertEqual(try body.value("isAppLockUsed"), "no")
                XCTAssertNil(try body.optionalValue("appState"), "Do not synthesize device integrity evidence")
                if approve
                {
                    XCTAssertEqual(try body.value("authenticate"), "no")
                    XCTAssertEqual(try body.value("selectedEntropyNumber"), "042")
                    XCTAssertNil(try body.optionalValue("pin"))
                }
                else { XCTAssertEqual(try body.value("authenticationResult"), "2") }
                return Self.decisionResponse(approve: approve)
            }, storage: storage)
            let pending = try await manager.handlePushNotification(payload: Self.authPush(guid))
            let session = try XCTUnwrap(pending.first)
            for number in [nil, "", " 42", "4x", "４２", "12345678901"] as [String?]
            {
                do { _ = try await manager.respond(authSession: session, action: .approve(number: number)); XCTFail("Invalid local number") }
                catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isInvalidCode == true) }
                XCTAssertFalse(try storage.load().completedSessionIds.contains(guid))
            }
            let result = try await manager.respond(authSession: session, action: approve ? .approve(number: "042") : .deny)
            switch (approve, result)
            {
            case (true, .approved), (false, .denied): break
            default: XCTFail("Only the acknowledged action is returned")
            }
            do { _ = try await manager.respond(authSession: session, action: .deny); XCTFail("No second decision") }
            catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isInvalidChallenge == true) }
        }
    }

    func testWrongNumberAndUncertainDecisionRemainConsumedButPreSubmitSaveFailureDoesNot() async throws
    {
        for outcome in ["7", "5", "0", "unknown", "transport"]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let guid = UUID().uuidString
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthentication"
                {
                    return Self.authentication(guid: guid, appLock: "no")
                }
                if outcome == "transport" { throw Failure.transportFailure }
                return Self.phone("phoneAppPinValidationResponse", fields: "<validationResult>\(outcome)</validationResult>")
            }, storage: storage)
            let sessions = try await manager.handlePushNotification(payload: Self.authPush(guid))
            let session = try XCTUnwrap(sessions.first)
            storage.failNextSave()
            do { _ = try await manager.respond(authSession: session, action: .approve(number: "42")); XCTFail("Save must precede submission") }
            catch { assertFailure(error, .storageFailure(status: -50)) }
            XCTAssertFalse(try storage.load().completedSessionIds.contains(guid))
            do { _ = try await manager.respond(authSession: session, action: .approve(number: "42")); XCTFail("Service rejection") }
            catch { XCTAssertFalse((error as? MSALNativeAuthMFAError)?.isInvalidCode == true) }
            XCTAssertTrue(try storage.load().completedSessionIds.contains(guid))
            let restarted = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Restart must not revive consumed session")
                return Data()
            }, storage: storage)
            do { _ = try await restarted.handlePushNotification(payload: Self.authPush(guid)); XCTFail("Replay") }
            catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isInvalidChallenge == true) }
        }
    }

    func testV2ArmsEarlyUsesStoredBundleAndRequiresExactAccountOutcome() async throws
    {
        for outcome in ["Success", "UnknownFailure", "TransientFailure", "TransientFailureSkipped",
                        "FinalFailureDeviceNotFound", "FinalFailureBadRequest", "unknown", "duplicate", "wrong-account"]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let started = expectation(description: "V2 start pending")
            let gate = MfaRequestGate()
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                let xml = try XML.parse(XCTUnwrap(request.httpBody)).child("request")
                if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppStartDeviceTokenChangeV2Request"
                {
                    let start = try xml.child("phoneAppStartDeviceTokenChangeV2Request")
                    XCTAssertEqual(try start.value("appPackageName"), "com.microsoft.azureauthenticator")
                    XCTAssertNil(try start.optionalValue("authenticatorFlavor"))
                    XCTAssertNil(try start.optionalValue("customerAppId"), "No invented customer-app binding")
                    started.fulfill()
                    await gate.wait()
                    return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>1</deviceTokenChangeResult>")
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppCompleteDeviceTokenChangeV2Request")
                let complete = try xml.child("phoneAppCompleteDeviceTokenChangeV2Request")
                let account = try complete.child("accounts").child("account")
                XCTAssertEqual(try account.value("oathCode"), try MSALNativeAuthMFAProof.validation(secret: "GEZDGNBVGY3TQOJQ", counter: 123))
                let id = outcome == "wrong-account" ? "other" : "registration"
                let entry = """
                    <accountValidationResult><groupKey>group</groupKey><username>fixture@example.test</username>
                    <phoneAppDetailId>\(id)</phoneAppDetailId><azureObjectId>object</azureObjectId><azureTenantId>tenant</azureTenantId>
                    <validationResult>\(outcome == "duplicate" ? "Success" : outcome)</validationResult></accountValidationResult>
                    """
                return Self.phone("phoneAppCompleteDeviceTokenChangeV2Response", fields:
                    "<deviceTokenChangeResult>1</deviceTokenChangeResult><accountValidationResults>\(entry)\(outcome == "duplicate" ? entry : "")</accountValidationResults>")
            }, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
            let task = Task { try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox) }
            await fulfillment(of: [started], timeout: 2)
            XCTAssertEqual(try storage.load().accounts[0].activatedToken, "sb-apns2-01")
            var payload = Self.validationPush()
            payload["validationScenario"] = "DeviceTokenChangeV2"
            payload["tenantId"] = "tenant"
            payload["oathCounter"] = "123"
            do { _ = try await manager.handlePushNotification(payload: payload) }
            catch { XCTAssertNotEqual(outcome, "Success") }
            await gate.release()
            do { try await task.value; XCTAssertEqual(outcome, "Success") }
            catch { XCTAssertNotEqual(outcome, "Success") }
            XCTAssertEqual(try storage.load().accounts[0].activatedToken, outcome == "Success" ? "sb-apns2-02" : "sb-apns2-01")
            if outcome != "Success"
            {
                let restarted = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                    XCTFail("Unresolved V2 mutation must not replay")
                    return Data()
                }, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
                do { try await restarted.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox); XCTFail("Unresolved rotation") }
                catch { assertFailure(error, .outcomeUnknown) }
            }
        }
    }

    func testV2ConfirmedCompletionAfterCancellationPersistsUnlessRegistrationWasDeleted() async throws
    {
        for deleted in [false, true]
        {
            let storage = MfaTestStorage()
            let initial = Self.deletionState()
            try storage.save(initial)
            let account = try XCTUnwrap(initial.accounts.first)
            let started = expectation(description: "V2 started")
            let completing = expectation(description: "Completion HTTP held")
            let gate = MfaRequestGate()
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                if request.httpMethod == "DELETE" { return Data() }
                if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppStartDeviceTokenChangeV2Request"
                {
                    started.fulfill()
                    return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>1</deviceTokenChangeResult>")
                }
                completing.fulfill()
                await gate.wait()
                return Self.phone("phoneAppCompleteDeviceTokenChangeV2Response", fields: """
                    <deviceTokenChangeResult>1</deviceTokenChangeResult><accountValidationResults><accountValidationResult>
                    <groupKey>\(account.groupKey)</groupKey><username>\(account.username)</username>
                    <phoneAppDetailId>\(account.id)</phoneAppDetailId><azureObjectId>\(account.objectId)</azureObjectId>
                    <azureTenantId>\(account.tenantId)</azureTenantId><validationResult>Success</validationResult>
                    </accountValidationResult></accountValidationResults>
                    """)
            }, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
            let update = Task { try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox) }
            await fulfillment(of: [started], timeout: 2)
            var payload = Self.validationPush()
            payload["validationScenario"] = "DeviceTokenChangeV2"
            payload["tenantId"] = account.tenantId
            payload["oathCounter"] = "123"
            let notification = Task { try await manager.handlePushNotification(payload: payload) }
            await fulfillment(of: [completing], timeout: 2)
            update.cancel()
            do { try await update.value; XCTFail("Initiating update must cancel") }
            catch { XCTAssertTrue(error is CancellationError) }
            if deleted
            {
                try await manager.deleteAuthMethod(registrationId: account.id) { _ in try Self.deletionToken() }
            }
            await gate.release()
            do { _ = try await notification.value; XCTFail("Cancelled validation must not resume") }
            catch { assertFailure(error, deleted ? .unknownAccount : .unexpectedNotification) }
            let final = try storage.load()
            XCTAssertTrue(final.unresolvedTokenUpdates.isEmpty)
            XCTAssertEqual(final.accounts.map(\.activatedToken), deleted ? [] : ["sb-apns2-02"])
            let restarted = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Confirmed completion must not replay")
                return Data()
            }, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
            try await restarted.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox)
        }
    }

    func testRotationCannotRebindBundleOrAPNsEnvironment() async throws
    {
        for changedBundle in [true, false]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Rotation cannot rebind an installation")
                return Data()
            }, storage: storage, bundleIdProvider: { changedBundle ? "com.example.other" : "com.microsoft.azureauthenticator" })
            do
            {
                try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: changedBundle ? .sandbox : .production)
                XCTFail("Changed app binding must fail")
            }
            catch { assertFailure(error, .invalidResponse) }
            XCTAssertEqual(try storage.load().accounts[0].activatedToken, "sb-apns2-01")
            XCTAssertTrue(try storage.load().unresolvedTokenUpdates.isEmpty)
        }
    }

    func testConfirmedEnrollmentSaveFailureDoesNotReturnOrResumeRegistration() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(MSALNativeAuthMFAStoredState(currentToken: "sb-apns2-01"))
        let started = expectation(description: "ActivateNew pending")
        let gate = MfaRequestGate()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "SOAPAction")?.hasSuffix("/ActivateNew") == true
            {
                started.fulfill()
                await gate.wait()
                return Self.activationSuccess()
            }
            if request.value(forHTTPHeaderField: "SOAPAction") != nil
            {
                storage.failNextSave()
                return Self.soap("ConfirmActivation", fields: "<error><Code>0</Code></error><phoneAppDetailId>registration</phoneAppDetailId>")
            }
            return Self.validationSuccess()
        }, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
        let task = Task { try await manager.registerAuthMethod(registrationParameters: Self.parameters()) }
        await fulfillment(of: [started], timeout: 2)
        _ = try await manager.handlePushNotification(payload: Self.validationPush())
        await gate.release()
        do { _ = try await task.value; XCTFail("Local save must succeed before returning enrollment") }
        catch { assertFailure(error, .storageFailure(status: -50)) }
        XCTAssertTrue(try storage.load().accounts.isEmpty)
        do { _ = try await manager.registerAuthMethod(registrationParameters: Self.parameters()); XCTFail("No confirmation replay") }
        catch { assertFailure(error, .outcomeUnknown) }
        try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox)
    }

    func testV2PreservesCompletedFirstAccountWhenSecondStartFails() async throws
    {
        let storage = MfaTestStorage()
        var initial = Self.registeredState()
        var other = initial.accounts[0]
        other.id = "other"
        other.tenantId = "other-tenant"
        initial.accounts.append(other)
        try storage.save(initial)
        let started = expectation(description: "First start pending")
        let gate = MfaRequestGate()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppStartDeviceTokenChangeV2Request"
            {
                if request.value(forHTTPHeaderField: "x-ms-client-tenant-id") == "other-tenant"
                {
                    return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>502</deviceTokenChangeResult>")
                }
                started.fulfill()
                await gate.wait()
                return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>1</deviceTokenChangeResult>")
            }
            return Self.phone("phoneAppCompleteDeviceTokenChangeV2Response", fields: """
                <deviceTokenChangeResult>1</deviceTokenChangeResult><accountValidationResults><accountValidationResult>
                <groupKey>group</groupKey><username>fixture@example.test</username><phoneAppDetailId>registration</phoneAppDetailId>
                <azureObjectId>object</azureObjectId><azureTenantId>tenant</azureTenantId><validationResult>Success</validationResult>
                </accountValidationResult></accountValidationResults>
                """)
        }, storage: storage, bundleIdProvider: { "com.microsoft.azureauthenticator" })
        let task = Task { try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox) }
        await fulfillment(of: [started], timeout: 2)
        var payload = Self.validationPush()
        payload["validationScenario"] = "DeviceTokenChangeV2"
        payload["tenantId"] = "tenant"
        payload["oathCounter"] = "123"
        _ = try await manager.handlePushNotification(payload: payload)
        await gate.release()
        do { try await task.value; XCTFail("Second account failure must not return success") }
        catch { assertFailure(error, .serviceFailure(operation: "DeviceTokenChange", code: "502")) }
        XCTAssertEqual(try storage.load().accounts.map(\.activatedToken), ["sb-apns2-02", "sb-apns2-01"])
        XCTAssertEqual(try storage.load().unresolvedTokenUpdates, ["other"])
    }

    func testDecisionCanCompleteWhileDeletionTokenAcquisitionIsPending() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let guid = UUID().uuidString
        let gate = MfaRequestGate()
        let acquiring = expectation(description: "Token acquisition pending")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.httpMethod == "DELETE" { return Data() }
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthentication"
            {
                return Self.deletionAuthentication(guid: guid)
            }
            return Self.decisionResponse(approve: false, deletionIdentity: true)
        }, storage: storage)
        let deletion = Task {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in
                acquiring.fulfill()
                await gate.wait()
                return try Self.deletionToken()
            }
        }
        await fulfillment(of: [acquiring], timeout: 2)
        let sessions = try await manager.handlePushNotification(payload: Self.authPush(guid))
        let result = try await manager.respond(authSession: XCTUnwrap(sessions.first), action: .deny)
        switch result
        {
        case .denied: break
        case .approved: XCTFail("Denial must remain denial")
        }
        await gate.release()
        try await deletion.value
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testConcurrentDecisionAndCancellationNeverPermitSecondSubmission() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let gate = MfaRequestGate()
        let submitting = expectation(description: "Decision submitted")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthentication"
            {
                return Self.authentication(guid: guid, appLock: "no")
            }
            submitting.fulfill()
            await gate.wait()
            throw CancellationError()
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: Self.authPush(guid))
        let session = try XCTUnwrap(sessions.first)
        let first = Task { try await manager.respond(authSession: session, action: .deny) }
        await fulfillment(of: [submitting], timeout: 2)
        do { _ = try await manager.respond(authSession: session, action: .approve(number: "42")); XCTFail("Concurrent replay") }
        catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isInvalidChallenge == true) }
        first.cancel()
        await gate.release()
        do { _ = try await first.value; XCTFail("Cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        do { _ = try await manager.handlePushNotification(payload: Self.authPush(guid)); XCTFail("Consumed after cancellation") }
        catch { XCTAssertTrue((error as? MSALNativeAuthMFAError)?.isInvalidChallenge == true) }
    }

    func testDeletionIsAvailableWithoutAnEnablementFlag() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let acquiring = expectation(description: "Host provides the deletion token")
        let deleting = expectation(description: "Graph deletion sent")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            deleting.fulfill()
            return Data()
        }, storage: storage)
        try await manager.deleteAuthMethod(registrationId: "registration")
        { _ in
            acquiring.fulfill()
            return try Self.deletionToken()
        }
        await fulfillment(of: [acquiring, deleting], timeout: 2)
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testDeletionUsesGraphAndRemovesOnlySelectedRegistration() async throws
    {
        let storage = MfaTestStorage()
        var state = Self.deletionState()
        var other = state.accounts[0]
        other.id = "other"
        state.accounts.append(other)
        state.completedSessionIds.insert("completed")
        try storage.save(state)
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.absoluteString,
                           "https://graph.microsoft.com/v1.0/users/\(Self.deletionObject)/authentication/microsoftAuthenticatorMethods/registration")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-test-token")
            XCTAssertNil(request.httpBody)
            XCTAssertNil(request.value(forHTTPHeaderField: "SOAPAction"))
            XCTAssertEqual(try storage.load().accounts.count, 2, "Cleanup must wait for Graph")
            return Data()
        }, storage: storage)
        try await manager.deleteAuthMethod(registrationId: "registration") { context in
            XCTAssertEqual(context.loginHint, "fixture@example.test")
            XCTAssertEqual(context.tenantId, Self.deletionTenant)
            XCTAssertEqual(context.objectId, Self.deletionObject)
            XCTAssertEqual(context.authorityURL.absoluteString, "https://login.microsoftonline.com/" + Self.deletionTenant)
            XCTAssertEqual(context.scopes, ["https://graph.microsoft.com/UserAuthenticationMethod.ReadWrite"])
            XCTAssertEqual(context.claimsRequestJSON, #"{"access_token":{"amr":{"essential":true,"values":["ngcmfa"]}}}"#)
            XCTAssertTrue(context.allowsInteraction)
            return try Self.deletionToken()
        }
        let restored = try await manager.registeredAuthMethods()
        XCTAssertEqual(restored.map(\.registrationId), ["other"])
        XCTAssertEqual(try storage.load().accounts.map(\.id), ["other"])
        XCTAssertEqual(try storage.load().completedSessionIds, ["completed"])
        XCTAssertEqual(try storage.load().currentToken, "sb-apns2-01")
    }

    func testSharedProviderCanServeAnotherFeatureAndMFADeletion() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            return Data()
        }, storage: storage)
        let credentialRequest = MSALTokenProviderParameters(
            authorityURL: try XCTUnwrap(URL(string: "https://login.microsoftonline.com/" + Self.deletionTenant)),
            scopes: ["api://fixture/credential.manage"],
            claimsRequestJSON: #"{"access_token":{"acrs":{"essential":true,"values":["urn:user:registersecurityinfo"]}}}"#,
            tenantId: Self.deletionTenant, objectId: Self.deletionObject, allowsInteraction: false
        )
        let provider = MfaTestTokenProvider { request in
            if request.scopes == credentialRequest.scopes
            {
                XCTAssertEqual(request.claimsRequestJSON, credentialRequest.claimsRequestJSON)
                XCTAssertFalse(request.allowsInteraction)
            }
            else
            {
                XCTAssertEqual(request.scopes, ["https://graph.microsoft.com/UserAuthenticationMethod.ReadWrite"])
                XCTAssertEqual(request.claimsRequestJSON, #"{"access_token":{"amr":{"essential":true,"values":["ngcmfa"]}}}"#)
                XCTAssertTrue(request.allowsInteraction)
            }
            let fixture = try Self.deletionToken()
            return MSALTokenProviderResult(
                accessToken: fixture.accessToken, expiresOn: fixture.expiresOn, scopes: request.scopes,
                tenantId: fixture.tenantId, objectId: fixture.objectId,
                authorityURL: fixture.authorityURL, authenticationScheme: fixture.authenticationScheme
            )
        }
        let token = try await provider.getAccessToken(parameters: credentialRequest)
        XCTAssertEqual(token.scopes, credentialRequest.scopes)
        try await manager.deleteAuthMethod(registrationId: "registration", tokenProvider: provider)
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testDeletionRejectsMismatchedIdentityAndInvalidTokensBeforeHTTP() async throws
    {
        for scenario in ["tenant", "object", "authority", "expired", "missingExpiry", "empty", "header", "scope", "scheme"]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.deletionState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Invalid token must not be sent")
                return Data()
            }, storage: storage)
            do
            {
                try await manager.deleteAuthMethod(registrationId: "registration") { _ in
                    return try Self.deletionToken(scenario: scenario)
                }
                XCTFail("Expected rejection for \(scenario)")
            }
            catch
            {
                let expected: Failure = ["tenant", "object", "authority"].contains(scenario)
                    ? .deletionAccountMismatch : .invalidDeletionToken
                assertFailure(error, expected)
            }
            XCTAssertEqual(try storage.load().accounts.count, 1)
        }
    }

    func testDeletionPreservesLocalStateOnProviderOrHTTPFailure() async throws
    {
        for providerFails in [true, false]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.deletionState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTAssertFalse(providerFails)
                throw Failure.httpFailure(statusCode: 403)
            }, storage: storage)
            do
            {
                try await manager.deleteAuthMethod(registrationId: "registration") { _ in
                    if providerFails { throw CancellationError() }
                    return try Self.deletionToken()
                }
                XCTFail("Failed deletion must throw")
            }
            catch
            {
                if providerFails { XCTAssertTrue(error is CancellationError) }
                else { assertFailure(error, .httpFailure(statusCode: 403)) }
            }
            XCTAssertEqual(try storage.load().accounts.count, 1)
        }
    }

    func testDefiniteDeletionRejectionRestoresDecisionsIncludingAfterRestart() async throws
    {
        for status in [401, 403]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.deletionState())
            let transport = MfaTestTransport { request in
                if request.httpMethod == "DELETE" { throw Failure.httpFailure(statusCode: status) }
                if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthentication"
                {
                    let context = try XML.parse(XCTUnwrap(request.httpBody)).child("request")
                        .child("phoneAppAuthenticationRequest").child("phoneAppContext")
                    return Self.deletionAuthentication(guid: try context.value("guid"))
                }
                return Self.decisionResponse(approve: false, deletionIdentity: true)
            }
            let manager = MSALNativeAuthMFAManager(transport: transport, storage: storage)
            let sessions = try await manager.handlePushNotification(payload: Self.authPush(UUID().uuidString))
            let session = try XCTUnwrap(sessions.first)
            do
            {
                try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
                XCTFail("Expected definite rejection")
            }
            catch { assertFailure(error, .httpFailure(statusCode: status)) }
            XCTAssertTrue(try storage.load().unresolvedDeletions.isEmpty)
            _ = try await manager.respond(authSession: session, action: .deny)
            let restarted = MSALNativeAuthMFAManager(transport: transport, storage: storage)
            let fresh = try await restarted.handlePushNotification(payload: Self.authPush(UUID().uuidString))
            _ = try await restarted.respond(authSession: XCTUnwrap(fresh.first), action: .deny)
            XCTAssertEqual(try storage.load().accounts.count, 1)
        }
    }

    func testRejectedRetryCannotClearEarlierAmbiguousDeletion() async throws
    {
        for failure in [Failure.transportFailure, .httpFailure(statusCode: 500)]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.deletionState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                if request.httpMethod == "DELETE" { throw failure }
                return Self.deletionAuthentication(guid: try XML.parse(XCTUnwrap(request.httpBody))
                    .child("request").child("phoneAppAuthenticationRequest").child("phoneAppContext").value("guid"))
            }, storage: storage)
            let sessions = try await manager.handlePushNotification(payload: Self.authPush(UUID().uuidString))
            let session = try XCTUnwrap(sessions.first)
            do
            {
                try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
                XCTFail("Expected ambiguous failure")
            }
            catch { assertFailure(error, failure) }
            do { _ = try await manager.respond(authSession: session, action: .deny); XCTFail("Uncertain target must remain blocked") }
            catch { assertFailure(error, .outcomeUnknown) }
            let restarted = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                throw Failure.httpFailure(statusCode: 403)
            }, storage: storage)
            do
            {
                try await restarted.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
                XCTFail("Expected rejected retry")
            }
            catch { assertFailure(error, .httpFailure(statusCode: 403)) }
            XCTAssertEqual(try storage.load().unresolvedDeletions, ["registration"])
        }
    }

    func testDefiniteDeletionRejectionWithCleanupSaveFailureKeepsUncertainty() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
            storage.failNextSave()
            throw Failure.httpFailure(statusCode: 403)
        }, storage: storage)
        do
        {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
            XCTFail("Failed local cleanup must be reported")
        }
        catch { assertFailure(error, .storageFailure(status: -50)) }
        XCTAssertEqual(try storage.load().unresolvedDeletions, ["registration"])
    }

    func testDeletionRejectsUnsupportedCloudUnknownAccountAndUnsafeMethodID() async throws
    {
        for scenario in ["cloud", "unknown", "path"]
        {
            let storage = MfaTestStorage()
            var state = Self.deletionState()
            if scenario == "cloud" { state.accounts[0].endpoint = try XCTUnwrap(URL(string: "https://activation.microsoft.us/pad")) }
            if scenario == "path" { state.accounts[0].id = "registration?other=method" }
            try storage.save(state)
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Invalid request must not contact Graph")
                return Data()
            }, storage: storage)
            do
            {
                try await manager.deleteAuthMethod(registrationId: scenario == "unknown" ? "missing" : state.accounts[0].id) { _ in
                    XCTFail("Invalid request must not acquire a token")
                    return try Self.deletionToken()
                }
                XCTFail("Expected rejection")
            }
            catch
            {
                let expected: Failure = scenario == "cloud" ? .unsupportedDeletionCloud
                    : (scenario == "unknown" ? .registrationNotFound : .untrustedEndpoint)
                assertFailure(error, expected)
            }
            XCTAssertEqual(try storage.load().accounts.count, 1)
        }
    }

    func testDeletionSerializesConcurrentDeletionAndChecksCancellationAfterTokenAcquisition() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let gate = MfaRequestGate()
        let acquiring = expectation(description: "Acquiring Graph token")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
            XCTFail("Cancelled operation must not send deletion")
            return Data()
        }, storage: storage)
        let deletion = Task {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in
                acquiring.fulfill()
                await gate.wait()
                return try Self.deletionToken()
            }
        }
        await fulfillment(of: [acquiring], timeout: 2)
        do
        {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in
                XCTFail("Concurrent deletion must not acquire another token")
                return try Self.deletionToken()
            }
            XCTFail("Expected busy")
        }
        catch { assertFailure(error, .operationInProgress) }
        deletion.cancel()
        await gate.release()
        do { try await deletion.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try storage.load().accounts.count, 1)
    }

    func testDeletionInvalidatesSessionsAndCanRetryLocalSaveFailure() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let guid = UUID().uuidString
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.httpMethod == "DELETE"
            {
                storage.failNextSave()
                return Data()
            }
            return Self.deletionAuthentication(guid: guid)
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "https://activation.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc"])
        let session = try XCTUnwrap(sessions.first)
        do
        {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
            XCTFail("Local save failure must not report success")
        }
        catch { assertFailure(error, .storageFailure(status: -50)) }
        XCTAssertEqual(try storage.load().accounts.count, 1)
        do { _ = try await manager.respond(authSession: session, action: .deny); XCTFail("Deleted registration must not authorize old sessions") }
        catch { assertFailure(error, .invalidSession) }
        try await manager.deleteAuthMethod(registrationId: "registration") { _ in
            XCTFail("Confirmed remote deletion should retry local cleanup without signing in again")
            return try Self.deletionToken()
        }
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testAuthenticationSuspendedAcrossDeletionCannotRestoreTheAccount() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let guid = UUID().uuidString
        let gate = MfaRequestGate()
        let fetching = expectation(description: "Authentication fetch suspended")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.httpMethod == "DELETE" { return Data() }
            fetching.fulfill()
            await gate.wait()
            return Self.deletionAuthentication(guid: guid)
        }, storage: storage)
        let fetch = Task {
            try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "https://activation.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc"])
        }
        await fulfillment(of: [fetching], timeout: 2)
        try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
        await gate.release()
        do { _ = try await fetch.value; XCTFail("Late fetch must not restore a deleted account") }
        catch { assertFailure(error, .unknownAccount) }
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testDeletionBlocksDecisionAndEnrollmentWhilePreservingLatestPushToken() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let guid = UUID().uuidString
        let gate = MfaRequestGate()
        let deleting = expectation(description: "Deletion in flight")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.httpMethod == "DELETE"
            {
                deleting.fulfill()
                await gate.wait()
                return Data()
            }
            return Self.deletionAuthentication(guid: guid)
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "https://activation.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc"])
        let session = try XCTUnwrap(sessions.first)
        let deletion = Task { try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() } }
        await fulfillment(of: [deleting], timeout: 2)
        do { _ = try await manager.respond(authSession: session, action: .deny); XCTFail("Decision must not overlap Graph deletion") }
        catch { assertFailure(error, .operationInProgress) }
        do
        {
            _ = try await manager.registerAuthMethod(registrationParameters: MSALNativeAuthMFARegistrationParameters(
                activationCode: "synthetic", activationURL: Self.activationURL
            ))
            XCTFail("Enrollment must not overlap deletion")
        }
        catch { assertFailure(error, .operationInProgress) }
        do
        {
            try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox)
            XCTFail("Token reconciliation must wait")
        }
        catch { assertFailure(error, .operationInProgress) }
        await gate.release()
        try await deletion.value
        XCTAssertTrue(try storage.load().accounts.isEmpty)
        XCTAssertEqual(try storage.load().currentToken, "sb-apns2-02")
    }

    func testDeletionWaitsUntilAnAlreadySubmittedDecisionFinishes() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let guid = UUID().uuidString
        let gate = MfaRequestGate()
        let responding = expectation(description: "Decision in flight")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthenticationResult"
            {
                responding.fulfill()
                await gate.wait()
                return Self.decisionResponse(approve: false, deletionIdentity: true)
            }
            XCTAssertNotEqual(request.httpMethod, "DELETE")
            return Self.deletionAuthentication(guid: guid)
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "https://activation.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc"])
        let session = try XCTUnwrap(sessions.first)
        let response = Task { try await manager.respond(authSession: session, action: .deny) }
        await fulfillment(of: [responding], timeout: 2)
        do
        {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
            XCTFail("Active decision must prevent remote deletion")
        }
        catch { assertFailure(error, .operationInProgress) }
        await gate.release()
        _ = try await response.value
        XCTAssertEqual(try storage.load().accounts.count, 1)
    }

    func testConfirmedDeletionPersistsEvenWhenCancelledDuringHTTP() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.deletionState())
        let gate = MfaRequestGate()
        let deleting = expectation(description: "Graph request in flight")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
            deleting.fulfill()
            await gate.wait()
            return Data()
        }, storage: storage)
        let task = Task { try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() } }
        await fulfillment(of: [deleting], timeout: 2)
        task.cancel()
        await gate.release()
        try await task.value
        XCTAssertTrue(try storage.load().accounts.isEmpty)
    }

    func testGraphSuccessStatusAndEndpointPolicyDoNotRelaxSOAP() throws
    {
        for status in [204, 404]
        {
            XCTAssertTrue(try MSALNativeAuthMFATransport.acceptsEmptyDeletionResponse(statusCode: status, policy: .graphDeletion))
            XCTAssertThrowsError(try MSALNativeAuthMFATransport.acceptsEmptyDeletionResponse(statusCode: status, policy: .phoneApp))
            XCTAssertThrowsError(try MSALNativeAuthMFATransport.acceptsEmptyDeletionResponse(statusCode: status, policy: .activation))
        }
        for status in [200, 202, 301, 401, 403, 429, 500]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFATransport.acceptsEmptyDeletionResponse(statusCode: status, policy: .graphDeletion))
        }
        XCTAssertFalse(try MSALNativeAuthMFATransport.acceptsEmptyDeletionResponse(statusCode: 200, policy: .phoneApp))
        let path = "/v1.0/users/\(Self.deletionObject)/authentication/microsoftAuthenticatorMethods/registration"
        try MSALNativeAuthMFAEndpoint.Policy.graphDeletion.validate(XCTUnwrap(URL(string: "https://graph.microsoft.com" + path)))
        for url in [
            "https://other.microsoft.com" + path, "http://graph.microsoft.com" + path,
            "https://graph.microsoft.com:443" + path, "https://user@graph.microsoft.com" + path,
            "https://graph.microsoft.com" + path + "?other=value", "https://graph.microsoft.com" + path + "#fragment",
            "https://graph.microsoft.com" + path + "/extra", "https://graph.microsoft.com" + path + "%2Fextra"
        ]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.Policy.graphDeletion.validate(XCTUnwrap(URL(string: url))))
        }
    }

    private static let deletionTenant = "11111111-1111-1111-1111-111111111111"
    private static let deletionObject = "22222222-2222-2222-2222-222222222222"
    private static let macURL = "https://activation.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc?ts=true&su=TestRing"
    private static let activationURL = "https://activation.auth.microsoft.com/eeid/mac/MobileAppCommunicator.svc/synthetic/TestRing/PfPaWs.asmx?ts=true&su=TestRing"

    private static func classifiers(_ error: MSALNativeAuthMFAError) -> [Bool]
    {
        [error.isPushTokenMissing, error.isRegistrationNotFound, error.isInvalidChallenge,
         error.isInvalidCode, error.isUserSignedInWithMismatchedAccount, error.isGeneralError]
    }

    private static func parameters() -> MSALNativeAuthMFARegistrationParameters
    {
        MSALNativeAuthMFARegistrationParameters(activationCode: "synthetic", activationURL: activationURL)
    }

    private static func validationPush() -> [String: String]
    {
        ["type": "validate", "guid": UUID().uuidString, "url": macURL, "validationScenario": "QrRegistration"]
    }

    private static func authPush(_ guid: String) -> [String: String]
    {
        ["type": "auth", "guid": guid, "url": macURL]
    }

    private static func activationSuccess() -> Data
    {
        soap("ActivateNew", fields: """
            <error><Code>0</Code></error><activationInfo><Username>fixture@example.test</Username>
            <TenantId>tenant</TenantId><AzureObjectId>object</AzureObjectId>
            <OathTokenSecretKey>GEZDGNBVGY3TQOJQ</OathTokenSecretKey><ConfirmationCode>synthetic-confirmation</ConfirmationCode>
            <ReplicationScope>NA</ReplicationScope><RoutingHint>route</RoutingHint><CountryCode>ZZ</CountryCode></activationInfo>
            """)
    }

    private static func validationSuccess(username: String? = "fixture@example.test") -> Data
    {
        phone("phoneAppValidateDeviceTokenResponse", fields: """
            <groupKey>group</groupKey><dosPreventer>proof</dosPreventer><accountName>Fixture account</accountName>
            \(username.map { "<username>\($0)</username>" } ?? "")<accountValidationResults/>
            """)
    }

    private static func decisionResponse(approve: Bool, deletionIdentity: Bool = false) -> Data
    {
        let result = approve ? "<validationResult>6</validationResult>" : "<authenticationResultResult>1</authenticationResultResult>"
        return phone(approve ? "phoneAppPinValidationResponse" : "phoneAppAuthenticationResultResponse", fields: """
            \(result)<azureObjectId>\(deletionIdentity ? deletionObject : "object")</azureObjectId>
            <tenantId>\(deletionIdentity ? deletionTenant : "tenant")</tenantId><username>fixture@example.test</username>
            """)
    }

    private static func deletionState() -> MSALNativeAuthMFAStoredState
    {
        var state = registeredState()
        state.accounts[0].tenantId = deletionTenant
        state.accounts[0].objectId = deletionObject
        return state
    }

    private static func deletionToken(scenario: String? = nil) throws -> MSALTokenProviderResult
    {
        let token = scenario == "empty" ? "" : (scenario == "header" ? "synthetic\r\ninjection" : "synthetic-test-token")
        let expiry: Date? = scenario == "missingExpiry" ? nil : (scenario == "expired" ? .distantPast : .distantFuture)
        return MSALTokenProviderResult(
            accessToken: token, expiresOn: expiry,
            scopes: scenario == "scope" ? ["User.Read"] : ["UserAuthenticationMethod.ReadWrite"],
            tenantId: scenario == "tenant" ? UUID().uuidString : deletionTenant,
            objectId: scenario == "object" ? UUID().uuidString : deletionObject,
            authorityURL: try XCTUnwrap(URL(string: scenario == "authority"
                ? "https://login.microsoftonline.us/common" : "https://login.microsoftonline.com/" + deletionTenant)),
            authenticationScheme: scenario == "scheme" ? "PoP" : "Bearer"
        )
    }

    private static func deletionAuthentication(guid: String) -> Data
    {
        let response = String(decoding: authentication(guid: guid, appLock: "no"), as: UTF8.self)
            .replacingOccurrences(of: "<tenantId>tenant</tenantId>", with: "<tenantId>\(deletionTenant)</tenantId>")
            .replacingOccurrences(of: "<azureObjectId>object</azureObjectId>", with: "<azureObjectId>\(deletionObject)</azureObjectId>")
        return Data(response.utf8)
    }

    private static func registeredState() -> MSALNativeAuthMFAStoredState
    {
        MSALNativeAuthMFAStoredState(accounts: [
            MSALNativeAuthMFAAccountRecord(
                id: "registration", name: "Fixture account", username: "fixture@example.test",
                secret: "GEZDGNBVGY3TQOJQ", groupKey: "group", tenantId: "tenant", objectId: "object",
                endpoint: URL(string: macURL)!,
                replicationScope: "", routingHint: "", countryCode: "",
                activatedToken: "sb-apns2-01", dosPreventer: "proof", bundleId: "com.microsoft.azureauthenticator"
            )
        ], currentToken: "sb-apns2-01")
    }

    private static func credentialPolicy(phone: [UInt8], companion: [UInt8]? = nil, platform: [UInt8]? = nil) -> String
    {
        var bytes: [UInt8] = [0x12, UInt8(phone.count)] + phone
        if let companion { bytes += [0x22, UInt8(companion.count)] + companion }
        if let platform { bytes += [0x2a, UInt8(platform.count)] + platform }
        return Data(bytes).base64EncodedString()
    }

    private static func authenticationRespondingTo(_ request: URLRequest, guid: String) throws -> Data
    {
        let context = try XML.parse(XCTUnwrap(request.httpBody)).child("request")
            .child("phoneAppAuthenticationRequest").child("phoneAppContext")
        let requested = try context.value("needDosPreventer") == "yes"
        return authentication(guid: guid, appLock: "no", dosPreventer: requested ? "refreshed-proof" : "")
    }

    private static func authentication(
        guid: String, appLock: String, credentialPolicy: String = "EgIoAg==", dosPreventer: String = "proof"
    ) -> Data
    {
        phone("phoneAppAuthenticationResponse", fields: """
            <guid>\(guid)</guid><oathCounter>123</oathCounter><dosPreventer>\(dosPreventer)</dosPreventer>\
            <phoneAppInfo><phoneAppDetailId>registration</phoneAppDetailId>\
            <tenantId>tenant</tenantId><azureObjectId>object</azureObjectId><sasSessionId>session</sasSessionId>\
            <isAppLockRequired>\(appLock)</isAppLockRequired><userCredentialPolicy>\(credentialPolicy)</userCredentialPolicy></phoneAppInfo>
            """)
    }

    private static func soap(_ operation: String, fields: String, result: String = "true") -> Data
    {
        Data("<Envelope><Body><\(operation)Response><\(operation)Result>\(result)</\(operation)Result>\(fields)</\(operation)Response></Body></Envelope>".utf8)
    }

    private static func phone(_ operation: String, fields: String) -> Data
    {
        Data("<pfpMessage version=\"1.6\"><response><status disposition=\"success\"><error-id>0</error-id></status><\(operation)>\(fields)</\(operation)></response></pfpMessage>".utf8)
    }
}

private actor MfaCorrelationCapture
{
    private(set) var values: [UUID] = []

    func record(_ value: UUID)
    {
        values.append(value)
    }
}

private struct MfaUnavailableStorage: MSALNativeAuthMFAStoring
{
    func load() throws -> MSALNativeAuthMFAStoredState
    {
        throw MSALNativeAuthMFAFailure.storageFailure(status: -50)
    }

    func save(_ state: MSALNativeAuthMFAStoredState) throws
    {
        throw MSALNativeAuthMFAFailure.storageFailure(status: -50)
    }
}

private struct MfaTestTransport: MSALNativeAuthMFATransporting
{
    let handler: @Sendable (URLRequest) async throws -> Data

    init(_ handler: @escaping @Sendable (URLRequest) async throws -> Data)
    {
        self.handler = handler
    }

    func send(_ request: URLRequest, endpointPolicy: MSALNativeAuthMFAEndpoint.Policy) async throws -> Data
    {
        try endpointPolicy.validate(XCTUnwrap(request.url))
        return try await handler(request)
    }
}

private actor MfaRequestGate
{
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async
    {
        guard !released else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release()
    {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

// All mutable state is protected by lock, including copies crossing actor boundaries.
private final class MfaTestStorage: MSALNativeAuthMFAStoring, @unchecked Sendable
{
    private let lock = NSLock()
    private var state = MSALNativeAuthMFAStoredState()
    private var shouldFailSave = false

    func failNextSave()
    {
        lock.lock()
        defer { lock.unlock() }
        shouldFailSave = true
    }

    func load() throws -> MSALNativeAuthMFAStoredState
    {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    func save(_ state: MSALNativeAuthMFAStoredState) throws
    {
        lock.lock()
        defer { lock.unlock() }
        if shouldFailSave
        {
            shouldFailSave = false
            throw MSALNativeAuthMFAFailure.storageFailure(status: -50)
        }
        self.state = state
    }
}
