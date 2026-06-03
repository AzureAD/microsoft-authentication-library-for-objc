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
    internal func getAPIClient() -> Result<CredentialManagementAPIClient, MSALNativeCredentialManagementError>
    {
        if let existing = apiClient
        {
            return .success(existing)
        }

        guard let baseURL = config.baseURL else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .invalidConfiguration,
                message: "baseURL must be set on MSALNativeCredentialManagementConfig."
            ))
        }

        let client = CredentialManagementAPIClient(
            baseURL: baseURL,
            networkClient: networkClient
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
            return .failure(tokenResult.failureValue!)
        }

        let clientResult = getAPIClient()
        guard case .success(let apiClientInstance) = clientResult else
        {
            if case .failure(let error) = clientResult { return .failure(error) }
            fatalError("Unreachable")
        }

        // Build the activation body with continuationToken and code
        let activationBody: [String: Any] = [
            "continuationToken": continuationToken,
            "oob": code
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: activationBody) else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Failed to encode activation request body.",
                correlationId: correlationId
            ))
        }

        // Use the activate href stored in the challenge state
        // The activate link was captured during enrollment
        guard let activateHref = pendingActivateHref else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "No pending activation link found.",
                correlationId: correlationId
            ))
        }

        let result = await apiClientInstance.activateEnrollment(
            activateHref: activateHref,
            accessToken: accessToken,
            body: bodyData,
            correlationId: correlationId
        )

        switch result
        {
        case .success(let halResource):
            let json = halResource.properties
            guard let method = CredentialMethodMapper.parseMethod(from: json) else
            {
                return .failure(MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: "Failed to parse registered method from activation response.",
                    correlationId: correlationId
                ))
            }
            self.pendingActivateHref = nil
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
            return .failure(tokenResult.failureValue!)
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

        let resendBody: [String: Any] = ["continuationToken": continuationToken]
        let bodyData = try? JSONSerialization.data(withJSONObject: resendBody)

        let result = await apiClientInstance.beginEnrollment(
            type: pendingType,
            accessToken: accessToken,
            body: bodyData,
            correlationId: correlationId
        )

        switch result
        {
        case .success(let halResource):
            let newContinuationToken = halResource.string(forKey: "continuationToken") ?? continuationToken

            if let activateLink = halResource.link(rel: "activate")
            {
                self.pendingActivateHref = activateLink.href
            }

            let newState = MSALCredentialMethodChallengeState(
                sentTo: halResource.string(forKey: "sentTo"),
                channelType: halResource.string(forKey: "channelType"),
                codeLength: halResource.properties["codeLength"] as? Int,
                continuationToken: newContinuationToken,
                client: self,
                correlationId: correlationId
            )
            return .success(newState)

        case .failure(let error):
            return .failure(error)
        }
    }
}
