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

import Foundation
import MSAL
@_implementationOnly import MSAL_Private

/// Internal mock API client that returns simulated responses without hitting the server.
///
/// Activated via UserDefaults key `com.microsoft.identity.credentialmanagement.useMockAPI`.
/// This is entirely internal — no public API exposes this client or the switch mechanism.
///
/// The mock maintains in-memory state so that enrollments and deletions are reflected
/// in subsequent `listMethods` calls within the same session.
internal final class CredentialManagementMockAPIClient: CredentialManagementNetworkClientProtocol
{
    /// Simulates network latency. Configurable via UserDefaults key
    /// `com.microsoft.identity.credentialmanagement.mockDelaySeconds` (default: 0.5).
    private var simulatedDelay: TimeInterval
    {
        let delay = UserDefaults.standard.double(
            forKey: "com.microsoft.identity.credentialmanagement.mockDelaySeconds"
        )
        return delay > 0 ? delay : 0.5
    }

    /// In-memory store of credential methods. Mutations (enroll/delete) persist for the
    /// lifetime of this client instance.
    private var methods: [any MSALCredentialMethodProtocol]

    /// Tracks the pending enrollment type between beginEnrollment and activateEnrollment.
    private var pendingEnrollmentType: MSALCredentialType?

    /// Tracks the user-provided phone number from the enrollment body.
    private var pendingPhoneNumber: String?

    init()
    {
        self.methods = Self.seedMethods()

        MSIDLogger.shared().log(
            level: .warning,
            correlationId: UUID(),
            message: "⚠️ Mock API client is active. All credential management calls will return simulated data."
        )
    }

    // MARK: - List Methods

    func listMethods(
        accessToken: String,
        correlationId: UUID
    ) async -> Result<[any MSALCredentialMethodProtocol], MSALNativeCredentialManagementError>
    {
        await simulateNetworkDelay()

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "[Mock] listMethods called — returning \(methods.count) methods"
        )

