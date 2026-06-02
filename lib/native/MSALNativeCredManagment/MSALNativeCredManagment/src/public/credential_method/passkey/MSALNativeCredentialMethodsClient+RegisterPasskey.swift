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
    internal func performRegisterPasskey(
        params: MSALRegisterPasskeyParams?
    ) async -> Result<MSALCredentialMethodRegistrationResult, MSALNativeCredentialManagementError>
    {
        let correlationId = params?.correlationId ?? UUID()

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

                self.acquireToken(correlationId: correlationId)
                { accessToken, tokenError in
                    if let tokenError = tokenError
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Failed to acquire access token for registering credential method.",
                            correlationId: correlationId,
                            underlyingError: tokenError
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    guard accessToken != nil else
                    {
                        let credError = MSALNativeCredentialManagementError(
                            type: .unauthorized,
                            message: "Token provider returned nil access token.",
                            correlationId: correlationId
                        )
                        continuation.resume(returning: .failure(credError))
                        return
                    }

                    // Mock: passkey registration completes immediately
                    let method = MSALPasskeyCredentialMethod(
                        id: "passkey-\(UUID().uuidString.prefix(8))",
                        displayName: params?.displayName,
                        createdAt: Date(),
                        credentialID: nil,
                        aaguid: nil
                    )
                    self.mockCredentialMethods.append(method)
                    continuation.resume(returning: .success(.completed(method)))
                }
            }
        }
    }
}
