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

/// In-memory mock implementation of `CredentialManagementNetworkClientProtocol`.
///
/// Operates entirely on real typed model objects — no HAL logic.
/// Stores methods in a dictionary keyed by ID for O(1) lookup/delete.
///
/// Activated via UserDefaults key `com.microsoft.identity.credentialmanagement.useMockAPI`.
internal final class CredentialManagementMockNetworkClient: CredentialManagementNetworkClientProtocol
{
    /// In-memory store of credential methods keyed by `id`.
    private var methodStore: [String: any MSALCredentialMethodProtocol]

    /// Tracks pending enrollments by continuationToken for activate step.
    private var pendingEnrollments: [String: PendingEnrollment]

    private struct PendingEnrollment
    {
        let type: MSALCredentialType
        let phoneNumber: String?
    }

    private var simulatedDelay: TimeInterval
    {
        let delay = UserDefaults.standard.double(
            forKey: "com.microsoft.identity.credentialmanagement.mockDelaySeconds"
        )
        return delay > 0 ? delay : 0.5
    }

    init()
    {
        self.methodStore = [:]
        self.pendingEnrollments = [:]
        Self.seedMethods().forEach { self.methodStore[$0.id] = $0 }

        MSIDLogger.shared().log(
            level: .warning,
            correlationId: UUID(),
            message: "⚠️ Mock network client is active. All credential management calls will return simulated data."
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
            message: "[Mock] listMethods — returning \(methodStore.count) methods"
        )

        return .success(Array(methodStore.values))
    }

    // MARK: - Begin Enrollment

    func beginEnrollment(
        type: MSALCredentialType,
        accessToken: String,
        body: Data?,
        correlationId: UUID
    ) async -> Result<EnrollmentBeginResponse, MSALNativeCredentialManagementError>
    {
        await simulateNetworkDelay()

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "[Mock] beginEnrollment for type=\(type.rawValue)"
        )

        switch type
        {
        case .password:
            // Password completes immediately
            let newId = "mock-\(UUID().uuidString.prefix(8))"
            let method = MSALPasswordCredentialMethod(id: newId, createdAt: Date())
            methodStore[newId] = method
            return .success(.completed(method))

        case .phone:
            let phoneNumber = extractPhoneNumber(from: body)
            let token = "mock-ct-\(UUID().uuidString.prefix(8))"
            pendingEnrollments[token] = PendingEnrollment(type: .phone, phoneNumber: phoneNumber)

            let maskedPhone = maskPhone(phoneNumber)
            let challengeInfo = EnrollmentChallengeInfo(
                sentTo: maskedPhone,
                channelType: "sms",
                codeLength: 6,
                continuationToken: token
            )
            return .success(.challengeRequired(challengeInfo))

        default:
            // Passkey — return creation options
            let token = "mock-ct-\(UUID().uuidString.prefix(8))"
            pendingEnrollments[token] = PendingEnrollment(type: type, phoneNumber: nil)

            let publicKey: [String: Any] = [
                "challenge": Data("mock-challenge-\(UUID().uuidString)".utf8).base64EncodedString(),
                "rp": ["id": "login.microsoft.com", "name": "Microsoft"],
                "user": [
                    "id": Data("mock-user-id".utf8).base64EncodedString(),
                    "name": "user@contoso.com",
                    "displayName": "Mock User"
                ]
            ]

            let creationInfo = PasskeyCreationInfo(
                publicKey: publicKey,
                continuationToken: token
            )
            return .success(.passkeyCreationRequired(creationInfo))
        }
    }

    // MARK: - Activate Enrollment

    func activateEnrollment(
        continuationToken: String,
        accessToken: String,
        body: Data,
        correlationId: UUID
    ) async -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>
    {
        await simulateNetworkDelay()

        MSIDLogger.shared().log(
            level: .info,
            correlationId: correlationId,
            message: "[Mock] activateEnrollment"
        )

        guard let pending = pendingEnrollments.removeValue(forKey: continuationToken) else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "No pending enrollment found for the given continuation token.",
                correlationId: correlationId
            ))
        }

        let newId = "mock-\(UUID().uuidString.prefix(8))"
        let bodyJson = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let displayName = bodyJson?["displayName"] as? String

        let method: any MSALCredentialMethodProtocol
        switch pending.type
        {
        case .phone:
            method = MSALPhoneCredentialMethod(
                id: newId,
                createdAt: Date(),
                phoneNumber: pending.phoneNumber ?? "+1 (555) 000-0000"
            )
        default:
            method = MSALPasskeyCredentialMethod(
                id: newId,
                displayName: displayName ?? "Passkey",
                createdAt: Date(),
                credentialID: "mock-cred-\(UUID().uuidString.prefix(8))",
                aaguid: nil
            )
        }

        methodStore[newId] = method
        return .success(method)
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
            message: "[Mock] deleteMethod id=\(methodId)"
        )

        methodStore.removeValue(forKey: methodId)
        return .success(())
    }

    // MARK: - Private

    private static func seedMethods() -> [any MSALCredentialMethodProtocol]
    {
        [
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

    private func extractPhoneNumber(from body: Data?) -> String?
    {
        guard let body = body,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else
        {
            return nil
        }
        return json["phoneNumber"] as? String
    }

    private func maskPhone(_ phone: String?) -> String
    {
        guard let phone = phone, phone.count > 4 else
        {
            return phone ?? "+1 (555) ***-0000"
        }
        return "••• \(String(phone.suffix(4)))"
    }

    private func simulateNetworkDelay() async
    {
        let delay = simulatedDelay
        if delay > 0
        {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