        return .success(methods)
    }

    // MARK: - Begin Enrollment

    func beginEnrollment(
        type: MSALCredentialType,
        accessToken: String,
        body: Data?,
        correlationId: UUID
    ) async -> Result<HALResource, MSALNativeCredentialManagementError>
    {
        await simulateNetworkDelay()

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "[Mock] beginEnrollment called for type=\(type.rawValue)"
        )

        // Track the pending enrollment so activateEnrollment returns the correct type
        pendingEnrollmentType = type

        // Extract phone number from body if present
        if type == .phone, let body = body,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let phone = json["phoneNumber"] as? String
        {
            pendingPhoneNumber = phone
        }

        let mockResponse = buildMockEnrollmentResponse(type: type)
        return .success(mockResponse)
    }

    // MARK: - Activate Enrollment

    func activateEnrollment(
        activateHref: String,
        accessToken: String,
        body: Data,
        correlationId: UUID
    ) async -> Result<HALResource, MSALNativeCredentialManagementError>
    {
        await simulateNetworkDelay()

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "[Mock] activateEnrollment called"
        )

        let enrolledType = pendingEnrollmentType ?? .passkey
        let newId = "mock-enrolled-\(UUID().uuidString.prefix(8))"

        // Extract displayName from the activation request body (provided by the user)
        let bodyJson = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let userDisplayName = bodyJson?["displayName"] as? String

        // Add the correct credential type to the in-memory store
        let newMethod: any MSALCredentialMethodProtocol
        switch enrolledType
        {
        case .phone:
            let phoneDisplay = pendingPhoneNumber ?? "+1 (555) ***-0000"
            newMethod = MSALPhoneCredentialMethod(
                id: newId,
                createdAt: nil,
                phoneNumber: phoneDisplay
            )
        case .password:
            newMethod = MSALPasswordCredentialMethod(
                id: newId,
                createdAt: nil
            )
        default:
            newMethod = MSALPasskeyCredentialMethod(
                id: newId,
                displayName: userDisplayName ?? "Passkey",
                createdAt: nil,
                credentialID: "mock-cred-\(UUID().uuidString.prefix(8))",
                aaguid: nil
            )
        }
        methods.append(newMethod)

        // Clear pending state
        let mockResponse = buildMockActivationResponse(type: enrolledType, id: newId, displayName: userDisplayName)
        pendingEnrollmentType = nil
        pendingPhoneNumber = nil

        return .success(mockResponse)
    }

    // MARK: - Delete Method

    func deleteMethod(
        type: MSALCredentialType,
        methodId: String,
        accessToken: String,
        correlationId: UUID
    ) async -> Result<Void, MSALNativeCredentialManagementError>
    {
        await simulateNetworkDelay()

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "[Mock] deleteMethod called for type=\(type.rawValue), id=\(methodId)"
        )

        // Remove from in-memory store so subsequent listMethods reflects the deletion
        methods.removeAll { $0.id == methodId }

        return .success(())
    }

    // MARK: - Private: Seed Data

    private static func seedMethods() -> [any MSALCredentialMethodProtocol]
    {
        return [
            MSALPasskeyCredentialMethod(
                id: "mock-passkey-001",
                displayName: "Mock Passkey",
                createdAt: nil,
                credentialID: "mock-credential-id-abc",
                aaguid: "00000000-0000-0000-0000-000000000001"
            ),
            MSALPhoneCredentialMethod(
                id: "mock-phone-001",
                createdAt: nil,
                phoneNumber: "+1 (555) 123-4567"
            ),
            MSALPasswordCredentialMethod(
                id: "mock-password-001",
                createdAt: nil
            )
        ]
    }

    // MARK: - Private: Mock Response Builders

    private func buildMockEnrollmentResponse(type: MSALCredentialType) -> HALResource
    {
        if type == .password
        {
            // Password completes in one step — no challenge/activation needed
            let newId = "mock-enrolled-\(UUID().uuidString.prefix(8))"
            let newMethod = MSALPasswordCredentialMethod(id: newId, createdAt: nil)
            methods.append(newMethod)

            let json: [String: Any] = [
                "id": newId,
                "type": type.rawValue,
                "state": "completed",
                "displayName": "Password"
            ]
            return HALResource(json: json)
        }

        var json: [String: Any] = [
            "continuationToken": "mock-continuation-token-\(UUID().uuidString.prefix(8))",
            "_links": [
                "activate": ["href": "https://mock.credentialmanagement.microsoft.com/activate"]
            ]
        ]

        if type == .phone
        {
            // Use the actual phone number provided by the user (masked for display)
            let maskedPhone: String
            if let phone = pendingPhoneNumber, phone.count > 4
            {
                let last4 = String(phone.suffix(4))
                maskedPhone = "••• \(last4)"
            }
            else
            {
                maskedPhone = pendingPhoneNumber ?? "+1 (555) ***-0000"
            }
            json["sentTo"] = maskedPhone
            json["channelType"] = "sms"
            json["codeLength"] = 6
        }
        else if type == .passkey
        {
            // Provide mock WebAuthn creation options so the passkey flow can parse them
            json["publicKey"] = [
                "challenge": Data("mock-challenge-\(UUID().uuidString)".utf8).base64EncodedString(),
                "rp": [
                    "id": "login.microsoft.com",
                    "name": "Microsoft"
                ],
                "user": [
                    "id": Data("mock-user-id".utf8).base64EncodedString(),
                    "name": "user@contoso.com",
                    "displayName": "Mock User"
                ]
            ]
        }

        return HALResource(json: json)
    }

    private func buildMockActivationResponse(type: MSALCredentialType, id: String, displayName: String?) -> HALResource
    {
        var json: [String: Any] = [
            "id": id,
            "type": type.rawValue
        ]

        switch type
        {
        case .phone:
            json["displayName"] = pendingPhoneNumber ?? "Phone"
            json["phoneNumber"] = pendingPhoneNumber ?? "+1 (555) 000-0000"
        case .password:
            json["displayName"] = "Password"
        default:
            json["displayName"] = displayName ?? "Passkey"
        }

        return HALResource(json: json)
    }

    // MARK: - Private: Delay Simulation

    private func simulateNetworkDelay() async
    {
        let delay = simulatedDelay
        if delay > 0
        {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
