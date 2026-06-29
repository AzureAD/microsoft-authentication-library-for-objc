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

extension MSALNativeCredentialMethodsClient
{
    // MARK: - Token Acquisition

    internal func acquireToken(
        correlationId: UUID,
        completion: @escaping (String?, Error?) -> Void
    )
    {
        guard let tokenProvider = config.tokenProvider else
        {
            let error = MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "Token provider is not configured.",
                correlationId: correlationId
            )
            completion(nil, error)
            return
        }

        let scopes = ["https://graph.microsoft.com/.default"]

        tokenProvider.getAccessToken(scopes: scopes)
        { accessToken, error in
            completion(accessToken, error)
        }
    }

    /// Async wrapper around the callback-based token acquisition.
    internal func acquireTokenAsync(
        correlationId: UUID
    ) async -> Result<String, MSALNativeCredentialManagementError>
    {
        return await withCheckedContinuation
        { continuation in
            self.acquireToken(correlationId: correlationId)
            { accessToken, tokenError in
                if let tokenError = tokenError
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Failed to acquire access token.",
                        correlationId: correlationId,
                        underlyingError: tokenError
                    )
                    continuation.resume(returning: .failure(credError))
                    return
                }

                guard let accessToken = accessToken else
                {
                    let credError = MSALNativeCredentialManagementError(
                        type: .unauthorized,
                        message: "Token provider returned nil access token.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(credError))
                    return
                }

                continuation.resume(returning: .success(accessToken))
            }
        }
    }

    // MARK: - API Client Access

    /// Returns or creates the internal API client for server communication.
    ///
    /// Client selection priority:
    /// 1. Mock API client — when `UserDefaults` key
    ///    `com.microsoft.identity.credentialmanagement.useMockAPI` is `true`.
    /// 2. Default (`CredentialManagementServerNetworkClient`) — MSIDHttpRequest-backed URLSession transport.
    ///
    /// The mock switch is evaluated on every call so toggling UserDefaults at runtime
    /// takes effect on the next API call (the cached client is invalidated when the
    /// environment changes).
    internal func getAPIClient() -> Result<any CredentialManagementNetworkClientProtocol, MSALNativeCredentialManagementError>
    {
        let useMock = CredentialManagementEnvironment.isMockAPIEnabled

        // Invalidate cached client if mock state changed
        if let existing = apiClient
        {
            let cachedIsMock = existing is CredentialManagementMockNetworkClient
            if cachedIsMock == useMock
            {
                return .success(existing)
            }
            // Mock state flipped — discard cached client
            self.apiClient = nil
        }

        // Mock API takes precedence — no config validation needed
        if useMock
        {
            let mockClient = CredentialManagementMockNetworkClient()
            self.apiClient = mockClient
            return .success(mockClient)
        }

        guard let tenantSubdomain = config.tenantSubdomain,
              let tenantId = config.tenantId,
              let baseURL = URL(string: "https://\(tenantSubdomain).ciamlogin.com/\(tenantId)") else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "tenantSubdomain and tenantId must be set on MSALNativeCredentialManagementConfig."
            ))
        }

        let requestSerializer = CredentialManagementRequestSerializer(
            urlResolver: CredentialManagementURLResolver(baseURL: baseURL),
            sliceConfig: config.sliceConfig
        )

        let client = CredentialManagementServerNetworkClient(
            requestSerializer: requestSerializer,
            requestInterceptor: config.requestInterceptor
        )

        self.apiClient = client
        return .success(client)
    }

    // MARK: - Challenge Handling

    internal func submitRegistrationChallenge(
        code: String,
        continuationToken: String,
        correlationId: UUID
    ) async -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>
    {
        guard !code.isEmpty else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .invalidInput,
                message: "Verification code cannot be empty.",
                correlationId: correlationId
            ))
        }

        // Acquire a fresh token for the activation call
        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        guard case .success(let accessToken) = tokenResult else
        {
            return .failure({ if case .failure(let e) = tokenResult { return e }; fatalError("Unreachable") }())
        }

        let clientResult = getAPIClient()
        guard case .success(let apiClientInstance) = clientResult else
        {
            if case .failure(let error) = clientResult { return .failure(error) }
            fatalError("Unreachable")
        }

        let result = await apiClientInstance.activateEnrollment(
            params: OTPActivationParams(continuationToken: continuationToken, code: code),
            accessToken: accessToken,
            correlationId: correlationId
        )

        switch result
        {
        case .success(let method):
            self.pendingEnrollmentType = nil
            return .success(method)
        case .failure(let error):
            return .failure(error)
        }
    }

    internal func resendRegistrationChallenge(
        continuationToken: String,
        correlationId: UUID
    ) async -> Result<MSALCredentialMethodChallengeState, MSALNativeCredentialManagementError>
    {
        // Acquire token for the re-send call
        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        guard case .success(let accessToken) = tokenResult else
        {
            return .failure({ if case .failure(let e) = tokenResult { return e }; fatalError("Unreachable") }())
        }

        let clientResult = getAPIClient()
        guard case .success(let apiClientInstance) = clientResult else
        {
            if case .failure(let error) = clientResult { return .failure(error) }
            fatalError("Unreachable")
        }

        // Re-enroll to get a new challenge (server re-sends OOB code)
        guard let pendingType = pendingEnrollmentType else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "No pending enrollment type found for resend.",
                correlationId: correlationId
            ))
        }

        // For resend, we use the same enrollment type but the server uses
        // the continuationToken to identify the pending session
        let enrollmentParams: EnrollmentParams
        switch pendingType
        {
        case .phone:
            enrollmentParams = PhoneEnrollmentParams(phoneNumber: "")
        case .password:
            enrollmentParams = PasswordEnrollmentParams(password: "")
        default:
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Resend not supported for type: \(pendingType.rawValue)",
                correlationId: correlationId
            ))
        }

        let result = await apiClientInstance.beginEnrollment(
            params: enrollmentParams,
            accessToken: accessToken,
            correlationId: correlationId
        )

        switch result
        {
        case .success(let response):
            switch response
            {
            case .challengeRequired(let challengeInfo):
                let newState = MSALCredentialMethodChallengeState(
                    sentTo: challengeInfo.sentTo,
                    channelType: challengeInfo.channelType,
                    codeLength: challengeInfo.codeLength,
                    continuationToken: challengeInfo.continuationToken,
                    client: self,
                    correlationId: correlationId
                )
                return .success(newState)

            case .completed(_):
                // Unlikely on resend, but handle gracefully
                let state = MSALCredentialMethodChallengeState(
                    sentTo: nil,
                    channelType: nil,
                    codeLength: nil,
                    continuationToken: continuationToken,
                    client: self,
                    correlationId: correlationId
                )
                return .success(state)

            case .passkeyCreationRequired:
                return .failure(MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: "Unexpected passkey creation response on resend.",
                    correlationId: correlationId
                ))
            }

        case .failure(let error):
            return .failure(error)
        }
    }
}
