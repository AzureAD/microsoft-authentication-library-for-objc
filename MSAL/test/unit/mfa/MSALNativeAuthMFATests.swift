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
    private typealias Failure = MSALNativeAuthMFAServiceError

    func testServiceReadsRegistrationsWithoutOptIn() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let service = MSALNativeAuthMFAService(transport: MfaTestTransport { _ in
            XCTFail("Reading registrations must not contact the service")
            throw Failure.transportFailure
        }, storage: storage, deviceNameProvider: {
            XCTFail("Reading registrations must not derive enrollment metadata")
            return nil
        })

        let records = try await service.registrations()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.registrationId, "registration")
        XCTAssertEqual(records.first?.accountName, "Fixture account")
        XCTAssertEqual(records.first?.username, "fixture@example.test")
    }

    func testQRAndManualActivationNormalizeToSameInput() throws
    {
        let url = "https://activation.auth.microsoft.com/enrollment"
        var qr = URLComponents(string: "phonefactor://activate_account")!
        qr.queryItems = [URLQueryItem(name: "code", value: "synthetic"), URLQueryItem(name: "url", value: url)]
        let encoded = try XCTUnwrap(qr.string)
        let scanned = try MSALNativeAuthMFARegistrationParameters(qrCode: encoded).validatedActivation()
        let manual = try MSALNativeAuthMFARegistrationParameters(activationCode: "synthetic", activationURL: url).validatedActivation()
        XCTAssertEqual(scanned, manual)
        XCTAssertEqual(scanned.endpoint.lastPathComponent, "PfPaWs.asmx")
    }

    func testHTTPSQRCodeNormalizesToManualAndLegacyActivation() throws
    {
        let url = "https://mobileappcommunicator.auth.microsoft.com/activatev2/fixture/fixture"
        let query = "code=000000001&url=https%3a%2f%2fmobileappcommunicator.auth.microsoft.com%2factivatev2%2ffixture%2ffixture"
        let scanned = try MSALNativeAuthMFARegistrationParameters(
            qrCode: "https://login.microsoftonline.com/authenticatorApp/activateAccount?accountType=mfa&source=qrCode&\(query)"
        ).validatedActivation()
        let legacy = try MSALNativeAuthMFAActivation(qrCode: "phonefactor://activate_account?\(query)")
        let manual = try MSALNativeAuthMFAActivation(code: "000000001", url: url)
        XCTAssertEqual(scanned, manual)
        XCTAssertEqual(scanned, legacy)
        XCTAssertEqual(scanned.code, "000000001")
        XCTAssertEqual(scanned.endpoint.absoluteString, url + "/PfPaWs.asmx")
    }

    func testHTTPSQRCodeRejectsWrongOriginRouteAccountTypeAndAmbiguousFields()
    {
        let query = "code=synthetic&url=https%3A%2F%2Factivation.auth.microsoft.com"
        for prefix in [
            "http://login.microsoftonline.com/authenticatorApp/activateAccount?accountType=mfa",
            "https://login.microsoftonline.com.example.test/authenticatorApp/activateAccount?accountType=mfa",
            "https://login.microsoftonline.com:444/authenticatorApp/activateAccount?accountType=mfa",
            "https://login.microsoftonline.com/other?accountType=mfa",
            "https://login.microsoftonline.com/authenticatorApp/activateAccount?accountType=msa",
            "https://login.microsoftonline.com/authenticatorApp/activateAccount?source=qrCode",
            "https://login.microsoftonline.com/authenticatorApp/activateAccount?accountType=mfa&accountType=msa"
        ]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFAActivation(qrCode: "\(prefix)&\(query)"))
        }
        let valid = "https://login.microsoftonline.com/authenticatorApp/activateAccount?accountType=mfa&\(query)"
        for suffix in ["&code=duplicate", "&url=https%3A%2F%2Fexample.test", "#fragment"]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFAActivation(qrCode: valid + suffix))
        }
        XCTAssertThrowsError(try MSALNativeAuthMFAActivation(qrCode:
            "https://login.microsoftonline.com/authenticatorApp/activateAccount?accountType=mfa&code=synthetic&url=https%3A%2F%2Fexample.test"
        ))
    }

    func testRejectsTOTPAndAmbiguousOrUnsafeActivationInput()
    {
        for qr in [
            "otpauth://totp/Example?secret=synthetic",
            "phonefactor://activate_account?code=a&code=b&url=https%3A%2F%2Fexample.test",
            "phonefactor://activate_account?code=a"
        ]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFAActivation(qrCode: qr))
        }
        for url in [
            "http://activation.auth.microsoft.com", "https://microsoft.com.example.test",
            "https://user:password@activation.auth.microsoft.com", "https://activation.auth.microsoft.com:444",
            "https://activation.auth.microsoft.com?redirect=https://example.test"
        ]
        {
            XCTAssertThrowsError(try MSALNativeAuthMFAActivation(code: "synthetic", url: url))
        }
    }

    func testNotificationEndpointPreservesMACRouteAndQuery() throws
    {
        let route = "mobileappcommunicator.auth.microsoft.com/mac/MobileAppCommunicator.svc/?su=SYNTHETIC%2DROUTE&ignored=fixture"
        let expected = "https://" + route
        for input in [route, expected]
        {
            let endpoint = try MSALNativeAuthMFAEndpoint.notification(input)
            XCTAssertEqual(endpoint.absoluteString, expected)
            try MSALNativeAuthMFAEndpoint.Policy.phoneApp.validate(endpoint)
            XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.Policy.activation.validate(endpoint))
            XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.validate(endpoint.absoluteString))
            XCTAssertThrowsError(try MSALNativeAuthMFAActivation(code: "synthetic", url: endpoint.absoluteString))
        }
        for host in ["activation.auth.microsoft.com", "fixture.phonefactor.net"]
        {
            XCTAssertEqual(try MSALNativeAuthMFAEndpoint.notification(host).absoluteString, "https://\(host)/pad")
        }
        let queryFree = "https://mobileappcommunicator.auth.microsoft.com/mac/MobileAppCommunicator.svc"
        XCTAssertEqual(try MSALNativeAuthMFAEndpoint.phoneApp(queryFree).absoluteString, queryFree)
        let explicitPort = "https://mobileappcommunicator.auth.microsoft.com:443/mac/MobileAppCommunicator.svc/?su=fixture"
        XCTAssertEqual(try MSALNativeAuthMFAEndpoint.notification(explicitPort).absoluteString, explicitPort)
    }

    func testNotificationEndpointRejectsUntrustedOrMalformedRoutes()
    {
        let host = "mobileappcommunicator.auth.microsoft.com"
        let path = "/mac/MobileAppCommunicator.svc/"
        let invalid = [
            "http://\(host)\(path)", "https://\(host):444\(path)", "https://user@\(host)\(path)",
            "https://\(host)\(path)#fragment", "\(host).example.test\(path)", "example.test\(path)",
            "\(host)/other?su=fixture", "\(host)/pad?su=fixture",
            "fixture.phonefactor.net\(path)?su=fixture", "\(host)/mac/../MobileAppCommunicator.svc/",
            "\(host)/%6dac/MobileAppCommunicator.svc/", "//\(host)\(path)", "\(host)\\\(path)",
            "\(host)\(path)?redirect=fixture", "\(host)\(path)?su=one&su=two",
            "\(host)\(path)?su=", "\(host)\(path)?su", "\(host)\(path)?ignored=",
            "\(host)\(path)?su=%ZZ", "\(host)\(path)?su=fixture%0A", "\(host)\(path)?su=has space",
            "\(host)\(path)?su=one&%73u=two", "\(host)\(path)?su=fixture&ignored=one&ignored=two",
            "\(host)\(path)?su=" + String(repeating: "a", count: 4096)
        ]
        for value in invalid
        {
            XCTAssertThrowsError(try MSALNativeAuthMFAEndpoint.notification(value))
        }
    }

    func testRequestBuilderRetainsNotificationPolicyWithoutRelaxingActivation() async throws
    {
        let endpoint = try MSALNativeAuthMFAEndpoint.notification(
            "mobileappcommunicator.auth.microsoft.com/mac/MobileAppCommunicator.svc/?su=SYNTHETIC%2DROUTE&ignored=fixture"
        )
        let sent = expectation(description: "Only the validation request reaches transport")
        let client = MSALNativeAuthMFAServiceClient(transport: MfaTestTransport { request in
            XCTAssertEqual(request.url?.absoluteString, endpoint.absoluteString)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppValidateDeviceToken")
            sent.fulfill()
            return Self.phone("phoneAppValidateDeviceTokenResponse", fields: "")
        })
        _ = try await client.phoneApp(operation: "PhoneAppValidateDeviceToken", endpoint: endpoint, fields: [])
        do
        {
            _ = try await client.activation(operation: "ActivateNew", endpoint: endpoint, fields: [])
            XCTFail("Activation must not accept a notification routing query")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .untrustedEndpoint)
        }
        await fulfillment(of: [sent], timeout: 2)
    }

    func testTransportRejectsInvalidEndpointBeforeNetwork() async throws
    {
        let transport = MSALNativeAuthMFATransport()
        let cases: [(String, MSALNativeAuthMFAEndpoint.Policy)] = [
            ("https://example.test/mac/MobileAppCommunicator.svc/?su=fixture", .phoneApp),
            ("https://activation.auth.microsoft.com/other?su=fixture", .phoneApp),
            ("https://activation.auth.microsoft.com/mac/MobileAppCommunicator.svc/?su=fixture", .activation)
        ]
        for (url, policy) in cases
        {
            do
            {
                _ = try await transport.send(URLRequest(url: XCTUnwrap(URL(string: url))), endpointPolicy: policy)
                XCTFail("Endpoint must be rejected before a network call")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .untrustedEndpoint)
            }
        }
    }

    func testXMLRoundTripEscapesTextAndRejectsDuplicateFieldsAndEntities() throws
    {
        let node = XML(name: "response", children: [XML(name: "value", text: "<&\"'>")])
        XCTAssertEqual(try XML.parse(Data(node.encoded.utf8)).value("value"), "<&\"'>")
        let duplicate = try XML.parse(Data("<response><value>a</value><value>b</value></response>".utf8))
        XCTAssertThrowsError(try duplicate.value("value"))
        XCTAssertThrowsError(try XML.parse(Data("<!DOCTYPE a [<!ENTITY x SYSTEM 'file:///tmp/test'>]><a>&x;</a>".utf8)))
        XCTAssertThrowsError(try XML.parse(Data("<a><b></a>".utf8)))
        XCTAssertThrowsError(try XML.parse(Data(repeating: 32, count: 1_048_577)))
    }

    func testTokenEncodingUsesExplicitEnvironmentAndPreservesLeadingZeros() throws
    {
        let data = Data([0, 0xAB, 0xFF])
        XCTAssertEqual(try MSALNativeAuthMFAProof.token(data, environment: .sandbox), "sb-apns2-00abff")
        XCTAssertEqual(try MSALNativeAuthMFAProof.token(data, environment: .production), "apns2-00abff")
        XCTAssertThrowsError(try MSALNativeAuthMFAProof.token(Data(), environment: .sandbox))
    }

    func testValidationProofUsesFullHMACNotTruncatedOTP() throws
    {
        // RFC 4226 test key/counter; service validation uses the complete SHA-1 digest.
        XCTAssertEqual(
            try MSALNativeAuthMFAProof.validation(secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", counter: 0),
            "CC93CF18508D94934C64B65D8BA7667FB7CDE4B0"
        )
        XCTAssertThrowsError(try MSALNativeAuthMFAProof.validation(secret: "not a base32 key!", counter: 0))
    }

    func testNoAccountTokenUpdatePersistsWithoutNetworkAndRejectsEmptyReplacement() async throws
    {
        let storage = MfaTestStorage()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
            XCTFail("Updating the token without accounts must not contact the service")
            throw Failure.transportFailure
        }, storage: storage)
        try await manager.updatePushRegistration(deviceToken: Data([0, 1]), apnsEnvironment: .sandbox)
        do
        {
            try await manager.updatePushRegistration(deviceToken: Data(), apnsEnvironment: .production)
            XCTFail("Empty token must fail")
        }
        catch
        {
            XCTAssertEqual(error as? MSALNativeAuthMFAPushRegistrationError, .invalidDeviceToken)
        }
        XCTAssertEqual(try storage.load().currentToken, "sb-apns2-0001")
        let records = try await manager.registeredAuthMethods()
        XCTAssertTrue(records.isEmpty)
    }

    func testRegistrationWaitsForValidationAndPersistsOnlyConfirmedAccount() async throws
    {
        try await verifyRegistrationValidation(notificationURL: "activation.auth.microsoft.com")
    }

    func testRegistrationAcceptsSchemeLessMACValidationPayloadAndPersistsEndpoint() async throws
    {
        try await verifyRegistrationValidation(notificationURL:
            "mobileappcommunicator.auth.microsoft.com/mac/MobileAppCommunicator.svc/?su=SYNTHETIC%2DROUTE&ignored=fixture"
        )
    }

    func testRegistrationAcceptsEmptyValidationUsernameAndConfirmsActivationIdentity() async throws
    {
        try await verifyRegistrationValidation(
            notificationURL: "activation.auth.microsoft.com",
            validationUsernameXML: "<username/>"
        )
    }

    func testRegistrationAcceptsCaseInsensitiveValidationUsername() async throws
    {
        try await verifyRegistrationValidation(
            notificationURL: "activation.auth.microsoft.com",
            validationUsernameXML: "<username>FIXTURE@EXAMPLE.TEST</username>"
        )
    }

    func testRegistrationRejectsMismatchedValidationUsernameWithoutConfirmation() async throws
    {
        try await verifyRegistrationValidation(
            notificationURL: "activation.auth.microsoft.com",
            validationUsernameXML: "<username>different@example.test</username>",
            expectsInvalidResponse: true
        )
    }

    func testRegistrationRejectsMissingValidationUsernameWithoutConfirmation() async throws
    {
        try await verifyRegistrationValidation(
            notificationURL: "activation.auth.microsoft.com",
            validationUsernameXML: "",
            expectsInvalidResponse: true
        )
    }

    private func verifyRegistrationValidation(
        notificationURL: String,
        validationUsernameXML: String = "<username>fixture@example.test</username>",
        expectsInvalidResponse: Bool = false
    ) async throws
    {
        let started = expectation(description: "Activation started")
        let confirmed = XCTestExpectation(description: "Activation confirmed once")
        confirmed.assertForOverFulfill = true
        let storage = MfaTestStorage()
        let guid = UUID().uuidString
        let expectedEndpoint = try MSALNativeAuthMFAEndpoint.notification(notificationURL)
        let transport = MfaTestTransport { request in
            let body = try XCTUnwrap(request.httpBody)
            let xml = try XML.parse(body)
            if request.value(forHTTPHeaderField: "SOAPAction")?.hasSuffix("/ActivateNew") == true
            {
                let activation = try xml.child("Body").child("ActivateNew").child("activationParams")
                XCTAssertEqual(try activation.value("DeviceToken"), "sb-apns2-01")
                XCTAssertEqual(try activation.value("DeviceName"), "iOS")
                let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                XCTAssertEqual(try activation.value("Version"), appVersion ?? "0")
                XCTAssertEqual(request.value(forHTTPHeaderField: "AppVersion"), appVersion)
                started.fulfill()
                return Self.soap("ActivateNew", fields: """
                    <activationInfo><Username>fixture@example.test</Username><ConfirmationCode>confirmation</ConfirmationCode>\
                    <OathTokenSecretKey>GEZDGNBVGY3TQOJQ</OathTokenSecretKey><TenantId>tenant</TenantId>\
                    <AzureObjectId>object</AzureObjectId></activationInfo>
                    """)
            }
            if request.value(forHTTPHeaderField: "SOAPAction")?.hasSuffix("/ConfirmActivation") == true
            {
                XCTAssertFalse(expectsInvalidResponse, "Invalid validation identity must not reach confirmation")
                confirmed.fulfill()
                XCTAssertEqual(try xml.child("Body").child("ConfirmActivation").value("confirmationCode"), "confirmation")
                return Self.soap("ConfirmActivation", fields: "<phoneAppDetailId>registration</phoneAppDetailId>")
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppValidateDeviceToken")
            XCTAssertEqual(request.url?.absoluteString, expectedEndpoint.absoluteString)
            let validation = try xml.child("request").child("phoneAppValidateDeviceTokenRequest")
            XCTAssertEqual(try validation.value("validationResult"), "yes")
            let context = try validation.child("phoneAppContext")
            XCTAssertEqual(try context.value("guid"), guid)
            XCTAssertEqual(try context.value("deviceToken"), "sb-apns2-01")
            return Self.phone("phoneAppValidateDeviceTokenResponse", fields: """
                \(validationUsernameXML)<accountName>Fixture account</accountName>\
                <groupKey>group</groupKey><dosPreventer>proof</dosPreventer>
                """)
        }
        let manager = MSALNativeAuthMFAManager(transport: transport, storage: storage)
        try await manager.updatePushRegistration(deviceToken: Data([1]), apnsEnvironment: .sandbox)
        let registration = Task
        {
            try await manager.registerAuthMethod(registrationParameters:
                MSALNativeAuthMFARegistrationParameters(activationCode: "synthetic", activationURL: "https://activation.auth.microsoft.com"))
        }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(try storage.load().accounts.isEmpty)
        let sessions = try await manager.handlePushNotification(payload: [
            "type": "validate", "guid": guid, "url": notificationURL,
            "validationScenario": "QrRegistration", "tenantId": "synthetic-tenant",
            "routingHint": "synthetic-route", "source": "SAS", "countryCode": "ZZ", "replicationScope": "fixture"
        ])
        XCTAssertTrue(sessions.isEmpty)
        if expectsInvalidResponse
        {
            do
            {
                _ = try await registration.value
                XCTFail("Invalid validation identity must reject registration")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .invalidResponse)
            }
            XCTAssertTrue(try storage.load().accounts.isEmpty)
            XCTAssertEqual(try storage.load().pendingEnrollment?.confirming, false)
            return
        }
        let result = try await registration.value
        await fulfillment(of: [confirmed], timeout: 2)
        XCTAssertEqual(result.registrationId, "registration")
        XCTAssertEqual(result.accountName, "Fixture account")
        XCTAssertEqual(result.username, "fixture@example.test")
        XCTAssertEqual(try storage.load().accounts.first?.endpoint.absoluteString, expectedEndpoint.absoluteString)
        XCTAssertEqual(try storage.load().accounts.first?.username, "fixture@example.test")
        XCTAssertNil(try storage.load().pendingEnrollment)
        let restored = MSALNativeAuthMFAManager(transport: transport, storage: storage)
        let saved = try await restored.registeredAuthMethods()
        XCTAssertEqual(saved.map(\.registrationId), ["registration"])
        XCTAssertEqual(saved.map(\.username), ["fixture@example.test"])
    }

    func testDefaultHardwareIdentifierIsForwardedForBothRegistrationInputs() async throws
    {
        let hardwareType = try XCTUnwrap(MSIDDeviceId.deviceHardwareType())
        XCTAssertFalse(hardwareType.isEmpty)
        try await assertEnrollmentDeviceName(hardwareType)
    }

    func testDerivedDeviceNameIsEscapedAndForwardedForBothRegistrationInputs() async throws
    {
        let deviceName = "Synthetic <device> & \"label\""
        try await assertEnrollmentDeviceName(deviceName, provider: { deviceName })
    }

    func testUnavailableDeviceNameRejectsEnrollmentWithoutNetworkOrPendingState() async throws
    {
        let unavailableNames: [String?] = [nil, "", " \n "]
        for deviceName in unavailableNames
        {
            let storage = MfaTestStorage()
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Unavailable device metadata must fail before activation")
                throw Failure.transportFailure
            }, storage: storage, deviceNameProvider: { deviceName })
            try await manager.updatePushRegistration(deviceToken: Data([1]), apnsEnvironment: .sandbox)
            do
            {
                _ = try await manager.registerAuthMethod(registrationParameters:
                    MSALNativeAuthMFARegistrationParameters(
                        activationCode: "synthetic", activationURL: "https://activation.auth.microsoft.com"
                    ))
                XCTFail("Unavailable device metadata must fail enrollment")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .invalidResponse)
            }
            XCTAssertNil(try storage.load().pendingEnrollment)
            XCTAssertTrue(try storage.load().accounts.isEmpty)
            let records = try await manager.registeredAuthMethods()
            XCTAssertTrue(records.isEmpty)
        }
    }

    private func assertEnrollmentDeviceName(
        _ deviceName: String, provider: (@Sendable () -> String?)? = nil
    ) async throws
    {
        let url = "https://activation.auth.microsoft.com"
        var qr = URLComponents(string: "phonefactor://activate_account")!
        qr.queryItems = [URLQueryItem(name: "code", value: "synthetic"), URLQueryItem(name: "url", value: url)]
        let inputs = [
            MSALNativeAuthMFARegistrationParameters(qrCode: try XCTUnwrap(qr.string)),
            MSALNativeAuthMFARegistrationParameters(activationCode: "synthetic", activationURL: url)
        ]
        for input in inputs
        {
            let submitted = expectation(description: "Activation metadata forwarded")
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                let body = try XML.parse(XCTUnwrap(request.httpBody))
                let activation = try body.child("Body").child("ActivateNew").child("activationParams")
                XCTAssertEqual(try activation.value("DeviceName"), deviceName)
                submitted.fulfill()
                return Self.soap("ActivateNew", fields: "<error><Code>15</Code></error>", result: "false")
            }, storage: MfaTestStorage(), deviceNameProvider: provider)
            try await manager.updatePushRegistration(deviceToken: Data([1]), apnsEnvironment: .sandbox)
            do
            {
                _ = try await manager.registerAuthMethod(registrationParameters: input)
                XCTFail("Synthetic service rejection must propagate")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .serviceFailure(operation: "ActivateNew", code: "15"))
            }
            await fulfillment(of: [submitted], timeout: 2)
        }
    }

    func testSoapFailureNeverBecomesRegistrationSuccess() async
    {
        let client = MSALNativeAuthMFAServiceClient(transport: MfaTestTransport { _ in
            Data("<Envelope><Body><ActivateNewResponse><ActivateNewResult>false</ActivateNewResult></ActivateNewResponse></Body></Envelope>".utf8)
        })
        do
        {
            _ = try await client.activation(operation: "ActivateNew",
                endpoint: URL(string: "https://activation.auth.microsoft.com/PfPaWs.asmx")!, fields: [])
            XCTFail("A service rejection must fail even with HTTP 200")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .serviceFailure(operation: "ActivateNew", code: "Rejected"))
        }
    }

    func testSoapRejectionPreservesOnlyBoundedNumericCodes() async throws
    {
        for (code, expected) in [
            ("15", "15"), (" 27 ", "27"), ("", "Rejected"), ("synthetic-private-value", "Rejected"),
            ("12345678901", "Rejected"), ("\u{FF11}\u{FF12}", "Rejected")
        ]
        {
            let client = MSALNativeAuthMFAServiceClient(transport: MfaTestTransport { _ in
                Self.soap("ActivateNew", fields:
                    "<error><Code>\(code)</Code><Description>synthetic-private-description</Description></error>", result: "false")
            })
            do
            {
                _ = try await client.activation(operation: "ActivateNew",
                    endpoint: URL(string: "https://activation.auth.microsoft.com/PfPaWs.asmx")!, fields: [])
                XCTFail("Explicit failure must throw")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .serviceFailure(operation: "ActivateNew", code: expected))
            }
        }
    }

    func testExplicitEnrollmentRejectionAllowsRetryAfterManagerRestart() async throws
    {
        for operation in ["ActivateNew", "ConfirmActivation"]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.enrollmentState(awaitingConfirmation: operation == "ConfirmActivation"))
            let submitted = expectation(description: "\(operation) retried")
            submitted.expectedFulfillmentCount = 2
            let transport = MfaTestTransport { request in
                XCTAssertTrue(request.value(forHTTPHeaderField: "SOAPAction")?.hasSuffix("/" + operation) == true)
                submitted.fulfill()
                return Self.soap(operation, fields: "<error><Code>15</Code></error>", result: "false")
            }
            for _ in 0..<2
            {
                let manager = MSALNativeAuthMFAManager(transport: transport, storage: storage, deviceNameProvider: {
                    XCTAssertEqual(operation, "ActivateNew", "Resuming confirmation must not derive device metadata again")
                    return "iPhone13,2"
                })
                do
                {
                    _ = try await manager.registerAuthMethod(registrationParameters:
                        MSALNativeAuthMFARegistrationParameters(
                            activationCode: "synthetic", activationURL: "https://activation.auth.microsoft.com"
                        ))
                    XCTFail("Service rejection must not succeed")
                }
                catch
                {
                    XCTAssertEqual(error as? Failure, .serviceFailure(operation: operation, code: "15"))
                }
                let state = try storage.load()
                XCTAssertTrue(state.accounts.isEmpty)
                XCTAssertEqual(state.currentToken, "sb-apns2-01")
                if operation == "ActivateNew"
                {
                    XCTAssertNil(state.pendingEnrollment)
                }
                else
                {
                    let pending = try XCTUnwrap(state.pendingEnrollment)
                    XCTAssertFalse(pending.confirming)
                    XCTAssertNotNil(pending.activation)
                    XCTAssertNotNil(pending.validation)
                }
            }
            await fulfillment(of: [submitted], timeout: 2)
        }
    }

    func testRejectedEnrollmentDoesNotBecomeRetryableIfStateCleanupFails() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.enrollmentState(awaitingConfirmation: false))
        let submitted = expectation(description: "Only one activation request")
        let transport = MfaTestTransport { _ in
            submitted.fulfill()
            storage.failNextSave()
            return Self.soap("ActivateNew", fields: "<error><Code>15</Code></error>", result: "false")
        }
        for attempt in 0..<2
        {
            let manager = MSALNativeAuthMFAManager(transport: transport, storage: storage)
            do
            {
                _ = try await manager.registerAuthMethod(registrationParameters:
                    MSALNativeAuthMFARegistrationParameters(
                        activationCode: "synthetic", activationURL: "https://activation.auth.microsoft.com"
                    ))
                XCTFail("Storage cleanup failure must not permit replay")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, attempt == 0 ? .storageFailure(status: -50) : .outcomeUnknown)
            }
        }
        XCTAssertNotNil(try storage.load().pendingEnrollment)
        await fulfillment(of: [submitted], timeout: 2)
    }

    func testAmbiguousEnrollmentFailuresRemainNonReplayable() async throws
    {
        for operation in ["ActivateNew", "ConfirmActivation"]
        {
            for failure in ["transport", "fault", "malformed", "duplicateCode"]
            {
                let storage = MfaTestStorage()
                try storage.save(Self.enrollmentState(awaitingConfirmation: operation == "ConfirmActivation"))
                let submitted = expectation(description: "Only one \(operation) for \(failure)")
                let transport = MfaTestTransport { request in
                    XCTAssertTrue(request.value(forHTTPHeaderField: "SOAPAction")?.hasSuffix("/" + operation) == true)
                    submitted.fulfill()
                    switch failure
                    {
                    case "transport": throw Failure.transportFailure
                    case "fault":
                        return Data("<Envelope><Body><Fault><faultstring>synthetic</faultstring></Fault></Body></Envelope>".utf8)
                    case "duplicateCode":
                        return Self.soap(operation, fields: "<error><Code>15</Code><Code>27</Code></error>", result: "false")
                    default: return Self.soap(operation, fields: "", result: "unexpected")
                    }
                }
                for attempt in 0..<2
                {
                    let manager = MSALNativeAuthMFAManager(transport: transport, storage: storage)
                    do
                    {
                        _ = try await manager.registerAuthMethod(registrationParameters:
                            MSALNativeAuthMFARegistrationParameters(
                                activationCode: "synthetic", activationURL: "https://activation.auth.microsoft.com"
                            ))
                        XCTFail("Ambiguous response must not succeed")
                    }
                    catch
                    {
                        let expected: Failure
                        if attempt == 1 { expected = .outcomeUnknown }
                        else if failure == "transport" { expected = .transportFailure }
                        else if failure == "fault" { expected = .serviceFailure(operation: operation, code: "SOAPFault") }
                        else { expected = .invalidResponse }
                        XCTAssertEqual(error as? Failure, expected)
                    }
                }
                XCTAssertNotNil(try storage.load().pendingEnrollment)
                await fulfillment(of: [submitted], timeout: 2)
            }
        }
    }

    func testDiscoverySelectsMatchingOrDefaultRouteAndCachesMap() async throws
    {
        for scope in ["MATCH", "UNLISTED"]
        {
            let storage = MfaTestStorage()
            var state = Self.registeredState()
            state.accounts[0].replicationScope = scope
            try storage.save(state)
            let discovered = expectation(description: "Discovery fetched once")
            discovered.assertForOverFulfill = true
            let checked = expectation(description: "Two empty polls")
            checked.expectedFulfillmentCount = 2
            let defaultURL = "https://mobileappcommunicator.auth.microsoft.com/mac/MobileAppCommunicator.svc"
            let matchedURL = "https://activation.auth.microsoft.com/pad"
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppGetEndpoints"
                {
                    discovered.fulfill()
                    return Self.phone("phoneAppGetEndpointsResponse", fields: """
                        <version>1</version><defaultUrl>\(defaultURL)</defaultUrl><endpoints>\
                        <endpoint><replicationScopes>MATCH,ALIAS</replicationScopes><url>\(matchedURL)</url></endpoint>\
                        <endpoint><replicationScopes>OTHER</replicationScopes>\
                        <url>https://untrusted.example.test/mac/MobileAppCommunicator.svc</url></endpoint>\
                        </endpoints>
                        """)
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppCheckForAuthentication")
                XCTAssertEqual(request.url?.absoluteString, scope == "MATCH" ? matchedURL : defaultURL)
                checked.fulfill()
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields: """
                    <checkForAuthenticationResult>101</checkForAuthenticationResult>\
                    <padUrl/><username/><oathCounter>123</oathCounter>
                    """)
            }, storage: storage)
            for _ in 0..<2
            {
                let sessions = try await manager.pullPendingNotifications()
                XCTAssertTrue(sessions.isEmpty)
            }
            await fulfillment(of: [discovered, checked], timeout: 2)
        }
    }

    func testDiscoveryRejectsUntrustedSelectedDefaultAndMatchingRoutes() async throws
    {
        for matching in [false, true]
        {
            let storage = MfaTestStorage()
            var state = Self.registeredState()
            state.accounts[0].replicationScope = "MATCH"
            try storage.save(state)
            let untrusted = "https://untrusted.example.test/mac/MobileAppCommunicator.svc"
            let trusted = "https://activation.auth.microsoft.com/pad"
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppGetEndpoints")
                return Self.phone("phoneAppGetEndpointsResponse", fields: """
                    <version>1</version><defaultUrl>\(matching ? trusted : untrusted)</defaultUrl><endpoints>\
                    <endpoint><replicationScopes>\(matching ? "MATCH" : "OTHER")</replicationScopes>\
                    <url>\(untrusted)</url></endpoint></endpoints>
                    """)
            }, storage: storage)
            do
            {
                _ = try await manager.pullPendingNotifications()
                XCTFail("An untrusted selected route must not be contacted or bypassed")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .untrustedEndpoint)
            }
        }
    }

    func testNoPendingResultContinuesToNextAccount() async throws
    {
        let storage = MfaTestStorage()
        var state = Self.registeredState()
        var second = state.accounts[0]
        second.id = "second-registration"
        state.accounts.append(second)
        try storage.save(state)
        let checked = expectation(description: "Both accounts checked")
        checked.expectedFulfillmentCount = 2
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppCheckForAuthentication")
            checked.fulfill()
            return Self.phone("phoneAppCheckForAuthenticationResponse", fields: "<checkForAuthenticationResult>101</checkForAuthenticationResult>")
        }, storage: storage)
        let sessions = try await manager.pullPendingNotifications()
        XCTAssertTrue(sessions.isEmpty)
        await fulfillment(of: [checked], timeout: 2)
    }

    func testPollingStillRejectsOtherServiceFailuresAndMalformedResults() async throws
    {
        for code in ["100", "999", "invalid"]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppCheckForAuthentication")
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields:
                    "<checkForAuthenticationResult>\(code)</checkForAuthenticationResult>")
            }, storage: storage)
            do
            {
                _ = try await manager.pullPendingNotifications()
                XCTFail("Only the recognized no-pending code may suppress a failure")
            }
            catch
            {
                let expected: Failure = code == "invalid"
                    ? .invalidResponse : .serviceFailure(operation: "CheckForAuthentication", code: code)
                XCTAssertEqual(error as? Failure, expected)
            }
        }
    }

    func testCredentialPolicyDecodesSupportedNumberMatchingSettings() throws
    {
        XCTAssertFalse(try MSALNativeAuthMFACredentialPolicy(encoded: "").requiresNumberMatching)
        // Phone mode ANY, number matching ENABLED; companion number matching ENABLED.
        let supported = Self.credentialPolicy(phone: [0x10, 2, 0x28, 2], companion: [0x28, 2, 0x38, 2])
        XCTAssertTrue(try MSALNativeAuthMFACredentialPolicy(encoded: supported).requiresNumberMatching)
        let ordinary = Self.credentialPolicy(phone: [0x10, 1])
        XCTAssertFalse(try MSALNativeAuthMFACredentialPolicy(encoded: ordinary).requiresNumberMatching)
        let companionRequired = Self.credentialPolicy(phone: [0x10, 2], companion: [0x28, 2])
        XCTAssertTrue(try MSALNativeAuthMFACredentialPolicy(encoded: companionRequired).requiresNumberMatching)
        let platformDisabled = Self.credentialPolicy(phone: [0x10, 2], platform: [0x08, 0])
        XCTAssertFalse(try MSALNativeAuthMFACredentialPolicy(encoded: platformDisabled).requiresNumberMatching)
    }

    func testCredentialPolicyRejectsUnsupportedRequirementsAndUnknownEnums() throws
    {
        let invalid = [
            Self.credentialPolicy(phone: []),
            Self.credentialPolicy(phone: [0x10, 0]),
            Self.credentialPolicy(phone: [0x10, 3]),
            Self.credentialPolicy(phone: [0x10, 4]),
            Self.credentialPolicy(phone: [0x10, 2, 0x18, 2]), // App context.
            Self.credentialPolicy(phone: [0x10, 2, 0x20, 2]), // Location context.
            Self.credentialPolicy(phone: [0x10, 2, 0x30, 2]), // App lock.
            Self.credentialPolicy(phone: [0x10, 2, 0x28, 1]), // Unresolved default.
            Self.credentialPolicy(phone: [0x10, 2, 0x28, 3]),
            Self.credentialPolicy(phone: [0x10, 2, 0x38, 3]),
            Self.credentialPolicy(phone: [0x10, 2, 0x40, 1]),
            Self.credentialPolicy(phone: [0x10, 2, 0x40, 2]),
            Self.credentialPolicy(phone: [0x10, 2, 0x08, 2]),
            Self.credentialPolicy(phone: [0x10, 2], platform: [0x08, 1]),
            Self.credentialPolicy(phone: [0x10, 2], companion: [0x30, 2]),
            Self.credentialPolicy(phone: [0x10, 2], companion: [0x28, 1]),
            Self.credentialPolicy(phone: [0x10, 2], companion: [0x38, 3])
        ]
        for value in invalid
        {
            XCTAssertThrowsError(try MSALNativeAuthMFACredentialPolicy(encoded: value)) { error in
                XCTAssertEqual(error as? Failure, .unsupportedPolicy)
            }
        }
    }

    func testCredentialPolicyRejectsMalformedAndAmbiguousProtobuf() throws
    {
        let malformed: [[UInt8]] = [
            [], [0], [0x12], [0x12, 5, 0x10, 2], // Empty, invalid tag, truncated length/message.
            [0x12, 2, 0x10, 0x80], // Truncated nested varint.
            [0x12, 4, 0x10, 1, 0x10, 2], // Duplicate scalar.
            [0x12, 2, 0x10, 2, 0x12, 2, 0x10, 2], // Duplicate message.
            [0x12, 2, 0x10, 2, 0x32, 0], // Unsupported top-level policy.
            [0x12, 4, 0x10, 2, 0x48, 0], // Unknown phone field.
            [0x10, 2], [0x12, 3, 0x12, 1, 2], // Wrong wire types.
            [0x13], [0x15, 0, 0, 0, 0], // Groups and fixed-width fields.
            Array(repeating: 0xff, count: 10) + [0],
            [0x12] + Array(repeating: 0xff, count: 10),
            [0x12, 11, 0x10] + Array(repeating: 0xff, count: 9) + [2]
        ]
        let inputs = malformed.map { Data($0).base64EncodedString() } + ["not base64!", String(repeating: "A", count: 4097)]
        for input in inputs where !input.isEmpty
        {
            XCTAssertThrowsError(try MSALNativeAuthMFACredentialPolicy(encoded: input)) { error in
                XCTAssertEqual(error as? Failure, .unsupportedPolicy)
            }
        }
    }

    func testSupportedCredentialPolicyRequiresNumberBeforeApproval() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let policy = Self.credentialPolicy(phone: [0x10, 2, 0x28, 2], companion: [0x28, 2, 0x38, 2])
        let approved = expectation(description: "Policy-aware number approval sent once")
        approved.assertForOverFulfill = true
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthentication"
            {
                return Self.authentication(guid: guid, appLock: "no", requiresNumber: false, credentialPolicy: policy)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppPinValidation")
            let xml = try XML.parse(XCTUnwrap(request.httpBody))
            XCTAssertEqual(try xml.child("request").child("phoneAppPinValidationRequest").value("selectedEntropyNumber"), "42")
            approved.fulfill()
            return Self.phone("phoneAppPinValidationResponse", fields: "<validationResult>6</validationResult>")
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: [
            "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
        ])
        let session = try XCTUnwrap(sessions.first)
        XCTAssertTrue(session.requiresNumberMatching)
        do
        {
            _ = try await manager.approve(authSession: session, number: "")
            XCTFail("The credential policy's number requirement must be enforced")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .invalidNumber)
        }
        XCTAssertFalse(try storage.load().completedSessionIds.contains(guid))
        let result = try await manager.approve(authSession: session, number: "42")
        XCTAssertTrue(result.wasApproved)
        await fulfillment(of: [approved], timeout: 2)
    }

    func testUnsupportedCredentialPolicyBlocksApprovalButAllowsDenial() async throws
    {
        for policy in [
            "not base64!",
            Self.credentialPolicy(phone: [0x10, 2, 0x30, 2]),
            Self.credentialPolicy(phone: [0x10, 2], platform: [0x08, 1]),
            Self.credentialPolicy(phone: [0x10, 2], companion: [0x30, 2])
        ]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let guid = UUID().uuidString
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthentication"
                {
                    return Self.authentication(guid: guid, appLock: "no", credentialPolicy: policy)
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthenticationResult")
                let xml = try XML.parse(XCTUnwrap(request.httpBody))
                XCTAssertEqual(try xml.child("request").child("phoneAppAuthenticationResultRequest").value("authenticationResult"), "2")
                return Self.phone("phoneAppAuthenticationResultResponse", fields: "<authenticationResultResult>1</authenticationResultResult>")
            }, storage: storage)
            let sessions = try await manager.handlePushNotification(payload: [
                "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
            ])
            let session = try XCTUnwrap(sessions.first)
            do
            {
                _ = try await manager.approve(authSession: session, number: "42")
                XCTFail("Unsupported policy must not send approval")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .unsupportedPolicy)
            }
            XCTAssertFalse(try storage.load().completedSessionIds.contains(guid))
            let result = try await manager.deny(authSession: session)
            XCTAssertFalse(result.wasApproved)
        }
    }

    func testPushAndPullReadNestedAuthenticationInfo() async throws
    {
        for isPull in [false, true]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let guid = UUID().uuidString
            let fetched = expectation(description: "Authentication fetched")
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppCheckForAuthentication"
                {
                    XCTAssertTrue(isPull)
                    return Self.phone("phoneAppCheckForAuthenticationResponse", fields: """
                        <checkForAuthenticationResult>1</checkForAuthenticationResult>\
                        <padUrl>activation.auth.microsoft.com</padUrl><oathCounter>123</oathCounter>\
                        <username>fixture@example.test</username>
                        """)
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthentication")
                let xml = try XML.parse(XCTUnwrap(request.httpBody))
                let context = try xml.child("request").child("phoneAppAuthenticationRequest").child("phoneAppContext")
                XCTAssertEqual(try context.value("guid"), isPull ? "" : guid)
                XCTAssertEqual(try context.value("oathCode").isEmpty, !isPull)
                fetched.fulfill()
                return Self.authentication(guid: guid, appLock: "no")
            }, storage: storage)
            let sessions = try await (isPull
                ? manager.pullPendingNotifications()
                : manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"]))
            await fulfillment(of: [fetched], timeout: 2)
            XCTAssertEqual(sessions.count, 1)
            let session = try XCTUnwrap(sessions.first)
            XCTAssertEqual(session.guid, guid)
            XCTAssertEqual(session.username, "fixture@example.test")
            XCTAssertTrue(session.requiresNumberMatching)
            XCTAssertEqual(
                Set(Mirror(reflecting: session).children.compactMap(\.label)),
                ["guid", "accountName", "username", "requiresNumberMatching"]
            )
            let account = try XCTUnwrap(storage.load().accounts.first)
            XCTAssertEqual(account.replicationScope, "NA")
            XCTAssertEqual(account.routingHint, "synthetic-route")
            XCTAssertEqual(account.countryCode, "ZZ")
            XCTAssertEqual(account.dosPreventer, "proof")
        }
    }

    func testNestedAuthenticationIdentityMismatchIsRejected() async throws
    {
        for field in ["phoneAppDetailId", "tenantId", "azureObjectId"]
        {
            let guid = UUID().uuidString
            let xml = try XML.parse(Self.authentication(guid: guid, appLock: "no"))
            var response = try xml.child("response").child("phoneAppAuthenticationResponse")
            let infoIndex = try XCTUnwrap(response.children.firstIndex { $0.name == "phoneAppInfo" })
            let fieldIndex = try XCTUnwrap(response.children[infoIndex].children.firstIndex { $0.name == field })
            response.children[infoIndex].children[fieldIndex].text = "different"
            let data = Self.phone("phoneAppAuthenticationResponse", fields: response.children.map(\.encoded).joined())
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthentication")
                return data
            }, storage: storage)
            do
            {
                _ = try await manager.handlePushNotification(payload: [
                    "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
                ])
                XCTFail("A mismatched nested identity must not produce a session")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .unknownAccount)
            }
            XCTAssertEqual(try storage.load().accounts.first?.replicationScope, "")
        }
    }

    func testMissingOrDuplicateAuthenticationInfoIsRejected() async throws
    {
        for infoCount in [0, 2]
        {
            let guid = UUID().uuidString
            let xml = try XML.parse(Self.authentication(guid: guid, appLock: "no"))
            let response = try xml.child("response").child("phoneAppAuthenticationResponse")
            let info = try response.child("phoneAppInfo")
            let fields = response.children.filter { $0.name != "phoneAppInfo" } + Array(repeating: info, count: infoCount)
            let data = Self.phone("phoneAppAuthenticationResponse", fields: fields.map(\.encoded).joined())
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in data }, storage: storage)
            do
            {
                _ = try await manager.handlePushNotification(payload: [
                    "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
                ])
                XCTFail("Exactly one phoneAppInfo element is required")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .invalidResponse)
            }
        }
    }

    func testNumberMatchingAndDenialUseDifferentServiceOperationsAndRejectDuplicateDecision() async throws
    {
        for (approve, requiresNumber) in [(true, true), (true, false), (false, true)]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let guid = UUID().uuidString
            let transport = MfaTestTransport { request in
                let operation = request.value(forHTTPHeaderField: "x-ms-mac-action")
                if operation == "PhoneAppAuthentication"
                {
                    return Self.authentication(
                        guid: guid, appLock: "no", requiresNumber: requiresNumber,
                        credentialPolicy: Self.credentialPolicy(phone: [0x10, 2])
                    )
                }
                let xml = try XML.parse(XCTUnwrap(request.httpBody))
                if approve && requiresNumber
                {
                    XCTAssertEqual(operation, "PhoneAppPinValidation")
                    let body = try xml.child("request").child("phoneAppPinValidationRequest")
                    XCTAssertEqual(try body.value("selectedEntropyNumber"), "42")
                    XCTAssertEqual(try body.value("authenticate"), "yes")
                    return Self.phone("phoneAppPinValidationResponse", fields: "<validationResult>6</validationResult>")
                }
                XCTAssertEqual(operation, "PhoneAppAuthenticationResult")
                let body = try xml.child("request").child("phoneAppAuthenticationResultRequest")
                XCTAssertEqual(try body.value("authenticationResult"), approve ? "1" : "2")
                return Self.phone("phoneAppAuthenticationResultResponse", fields: "<authenticationResultResult>1</authenticationResultResult>")
            }
            let manager = MSALNativeAuthMFAManager(transport: transport, storage: storage)
            let sessions = try await manager.handlePushNotification(payload: [
                "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
            ])
            let session = try XCTUnwrap(sessions.first)
            XCTAssertEqual(session.requiresNumberMatching, requiresNumber)
            let result = try await (approve
                ? manager.approve(authSession: session, number: requiresNumber ? "42" : "")
                : manager.deny(authSession: session))
            XCTAssertEqual(result.wasApproved, approve)
            do
            {
                _ = try await manager.deny(authSession: session)
                XCTFail("A completed session cannot submit a second decision")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .invalidSession)
            }
        }
    }

    func testUnsupportedPolicyCannotBeApproved() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthentication")
            return Self.authentication(guid: guid, appLock: "yes")
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: [
            "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
        ])
        let session = try XCTUnwrap(sessions.first)
        do
        {
            _ = try await manager.approve(authSession: session, number: "42")
            XCTFail("App-lock policy must not be bypassed")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .unsupportedPolicy)
        }
    }

    func testRotationKeepsActivatedTokenUntilValidationCompletes() async throws
    {
        try await verifyTokenRotation(usesDiscoveryDefault: false)
    }

    func testRotationAcceptsDiscoveredDefaultButRejectsUnrelatedMappedHost() async throws
    {
        try await verifyTokenRotation(usesDiscoveryDefault: true)
    }

    func testUnchangedTokenDoesNotStartTokenChange() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
            XCTFail("An already activated token must not trigger network calls")
            throw Failure.transportFailure
        }, storage: storage)
        try await manager.updatePushRegistration(deviceToken: Data([1]), apnsEnvironment: .sandbox)
        XCTAssertEqual(try storage.load().accounts.first?.activatedToken, "sb-apns2-01")
        XCTAssertNil(try storage.load().previousToken)
    }

    func testTokenChangeRejectsMissingV2CredentialsWithoutNetwork() async throws
    {
        for missingID in [true, false]
        {
            let storage = MfaTestStorage()
            var state = Self.registeredState()
            if missingID { state.accounts[0].id = "" }
            else { state.accounts[0].secret = "" }
            try storage.save(state)
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Missing V2 credentials must not trigger discovery or a legacy fallback")
                throw Failure.transportFailure
            }, storage: storage)
            do
            {
                try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production)
                XCTFail("Missing V2 credentials must reject the update")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .invalidResponse)
            }
            XCTAssertEqual(try storage.load().accounts.first?.activatedToken, "sb-apns2-01")
            XCTAssertNil(try storage.load().previousToken)
        }
    }

    func testRejectedV2TokenChangeDoesNotFallBackToLegacy() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let started = expectation(description: "V2 token change submitted once")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppStartDeviceTokenChangeV2Request")
            started.fulfill()
            return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>0</deviceTokenChangeResult>")
        }, storage: storage)
        do
        {
            try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production)
            XCTFail("V2 rejection must be propagated")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .serviceFailure(operation: "DeviceTokenChange", code: "0"))
        }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(try storage.load().accounts.first?.activatedToken, "sb-apns2-01")
        XCTAssertNil(try storage.load().previousToken)
    }

    private func verifyTokenRotation(usesDiscoveryDefault: Bool) async throws
    {
        let storage = MfaTestStorage()
        var state = Self.registeredState()
        let previousToken = state.accounts[0].activatedToken
        state.accounts[0].replicationScope = usesDiscoveryDefault ? "UNLISTED" : ""
        try storage.save(state)
        let validationHost = usesDiscoveryDefault ? "mobileappcommunicator.auth.microsoft.com" : "activation.auth.microsoft.com"
        let started = expectation(description: "Token change started")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            let operation = request.value(forHTTPHeaderField: "x-ms-mac-action")
            if operation == "PhoneAppGetEndpoints"
            {
                XCTAssertTrue(usesDiscoveryDefault)
                return Self.phone("phoneAppGetEndpointsResponse", fields: """
                    <version>1</version>\
                    <defaultUrl>https://mobileappcommunicator.auth.microsoft.com/mac/MobileAppCommunicator.svc</defaultUrl>\
                    <endpoints><endpoint><replicationScopes>OTHER</replicationScopes>\
                    <url>https://unrelated.auth.microsoft.com/pad</url></endpoint></endpoints>
                    """)
            }
            XCTAssertEqual(request.url?.host, validationHost)
            if operation == "PhoneAppStartDeviceTokenChangeV2Request"
            {
                started.fulfill()
                return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>1</deviceTokenChangeResult>")
            }
            XCTAssertEqual(operation, "PhoneAppCompleteDeviceTokenChangeV2Request")
            let xml = try XML.parse(XCTUnwrap(request.httpBody))
            let body = try xml.child("request").child("phoneAppCompleteDeviceTokenChangeV2Request")
            XCTAssertEqual(try body.value("newDeviceToken"), "apns2-02")
            let account = try body.child("accounts").child("account")
            XCTAssertEqual(try account.value("phoneAppDetailId"), "registration")
            XCTAssertEqual(try account.value("oathCode").count, 40)
            return Self.phone("phoneAppCompleteDeviceTokenChangeV2Response", fields: """
                <deviceTokenChangeResult>1</deviceTokenChangeResult><accountValidationResults>\
                <account><phoneAppDetailId>registration</phoneAppDetailId><validationResult>Success</validationResult></account>\
                </accountValidationResults>
                """)
        }, storage: storage)
        let update = Task { try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(try storage.load().currentToken, "apns2-02")
        XCTAssertEqual(try storage.load().accounts.first?.activatedToken, previousToken)
        for scenario in ["DeviceTokenChangeV1", "QrRegistration"]
        {
            do
            {
                _ = try await manager.handlePushNotification(payload: [
                    "type": "validate", "guid": UUID().uuidString, "url": validationHost,
                    "validationScenario": scenario, "tenantId": "tenant", "oathCounter": "123"
                ])
                XCTFail("Only V2 validation may complete a token update")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .unexpectedNotification)
            }
        }
        if usesDiscoveryDefault
        {
            do
            {
                _ = try await manager.handlePushNotification(payload: [
                    "type": "validate", "guid": UUID().uuidString, "url": "unrelated.auth.microsoft.com",
                    "validationScenario": "DeviceTokenChangeV2", "tenantId": "tenant", "oathCounter": "123"
                ])
                XCTFail("An unrelated mapped host must not validate this account's token")
            }
            catch
            {
                XCTAssertEqual(error as? Failure, .untrustedEndpoint)
            }
        }
        _ = try await manager.handlePushNotification(payload: [
            "type": "validate", "guid": UUID().uuidString, "url": validationHost,
            "validationScenario": "DeviceTokenChangeV2", "tenantId": "tenant", "oathCounter": "123"
        ])
        try await update.value
        XCTAssertEqual(try storage.load().accounts.first?.activatedToken, "apns2-02")
        XCTAssertEqual(try storage.load().previousToken, previousToken)
    }

    func testRoutingSuspensionCannotBeOvertakenByRegistrationOrAnotherTokenUpdate() async throws
    {
        let storage = MfaTestStorage()
        var state = Self.registeredState()
        state.accounts[0].replicationScope = "NA"
        try storage.save(state)
        let routingStarted = expectation(description: "Routing request started")
        let gate = MfaRequestGate()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            guard request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppGetEndpoints" else
            {
                XCTFail("No activation or token-change request may overtake routing")
                throw Failure.transportFailure
            }
            routingStarted.fulfill()
            await gate.wait()
            return Self.phone("phoneAppGetEndpointsResponse", fields: """
                <version>1</version><defaultUrl>https://activation.auth.microsoft.com/pad</defaultUrl>\
                <endpoints><endpoint><replicationScopes>NA</replicationScopes>\
                <url>https://activation.auth.microsoft.com/pad</url></endpoint></endpoints>
                """)
        }, storage: storage)
        let update = Task { try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production) }
        await fulfillment(of: [routingStarted], timeout: 2)
        do
        {
            _ = try await manager.registerAuthMethod(registrationParameters:
                MSALNativeAuthMFARegistrationParameters(
                    activationCode: "synthetic", activationURL: "https://activation.auth.microsoft.com"
                ))
            XCTFail("Enrollment must not replace an in-flight token update")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .operationInProgress)
        }
        do
        {
            try await manager.updatePushRegistration(deviceToken: Data([3]), apnsEnvironment: .production)
            XCTFail("A second update must not start another validation operation")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .operationInProgress)
        }
        await gate.release()
        do
        {
            try await update.value
            XCTFail("The superseded token must not be submitted after routing completes")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .operationInProgress)
        }
        let saved = try storage.load()
        XCTAssertEqual(saved.currentToken, "apns2-03")
        XCTAssertEqual(saved.accounts.first?.activatedToken, "sb-apns2-01")
        XCTAssertNil(saved.pendingEnrollment)
    }

    func testDecisionCanRetryWhenPersistenceFailsBeforeSubmission() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let submitted = expectation(description: "Decision submitted once")
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppAuthentication"
            {
                return Self.authentication(guid: guid, appLock: "no")
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthenticationResult")
            submitted.fulfill()
            return Self.phone("phoneAppAuthenticationResultResponse", fields: "<authenticationResultResult>1</authenticationResultResult>")
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: [
            "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
        ])
        let session = try XCTUnwrap(sessions.first)
        storage.failNextSave()
        do
        {
            _ = try await manager.deny(authSession: session)
            XCTFail("A persistence failure must prevent submission")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .storageFailure(status: -50))
        }
        XCTAssertFalse(try storage.load().completedSessionIds.contains(guid))
        let result = try await manager.deny(authSession: session)
        XCTAssertFalse(result.wasApproved)
        await fulfillment(of: [submitted], timeout: 2)
    }

    func testSubmittedSessionsCannotBeRetrievedDuringOrAfterDecision() async throws
    {
        for fails in [false, true]
        {
            let storage = MfaTestStorage()
            try storage.save(Self.registeredState())
            let guid = UUID().uuidString
            let submitted = expectation(description: "Decision is in flight")
            let gate = MfaRequestGate()
            let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
                switch request.value(forHTTPHeaderField: "x-ms-mac-action")
                {
                case "PhoneAppGetEndpoints":
                    return Self.phone("phoneAppGetEndpointsResponse", fields: """
                        <version>1</version><defaultUrl>https://activation.auth.microsoft.com/pad</defaultUrl><endpoints/>
                        """)
                case "PhoneAppCheckForAuthentication":
                    return Self.phone("phoneAppCheckForAuthenticationResponse", fields: """
                        <checkForAuthenticationResult>1</checkForAuthenticationResult>\
                        <padUrl>activation.auth.microsoft.com</padUrl><oathCounter>123</oathCounter>\
                        <username>fixture@example.test</username>
                        """)
                case "PhoneAppAuthentication":
                    return Self.authentication(guid: guid, appLock: "no")
                case "PhoneAppAuthenticationResult":
                    submitted.fulfill()
                    await gate.wait()
                    if fails { throw Failure.transportFailure }
                    return Self.phone("phoneAppAuthenticationResultResponse", fields: """
                        <authenticationResultResult>1</authenticationResultResult>
                        """)
                default:
                    XCTFail("Unexpected operation")
                    throw Failure.invalidResponse
                }
            }, storage: storage)
            let payload = ["type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"]
            let fetched = try await manager.handlePushNotification(payload: payload)
            let session = try XCTUnwrap(fetched.first)
            let duplicate = try await manager.handlePushNotification(payload: payload)
            XCTAssertTrue(duplicate.first === session)
            let decision = Task { try await manager.deny(authSession: session) }
            await fulfillment(of: [submitted], timeout: 2)
            for isPull in [false, true]
            {
                do
                {
                    _ = try await (isPull
                        ? manager.pullPendingNotifications()
                        : manager.handlePushNotification(payload: payload))
                    XCTFail("A submitted request must not be returned as an active session")
                }
                catch
                {
                    XCTAssertEqual(error as? Failure, .invalidSession)
                }
            }
            await gate.release()
            do
            {
                let result = try await decision.value
                XCTAssertFalse(fails)
                XCTAssertFalse(result.wasApproved)
            }
            catch
            {
                XCTAssertTrue(fails)
                XCTAssertEqual(error as? Failure, .transportFailure)
            }
            let restarted = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
                XCTFail("Persisted replay protection must reject the push before HTTP")
                throw Failure.transportFailure
            }, storage: storage)
            for reader in [manager, restarted]
            {
                do
                {
                    _ = try await reader.handlePushNotification(payload: payload)
                    XCTFail("Submission must remain replay-blocked after success, failure, or restart")
                }
                catch
                {
                    XCTAssertEqual(error as? Failure, .invalidSession)
                }
            }
            XCTAssertTrue(try storage.load().completedSessionIds.contains(guid))
        }
    }

    func testPullRejectsCachedSessionForAnotherAccount() async throws
    {
        let storage = MfaTestStorage()
        var state = Self.registeredState()
        var other = state.accounts[0]
        other.id = "other-registration"
        other.username = "other@example.test"
        other.objectId = "other-object"
        state.accounts.insert(other, at: 0)
        try storage.save(state)
        let guid = UUID().uuidString
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppCheckForAuthentication"
            {
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields: """
                    <checkForAuthenticationResult>1</checkForAuthenticationResult>\
                    <padUrl>activation.auth.microsoft.com</padUrl><oathCounter>123</oathCounter>\
                    <username>other@example.test</username>
                    """)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthentication")
            return Self.authentication(guid: guid, appLock: "no")
        }, storage: storage)
        let fetched = try await manager.handlePushNotification(payload: [
            "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
        ])
        XCTAssertEqual(fetched.count, 1)
        do
        {
            _ = try await manager.pullPendingNotifications()
            XCTFail("Cached sessions must still match the account used for the pull proof")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .unknownAccount)
        }
    }

    func testDelayedAuthenticationPreservesCompletedTokenUpdate() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let fetching = expectation(description: "Authentication retrieval suspended")
        let started = expectation(description: "Token update started")
        let gate = MfaRequestGate()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            switch request.value(forHTTPHeaderField: "x-ms-mac-action")
            {
            case "PhoneAppAuthentication":
                fetching.fulfill()
                await gate.wait()
                return Self.authentication(guid: guid, appLock: "no")
            case "PhoneAppStartDeviceTokenChangeV2Request":
                started.fulfill()
                return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>1</deviceTokenChangeResult>")
            case "PhoneAppCompleteDeviceTokenChangeV2Request":
                return Self.phone("phoneAppCompleteDeviceTokenChangeV2Response", fields: """
                    <deviceTokenChangeResult>1</deviceTokenChangeResult><accountValidationResults>\
                    <account><phoneAppDetailId>registration</phoneAppDetailId><validationResult>Success</validationResult></account>\
                    </accountValidationResults>
                    """)
            default:
                XCTFail("Unexpected operation")
                throw Failure.invalidResponse
            }
        }, storage: storage)
        let fetch = Task { try await manager.handlePushNotification(payload: [
            "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
        ]) }
        await fulfillment(of: [fetching], timeout: 2)
        do
        {
            let update = Task { try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production) }
            await fulfillment(of: [started], timeout: 2)
            _ = try await manager.handlePushNotification(payload: [
                "type": "validate", "guid": UUID().uuidString, "url": "activation.auth.microsoft.com",
                "validationScenario": "DeviceTokenChangeV2", "tenantId": "tenant", "oathCounter": "123"
            ])
            try await update.value
        }
        catch
        {
            await gate.release()
            _ = await fetch.result
            throw error
        }
        await gate.release()
        let sessions = try await fetch.value
        XCTAssertEqual(sessions.count, 1)
        let saved = try storage.load()
        XCTAssertEqual(saved.currentToken, "apns2-02")
        XCTAssertEqual(saved.previousToken, "sb-apns2-01")
        XCTAssertEqual(saved.accounts.first?.activatedToken, "apns2-02")
        XCTAssertEqual(saved.accounts.first?.replicationScope, "NA")
        try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production)
    }

    func testSupersededValidationPersistsCompletedAccountButDoesNotReportSuccess() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let started = expectation(description: "Account update starts once")
        started.assertForOverFulfill = true
        let validating = expectation(description: "Validation completion is in flight")
        let gate = MfaRequestGate()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppStartDeviceTokenChangeV2Request"
            {
                started.fulfill()
                return Self.phone("phoneAppStartDeviceTokenChangeV2Response", fields: "<deviceTokenChangeResult>1</deviceTokenChangeResult>")
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppCompleteDeviceTokenChangeV2Request")
            validating.fulfill()
            await gate.wait()
            return Self.phone("phoneAppCompleteDeviceTokenChangeV2Response", fields: """
                <deviceTokenChangeResult>1</deviceTokenChangeResult><accountValidationResults>\
                <account><phoneAppDetailId>registration</phoneAppDetailId><validationResult>Success</validationResult></account>\
                </accountValidationResults>
                """)
        }, storage: storage)
        let update = Task { try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production) }
        await fulfillment(of: [started], timeout: 2)
        let validation = Task { try await manager.handlePushNotification(payload: [
            "type": "validate", "guid": UUID().uuidString, "url": "activation.auth.microsoft.com",
            "validationScenario": "DeviceTokenChangeV2", "tenantId": "tenant", "oathCounter": "123"
        ]) }
        await fulfillment(of: [validating], timeout: 2)
        do
        {
            try await manager.updatePushRegistration(deviceToken: Data([3]), apnsEnvironment: .production)
            XCTFail("The new token must be retained without starting a concurrent update")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .operationInProgress)
        }
        await gate.release()
        _ = try await validation.value
        do
        {
            try await update.value
            XCTFail("A superseded update must not report success")
        }
        catch
        {
            XCTAssertEqual(error as? Failure, .operationInProgress)
        }
        let saved = try storage.load()
        XCTAssertEqual(saved.currentToken, "apns2-03")
        XCTAssertEqual(saved.accounts[0].activatedToken, "apns2-02")
        XCTAssertEqual(saved.previousToken, "sb-apns2-01")
    }

    func testCanceledPullDoesNotReturnCachedSessionAfterAuthenticationResponse() async throws
    {
        let storage = MfaTestStorage()
        try storage.save(Self.registeredState())
        let guid = UUID().uuidString
        let fetching = expectation(description: "Authentication retrieval suspended")
        let gate = MfaRequestGate()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { request in
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppGetEndpoints"
            {
                return Self.phone("phoneAppGetEndpointsResponse", fields: """
                    <version>1</version><defaultUrl>https://activation.auth.microsoft.com/pad</defaultUrl><endpoints/>
                    """)
            }
            if request.value(forHTTPHeaderField: "x-ms-mac-action") == "PhoneAppCheckForAuthentication"
            {
                return Self.phone("phoneAppCheckForAuthenticationResponse", fields: """
                    <checkForAuthenticationResult>1</checkForAuthenticationResult>\
                    <padUrl>activation.auth.microsoft.com</padUrl><oathCounter>123</oathCounter>\
                    <username>fixture@example.test</username>
                    """)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-ms-mac-action"), "PhoneAppAuthentication")
            let xml = try XML.parse(XCTUnwrap(request.httpBody))
            let context = try xml.child("request").child("phoneAppAuthenticationRequest").child("phoneAppContext")
            if try context.value("guid").isEmpty
            {
                fetching.fulfill()
                await gate.wait()
            }
            return Self.authentication(guid: guid, appLock: "no")
        }, storage: storage)
        _ = try await manager.handlePushNotification(payload: [
            "type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"
        ])
        let fetch = Task { try await manager.pullPendingNotifications() }
        await fulfillment(of: [fetching], timeout: 2)
        fetch.cancel()
        await gate.release()
        do
        {
            _ = try await fetch.value
            XCTFail("Cancellation must not return a successful session")
        }
        catch
        {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(try storage.load().accounts.first?.replicationScope, "NA")
    }

    func testCanceledUpdateDoesNotReplaceStoredToken() async throws
    {
        let storage = MfaTestStorage()
        let manager = MSALNativeAuthMFAManager(transport: MfaTestTransport { _ in
            XCTFail("No network expected")
            throw Failure.transportFailure
        }, storage: storage)
        try await manager.updatePushRegistration(deviceToken: Data([1]), apnsEnvironment: .sandbox)
        let task = Task
        {
            withUnsafeCurrentTask { $0?.cancel() }
            try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .production)
        }
        do
        {
            try await task.value
            XCTFail("Cancellation must be propagated")
        }
        catch
        {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(try storage.load().currentToken, "sb-apns2-01")
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
                XCTAssertEqual(error as? Failure, expected)
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
                else { XCTAssertEqual(error as? Failure, .httpFailure(statusCode: 403)) }
            }
            XCTAssertEqual(try storage.load().accounts.count, 1)
        }
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
                    : (scenario == "unknown" ? .unknownAccount : .untrustedEndpoint)
                XCTAssertEqual(error as? Failure, expected)
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
        catch { XCTAssertEqual(error as? Failure, .operationInProgress) }
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
            if request.httpMethod == "DELETE" { return Data() }
            return Self.deletionAuthentication(guid: guid)
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"])
        let session = try XCTUnwrap(sessions.first)
        storage.failNextSave()
        do
        {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
            XCTFail("Local save failure must not report success")
        }
        catch { XCTAssertEqual(error as? Failure, .storageFailure(status: -50)) }
        XCTAssertEqual(try storage.load().accounts.count, 1)
        do { _ = try await manager.deny(authSession: session); XCTFail("Deleted registration must not authorize old sessions") }
        catch { XCTAssertEqual(error as? Failure, .invalidSession) }
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
            try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"])
        }
        await fulfillment(of: [fetching], timeout: 2)
        try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
        await gate.release()
        do { _ = try await fetch.value; XCTFail("Late fetch must not restore a deleted account") }
        catch { XCTAssertEqual(error as? Failure, .unknownAccount) }
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
        let sessions = try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"])
        let session = try XCTUnwrap(sessions.first)
        let deletion = Task { try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() } }
        await fulfillment(of: [deleting], timeout: 2)
        do { _ = try await manager.deny(authSession: session); XCTFail("Decision must not overlap Graph deletion") }
        catch { XCTAssertEqual(error as? Failure, .operationInProgress) }
        do
        {
            _ = try await manager.registerAuthMethod(registrationParameters: MSALNativeAuthMFARegistrationParameters(
                activationCode: "synthetic", activationURL: "https://activation.auth.microsoft.com"
            ))
            XCTFail("Enrollment must not overlap deletion")
        }
        catch { XCTAssertEqual(error as? Failure, .operationInProgress) }
        do
        {
            try await manager.updatePushRegistration(deviceToken: Data([2]), apnsEnvironment: .sandbox)
            XCTFail("Token reconciliation must wait")
        }
        catch { XCTAssertEqual(error as? Failure, .operationInProgress) }
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
                return Self.phone("phoneAppAuthenticationResultResponse", fields: "<authenticationResultResult>1</authenticationResultResult>")
            }
            XCTAssertNotEqual(request.httpMethod, "DELETE")
            return Self.deletionAuthentication(guid: guid)
        }, storage: storage)
        let sessions = try await manager.handlePushNotification(payload: ["type": "auth", "guid": guid, "url": "activation.auth.microsoft.com"])
        let session = try XCTUnwrap(sessions.first)
        let response = Task { try await manager.deny(authSession: session) }
        await fulfillment(of: [responding], timeout: 2)
        do
        {
            try await manager.deleteAuthMethod(registrationId: "registration") { _ in try Self.deletionToken() }
            XCTFail("Active decision must prevent remote deletion")
        }
        catch { XCTAssertEqual(error as? Failure, .operationInProgress) }
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

    private static func enrollmentState(awaitingConfirmation: Bool) throws -> MSALNativeAuthMFAStoredState
    {
        var state = MSALNativeAuthMFAStoredState(currentToken: "sb-apns2-01")
        guard awaitingConfirmation else { return state }
        let input = try MSALNativeAuthMFAActivation(code: "synthetic", url: "https://activation.auth.microsoft.com")
        state.pendingEnrollment = MSALNativeAuthMFAPendingEnrollment(
            id: UUID(), inputDigest: MSALNativeAuthMFAProof.digest(input.endpoint.absoluteString + "\n" + input.code),
            token: "sb-apns2-01",
            activation: XML(name: "ActivateNewResponse", children: [
                XML(name: "activationInfo", children: [
                    XML(name: "Username", text: "fixture@example.test"),
                    XML(name: "OathTokenSecretKey", text: "GEZDGNBVGY3TQOJQ"),
                    XML(name: "ConfirmationCode", text: "synthetic-confirmation")
                ])
            ]),
            validation: XML(name: "phoneAppValidateDeviceTokenResponse", children: [
                XML(name: "username", text: "fixture@example.test"), XML(name: "accountName", text: "Fixture account")
            ]),
            validationEndpoint: URL(string: "https://activation.auth.microsoft.com/pad")
        )
        return state
    }

    private static func registeredState() -> MSALNativeAuthMFAStoredState
    {
        MSALNativeAuthMFAStoredState(accounts: [
            MSALNativeAuthMFAAccountRecord(
                id: "registration", name: "Fixture account", username: "fixture@example.test",
                secret: "GEZDGNBVGY3TQOJQ", groupKey: "group", tenantId: "tenant", objectId: "object",
                endpoint: URL(string: "https://activation.auth.microsoft.com/pad")!,
                replicationScope: "", routingHint: "", countryCode: "",
                activatedToken: "sb-apns2-01", dosPreventer: "proof"
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

    private static func authentication(
        guid: String, appLock: String, requiresNumber: Bool = true, credentialPolicy: String = ""
    ) -> Data
    {
        phone("phoneAppAuthenticationResponse", fields: """
            <guid>\(guid)</guid><oathCounter>123</oathCounter><dosPreventer>proof</dosPreventer>\
            <phoneAppInfo mode="standard"><phoneAppDetailId>registration</phoneAppDetailId>\
            <tenantId>tenant</tenantId><azureObjectId>object</azureObjectId><replicationScope>NA</replicationScope>\
            <routingHint>synthetic-route</routingHint><countryCode>ZZ</countryCode>\
            <firstEntropyChallenge>\(requiresNumber ? "opaque" : "")</firstEntropyChallenge>\
            <returnLocationData>no</returnLocationData><isSilent>no</isSilent>\
            <isAppLockRequired>\(appLock)</isAppLockRequired><userCredentialPolicy>\(credentialPolicy)</userCredentialPolicy></phoneAppInfo>
            """)
    }

    private static func soap(_ operation: String, fields: String, result: String = "true") -> Data
    {
        Data("<Envelope><Body><\(operation)Response><\(operation)Result>\(result)</\(operation)Result>\(fields)</\(operation)Response></Body></Envelope>".utf8)
    }

    private static func phone(_ operation: String, fields: String) -> Data
    {
        Data("<pfpMessage><response><status disposition=\"success\"></status><\(operation)>\(fields)</\(operation)></response></pfpMessage>".utf8)
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
            throw MSALNativeAuthMFAServiceError.storageFailure(status: -50)
        }
        self.state = state
    }
}
