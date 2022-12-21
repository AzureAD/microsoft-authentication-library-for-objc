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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

@_implementationOnly import MSAL_Private

struct MSALNativeSignInPasswordRequestParameters: MSALNativeRequestable {

    let tenant: URL
    let clientId: String
    let endpoint: MSALNativeEndpoint
    let context: MSIDRequestContext
    let correlationId: UUID
    let email: String
    let password: String
    let scope: String
    let granType: MSALNativeGrantType

    var url: URL {
        let baseUrl = tenant.absoluteString
        let endpoint = baseUrl + endpoint.rawValue

        if let url = URL(string: endpoint) {
            return url
        } else {
            MSALLogger.log(level: .error, context: context, format: "Invalid url")
            return tenant
        }
    }
}

// MARK: - Convenience init

extension MSALNativeSignInPasswordRequestParameters {

    init(
        tenant: URL,
        clientId: String,
        email: String,
        password: String,
        scope: String
    ) {
        self.init(
            tenant: tenant,
            clientId: clientId,
            endpoint: .signIn,
            context: MSALNativeContext(),
            correlationId: UUID(),
            email: email,
            password: password,
            scope: scope,
            granType: .password
        )
    }
}
