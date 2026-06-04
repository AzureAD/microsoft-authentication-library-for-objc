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
extension MSALNativeCredentialMethodsClient
{
    internal func performRegisterPassword(
        params: MSALRegisterPasswordParams
    ) async -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    {
        let correlationId = params.correlationId ?? UUID()

        MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "performRegisterPassword: starting")

        // Acquire access token
        let tokenResult = await acquireTokenAsync(correlationId: correlationId)
        guard case .success(let accessToken) = tokenResult else
        {
            return .failure({ if case .failure(let e) = tokenResult { return e }; fatalError("Unreachable") }())
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
            case .success(let response):
                switch response
                {
                case .completed(let method):
                    MSIDLogger.shared().log(level: .info, correlationId: correlationId, message: "performRegisterPassword: completed")
                    return .success(.completed(method))

                case .challengeRequired(let challengeInfo):
                    // Unlikely for password but handle gracefully
                    self.pendingEnrollmentType = .password

                    let challengeState = MSALCredentialMethodChallengeState(
                        sentTo: challengeInfo.sentTo,
                        channelType: challengeInfo.channelType,
                        codeLength: challengeInfo.codeLength,
                        continuationToken: challengeInfo.continuationToken,
                        client: self,
                        correlationId: correlationId
                    )
                    return .success(.challengeRequired(challengeState))

                case .passkeyCreationRequired:
                    return .failure(MSALNativeCredentialManagementError(
                        type: .generalError,
                        message: "Unexpected passkey creation response for password enrollment.",
                        correlationId: correlationId
                    ))
                }

            case .failure(let error):
                return .failure(error)
            }
        }
    }
}
