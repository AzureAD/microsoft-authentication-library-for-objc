//
//  MockNetworkProvider.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-06-04.
//

import Foundation
import MSALNativeCredManagment

/// A local mock network provider that returns fake HAL+JSON responses.
///
/// Used for development and testing without a live server. Toggle between
/// this and the real server implementation via the sample app settings.
class MockNetworkProvider: MSALNativeCredentialManagementNetworkProvider {

    func performRequest(
        _ request: MSALCredentialManagementHTTPRequest
    ) async throws -> MSALCredentialManagementHTTPResponse {
        // Simulate a brief network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3s

        let path = request.url.path

        switch (request.method, path) {
        case ("GET", let p) where p.contains("/me/methods"):
            return listMethodsResponse()
        case ("POST", let p) where p.contains("/activate"):
            return activateResponse()
        case ("POST", let p) where p.contains("/me/methods/phone"):
            return enrollPhoneResponse()
        case ("POST", let p) where p.contains("/me/methods/fido"):
            return enrollPasskeyResponse()
        case ("POST", let p) where p.contains("/me/methods/password"):
            return enrollPasswordResponse()
        case ("DELETE", _):
            return MSALCredentialManagementHTTPResponse(statusCode: 204, headers: [:], data: nil)
        default:
            return MSALCredentialManagementHTTPResponse(statusCode: 404, headers: [:], data: nil)
        }
    }

    // MARK: - Mock Responses

    private func listMethodsResponse() -> MSALCredentialManagementHTTPResponse {
        let json: [String: Any] = [
            "_embedded": [
                "methods": [
                    [
                        "id": "mock-phone-001",
                        "type": "phone",
                        "displayName": "+1 •••• 5678",
                        "createdDateTime": "2025-01-15T10:30:00Z",
                        "_links": [
                            "self": ["href": "/api/v1.0/me/methods/phone/mock-phone-001"]
                        ]
                    ],
                    [
                        "id": "mock-passkey-001",
                        "type": "fido",
                        "displayName": "iPhone Passkey",
                        "createdDateTime": "2025-02-01T14:00:00Z",
                        "aaGuid": "00000000-0000-0000-0000-000000000001",
                        "_links": [
                            "self": ["href": "/api/v1.0/me/methods/fido/mock-passkey-001"]
                        ]
                    ],
                    [
                        "id": "mock-password-001",
                        "type": "password",
                        "displayName": "Password",
                        "createdDateTime": "2024-12-01T09:00:00Z",
                        "_links": [
                            "self": ["href": "/api/v1.0/me/methods/password/mock-password-001"]
                        ]
                    ]
                ]
            ],
            "_links": [
                "self": ["href": "/api/v1.0/me/methods"],
                "enroll": [
                    ["href": "/api/v1.0/me/methods/phone", "name": "phone"],
                    ["href": "/api/v1.0/me/methods/fido", "name": "fido"],
                    ["href": "/api/v1.0/me/methods/password", "name": "password"]
                ]
            ]
        ]
        return jsonResponse(statusCode: 200, json: json)
    }

    private func enrollPhoneResponse() -> MSALCredentialManagementHTTPResponse {
        let json: [String: Any] = [
            "state": "challengeRequired",
            "continuationToken": "mock-continuation-token-phone",
            "challengeChannel": "sms",
            "challengeTargetLabel": "+1 •••• 5678",
            "codeLength": 6,
            "_links": [
                "activate": ["href": "/api/v1.0/me/methods/phone/mock-new-phone/activate"]
            ]
        ]
        return jsonResponse(statusCode: 200, json: json)
    }

    private func enrollPasskeyResponse() -> MSALCredentialManagementHTTPResponse {
        let json: [String: Any] = [
            "state": "completed",
            "method": [
                "id": "mock-passkey-new",
                "type": "fido",
                "displayName": "New Passkey",
                "createdDateTime": "2025-06-04T12:00:00Z",
                "_links": [
                    "self": ["href": "/api/v1.0/me/methods/fido/mock-passkey-new"]
                ]
            ]
        ]
        return jsonResponse(statusCode: 201, json: json)
    }

    private func enrollPasswordResponse() -> MSALCredentialManagementHTTPResponse {
        let json: [String: Any] = [
            "state": "completed",
            "method": [
                "id": "mock-password-new",
                "type": "password",
                "displayName": "Password",
                "createdDateTime": "2025-06-04T12:00:00Z",
                "_links": [
                    "self": ["href": "/api/v1.0/me/methods/password/mock-password-new"]
                ]
            ]
        ]
        return jsonResponse(statusCode: 201, json: json)
    }

    private func activateResponse() -> MSALCredentialManagementHTTPResponse {
        let json: [String: Any] = [
            "state": "completed",
            "method": [
                "id": "mock-activated-001",
                "type": "phone",
                "displayName": "+1 •••• 5678",
                "createdDateTime": "2025-06-04T12:00:00Z",
                "_links": [
                    "self": ["href": "/api/v1.0/me/methods/phone/mock-activated-001"]
                ]
            ]
        ]
        return jsonResponse(statusCode: 200, json: json)
    }

    // MARK: - Helpers

    private func jsonResponse(statusCode: Int, json: [String: Any]) -> MSALCredentialManagementHTTPResponse {
        let data = try? JSONSerialization.data(withJSONObject: json)
        return MSALCredentialManagementHTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/hal+json"],
            data: data
        )
    }
}
