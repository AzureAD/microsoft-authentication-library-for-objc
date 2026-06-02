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

        // TODO: Replace with actual scopes for credential management API once defined
        let scopes = ["openid", "offline_access"]

        tokenProvider.getAccessToken(scopes: scopes)
        { accessToken, error in
            completion(accessToken, error)
        }
    }

    // MARK: - Challenge Handling

    internal func submitRegistrationChallenge(
        code: String,
        continuationToken: String,
        correlationId: UUID
    ) async -> Result<any MSALCredentialMethodProtocol, MSALNativeCredentialManagementError>
    {
        return await withCheckedContinuation
        { continuation in
            self.operationQueue.async
            { [weak self] in
                guard let self = self else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Client was deallocated.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                guard !code.isEmpty else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .invalidInput,
                        message: "Verification code cannot be empty.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                guard let credential = self.pendingRegistrationCredential else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "No pending registration found.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                self.mockCredentialMethods.append(credential)
                self.pendingRegistrationCredential = nil
                continuation.resume(returning: .success(credential))
            }
        }
    }

    internal func resendRegistrationChallenge(
        continuationToken: String,
        correlationId: UUID
    ) async -> Result<MSALCredentialMethodChallengeState, MSALNativeCredentialManagementError>
    {
        return await withCheckedContinuation
        { continuation in
            self.operationQueue.async
            { [weak self] in
                guard let self = self else
                {
                    let error = MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Client was deallocated.",
                        correlationId: correlationId
                    )
                    continuation.resume(returning: .failure(error))
                    return
                }

                let newState = MSALCredentialMethodChallengeState(
                    sentTo: self.pendingRegistrationCredential?.displayName ?? "***",
                    channelType: self.pendingRegistrationCredential?.credentialType.rawValue,
                    codeLength: 6,
                    continuationToken: "mock-continuation-\(UUID().uuidString.prefix(8))",
                    client: self,
                    correlationId: correlationId
                )
                continuation.resume(returning: .success(newState))
            }
        }
    }

    // MARK: - Mock Data

    internal func seedMockData()
    {
        mockCredentialMethods = [
            MSALPasskeyCredentialMethod(
                id: "passkey-001",
                displayName: "Security Key (YubiKey 5)",
                createdAt: Date(timeIntervalSinceNow: -86400 * 30),
                credentialID: "abc123base64",
                aaguid: "2fc0579f-8113-47ea-b116-bb5a8db9202a"
            ),
            MSALPhoneCredentialMethod(
                id: "phone-001",
                createdAt: Date(timeIntervalSinceNow: -86400 * 60),
                phoneNumber: "+1 *** ***-4589"
            ),
            MSALPasswordCredentialMethod(
                id: "password-001",
                createdAt: Date(timeIntervalSinceNow: -86400 * 90)
            )
        ]
    }
}
