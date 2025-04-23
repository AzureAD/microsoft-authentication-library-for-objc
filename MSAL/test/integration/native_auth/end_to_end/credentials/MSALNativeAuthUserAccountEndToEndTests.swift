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
import XCTest
import MSAL

final class MSALNativeAuthUserAccountEndToEndTests: MSALNativeAuthEndToEndPasswordTestCase {

    // Sign in with username and password to get access token and force refresh
    func test_signInAndForceRefreshSucceeds() async throws {
#if os(macOS)
        throw XCTSkip("Bundle id for macOS is not added to the client id, test is not needed on both iOS and macOS")
#endif
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let param = MSALNativeAuthSignInParameters(username: username)
        param.password = password
        param.correlationId = correlationId
        sut.signIn(parameters: param, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)

        let previousIdToken = signInDelegateSpy.result?.idToken
        let refreshAccessTokenExpectation = expectation(description: "refreshing access token")
        let credentialsDelegateSpy = CredentialsDelegateSpy(expectation: refreshAccessTokenExpectation)

        let tokenParam = MSALNativeAuthGetAccessTokenParameters()
        tokenParam.forceRefresh = true
        signInDelegateSpy.result?.getAccessToken(parameters: tokenParam, delegate: credentialsDelegateSpy)

        await fulfillment(of: [refreshAccessTokenExpectation])

        XCTAssertTrue(credentialsDelegateSpy.onAccessTokenRetrieveCompletedCalled)
        XCTAssertNotNil(credentialsDelegateSpy.result?.accessToken)
        XCTAssertNotEqual(previousIdToken, signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)
    }

    // Sign in with username and password to get access token and force refresh with access token not linked to client Id
    func test_signInAndForceRefreshWithNotConfiguredScopes() async throws {
#if os(macOS)
        throw XCTSkip("Bundle id for macOS is not added to the client id, test is not needed on both iOS and macOS")
#endif
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let signInParam = MSALNativeAuthSignInParameters(username: username)
        signInParam.password = password
        signInParam.correlationId = correlationId
        sut.signIn(parameters: signInParam, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)

        let refreshAccessTokenExpectation = expectation(description: "refreshing access token")
        let credentialsDelegateSpy = CredentialsDelegateSpy(expectation: refreshAccessTokenExpectation)

        let tokenParam = MSALNativeAuthGetAccessTokenParameters()
        tokenParam.scopes = ["Calendar.Read"]
        tokenParam.forceRefresh = true
        signInDelegateSpy.result?.getAccessToken(parameters: tokenParam, delegate: credentialsDelegateSpy)

        await fulfillment(of: [refreshAccessTokenExpectation])

        XCTAssertTrue(credentialsDelegateSpy.onAccessTokenRetrieveErrorCalled)
        XCTAssertTrue(credentialsDelegateSpy.error!.errorDescription!.contains("Send an interactive authorization request for this user and resource."))
    }
    
    // Sign in with username and password with extra scopes to get access token and validate the scopes
    func test_signInWithExtraScopes() async throws {
#if os(macOS)
        throw XCTSkip("Bundle id for macOS is not added to the client id, test is not needed on both iOS and macOS")
#endif
        guard let sut = initialisePublicClientApplication(), let username = retrieveUsernameForSignInUsernameAndPassword(), let password = await retrievePasswordForSignInUsername() else {
            XCTFail("Missing information")
            return
        }

        let signInExpectation = expectation(description: "signing in")
        let signInDelegateSpy = SignInPasswordStartDelegateSpy(expectation: signInExpectation)

        let params = MSALNativeAuthSignInParameters(username: username)
        params.password = password
        params.scopes = ["User.Read"]
        params.correlationId = correlationId
        sut.signIn(parameters: params, delegate: signInDelegateSpy)

        await fulfillment(of: [signInExpectation])

        XCTAssertTrue(signInDelegateSpy.onSignInCompletedCalled)
        XCTAssertNotNil(signInDelegateSpy.result?.idToken)
        XCTAssertEqual(signInDelegateSpy.result?.account.username, username)

        let getAccessTokenExpectation = expectation(description: "getting access token")
        let credentialsDelegateSpy = CredentialsDelegateSpy(expectation: getAccessTokenExpectation)

        let getTokenParam = MSALNativeAuthGetAccessTokenParameters()
        getTokenParam.scopes = ["User.Read"]
        signInDelegateSpy.result?.getAccessToken(parameters: getTokenParam, delegate: credentialsDelegateSpy)

        await fulfillment(of: [getAccessTokenExpectation])

        XCTAssertTrue(credentialsDelegateSpy.onAccessTokenRetrieveCompletedCalled)
        XCTAssertNotNil(credentialsDelegateSpy.result?.accessToken)
        XCTAssertNotNil(credentialsDelegateSpy.result?.scopes)
        XCTAssertTrue(credentialsDelegateSpy.result!.scopes.contains("User.Read"))
    }
}
