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

/// Encapsulates the parameters passed to the signUpV2 method of MSALNativeAuthPublicClientApplication.
///
/// The email address is sent as `username` when sign-up starts, never as a user attribute.
/// A server request to collect email as an attribute results in a general error.
/// Supplied password and profile attributes are retained through verification and submitted when requested.
///
/// - Warning: This API is experimental. It may be changed in the future without notice. Do not use in production applications.
@objcMembers
public class MSALNativeAuthSignUpParametersV2: MSALNativeAuthSignUpParameters {

    /// Permissions you want included in the access token received once the account is signed in
    /// at the end of the sign up flow.
    /// Not all scopes are guaranteed to be included in the access token returned.
    public var scopes: [String]?

    /// The claims parameter that needs to be sent to the service.
    public var claimsRequest: MSALClaimsRequest?

    public override init(username: String) {
        super.init(username: username)
    }
}
