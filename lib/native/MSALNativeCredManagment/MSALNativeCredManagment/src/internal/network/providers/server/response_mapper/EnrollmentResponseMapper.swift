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

/// Maps a successful credential management response into a `MSIDHALResource`.
/// Used for enrollment (begin and activate) responses.
internal enum EnrollmentResponseMapper
{
    static func map(
        _ response: CredentialManagementResponse,
        correlationId: UUID
    ) -> Result<MSIDHALResource, MSALNativeCredentialManagementError>
    {
        guard let json = response.jsonBody else
        {
            return .failure(MSALNativeCredentialManagementError(
                type: .generalError,
                message: "Response body is empty or not valid JSON.",
                correlationId: correlationId
            ))
        }

        return .success(MSIDHALResource(json: json))
    }
}
