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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import MSAL
import UIKit

class WebFallbackViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    var nativeAuth: MSALNativeAuthPublicClientApplication!
    var webviewParams: MSALWebviewParameters!

    var accountResult: MSALNativeAuthUserAccountResult?
    var msalAccount: MSALAccount?

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            nativeAuth = try MSALNativeAuthPublicClientApplication(
                clientId: Configuration.clientId,
                tenantSubdomain: Configuration.tenantSubdomain,
                challengeTypes: [.OOB, .password]
            )
        } catch {
            print("Unable to initialize MSAL \(error)")
            showResultText("Unable to initialize MSAL")
        }

        webviewParams = MSALWebviewParameters(authPresentationViewController: self)
    }

    @IBAction func signInPressed(_: Any) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty
        else {
            resultTextView.text = "Invalid email address or password"
            return
        }

        print("Signing in with email \(email) and password")

        nativeAuth.signInUsingPassword(username: email, password: password, delegate: self)
    }

    @IBAction func signOutPressed(_: Any) {
        if msalAccount != nil {
            signOutWithWebUX()
        } else if accountResult != nil {
            accountResult?.signOut()

            accountResult = nil

            showResultText("Signed out")

            updateUI()
        }
    }

    fileprivate func showResultText(_ text: String) {
        resultTextView.text = text
    }

    fileprivate func updateUI() {
        let signedIn = msalAccount != nil || accountResult != nil

        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
    }

    fileprivate func signInWithWebUX() {
        let parameters = MSALInteractiveTokenParameters(scopes: ["User.Read"], webviewParameters: webviewParams)

        nativeAuth.acquireToken(with: parameters) { [weak self] (result: MSALResult?, error: Error?) in
            guard let self = self else { return }

            if let error = error {
                self.showResultText("Error acquiring token: \(error)")
                return
            }

            self.msalAccount = result?.account

            guard let msalAccount = self.msalAccount else {
                self.showResultText("Could not acquire token: No result or account returned")
                return
            }

            self.updateUI()

            self.showResultText("Signed in successfully with Web UX: \(msalAccount.accountClaims!.description)")
        }
    }

    fileprivate func signOutWithWebUX() {
        let parameters = MSALSignoutParameters(webviewParameters: webviewParams)
        parameters.signoutFromBrowser = true

        nativeAuth.signout(
            with: msalAccount!,
            signoutParameters: parameters
        ) { [weak self] (result: Bool, error: Error?) in
            guard let self = self else { return }

            if let error = error {
                self.showResultText("Error signing out: \(error)")
                return
            }

            if !result {
                self.showResultText("Error signing out: Method returned false")
                return
            }

            self.showResultText("Signed out successfully")
            self.msalAccount = nil

            self.updateUI()
        }
    }
}

// MARK: - Sign In delegates

extension WebFallbackViewController: SignInPasswordStartDelegate {
    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        accountResult = result
        result.getAccessToken(delegate: self)
    }

    func onSignInPasswordError(error: MSAL.SignInPasswordStartError) {
        print("SignInPasswordStartDelegate: onSignInPasswordError: \(error)")

        switch error.type {
        case .userNotFound, .invalidUsername:
            showResultText("Invalid username or password")
        case .browserRequired:
            signInWithWebUX()
        default:
            showResultText("Error while signing in: \(error.errorDescription ?? String(error.type.rawValue))")
        }
    }
}

// MARK: - Credentials Delegate methods

extension WebFallbackViewController: CredentialsDelegate {
    func onAccessTokenRetrieveCompleted(accessToken: String) {
        print("Access Token: \(accessToken)")
        showResultText("Signed in successfully. Access Token: \(accessToken)")
        updateUI()
    }

    func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        showResultText("Error retrieving access token: \(error.errorDescription ?? String(error.type.rawValue))")
    }
}
