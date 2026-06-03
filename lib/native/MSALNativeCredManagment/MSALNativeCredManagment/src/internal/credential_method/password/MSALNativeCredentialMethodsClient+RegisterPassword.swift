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
    internal func performRegisterPassword(
        params: MSALRegisterPasswordParams
    ) async -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    {
        let correlationId = params.correlationId ?? UUID()

        CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "performRegisterPassword: starting")

        // Acquire access token
        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        guard case .success(let accessToken) = tokenResult else
        {
            return .failure(tokenResult.failureValue!)
        }

        switch getAPIClient()
        {
        case .failure(let error):
            return .failure(error)
        case .success(let client):
            // Build the enrollment body with password
            let enrollBody: [String: Any] = ["password": params.password]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: enrollBody) else
            {
                return .failure(MSALNativeCredentialManagementError(
                    type: .generalError,
                    message: "Failed to encode password enrollment body.",
                    correlationId: correlationId
                ))
            }

            let enrollResult = await client.beginEnrollment(
                type: .password,
                accessToken: accessToken,
                body: bodyData,
                correlationId: correlationId
            )

            switch enrollResult
            {
            case .success(let halResource):
                let state = halResource.string(forKey: "state")

                // Password registration typically completes in one step
                if state == "completed" || halResource.link(rel: "activate") == nil
                {
                    guard let method = CredentialMethodMapper.parseMethod(from: halResource.properties) else
                    {
                        // If server returned state=completed but no parseable method,
                        // create a password method from what we know
                        let fallbackMethod = MSALPasswordCredentialMethod(
                            id: halResource.string(forKey: "id") ?? UUID().uuidString,
                            createdAt: Date()
                        )
                        return .success(.completed(fallbackMethod))
                    }
                    CredentialManagementLogger.log(level: .info, correlationId: correlationId, message: "performRegisterPassword: completed")
                    return .success(.completed(method))
                }

                // If server requires activation (unlikely for password but handle gracefully)
                guard let continuationToken = halResource.string(forKey: "continuationToken") else
                {
                    return .failure(MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Server did not return continuationToken for password enrollment.",
                        correlationId: correlationId
                    ))
                }

                if let activateLink = halResource.link(rel: "activate")
                {
                    self.pendingActivateHref = activateLink.href
                }
                self.pendingEnrollmentType = .password

                let challengeState = MSALCredentialMethodChallengeState(
                    sentTo: halResource.string(forKey: "sentTo"),
                    channelType: halResource.string(forKey: "channelType"),
                    codeLength: halResource.properties["codeLength"] as? Int,
                    continuationToken: continuationToken,
                    client: self,
                    correlationId: correlationId
                )
                return .success(.challengeRequired(challengeState))

            case .failure(let error):
                return .failure(error)
            }
        }
    }
}
