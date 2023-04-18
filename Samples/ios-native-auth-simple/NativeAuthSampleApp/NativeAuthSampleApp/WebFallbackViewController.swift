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

import UIKit
import MSAL

class WebFallbackViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    fileprivate var appContext: MSALNativeAuthPublicClientApplication!

    fileprivate var msalAccount: MSALAccount?
    fileprivate var webviewParams: MSALWebviewParameters!

    override func viewDidLoad() {
        super.viewDidLoad()

        let authority = try! MSALAuthority(url: URL(string: Configuration.authority)!)

        appContext = try! MSALNativeAuthPublicClientApplication(
            configuration: MSALPublicClientApplicationConfig(
                clientId: Configuration.clientId,
                redirectUri: nil,
                authority: authority),
                challengeTypes: [.oob, .password])

        webviewParams = MSALWebviewParameters(authPresentationViewController: self)
    }

    @IBAction func signInPressed(_ sender: Any) {
        performMSALSignIn()
    }

    @IBAction func signOutPressed(_ sender: Any) {
        performMSALSignOut()
    }

    fileprivate func showResultText(_ text: String) {
        resultTextView.text = text
    }

    fileprivate func updateUI() {
        let signedIn = msalAccount != nil

        if signedIn {
            signInButton.isEnabled = false
            signOutButton.isEnabled = true
        } else {
            signInButton.isEnabled = true
            signOutButton.isEnabled = false
        }
    }

    fileprivate func performMSALSignIn() {
        let parameters = MSALInteractiveTokenParameters(scopes: ["User.Read"], webviewParameters: webviewParams)

        appContext.acquireToken(with: parameters) { [weak self] (result: MSALResult?, error: Error?) in
            guard let self = self else { return }

            if let error = error {
                showResultText("Error acquiring token: \(error)")
                return
            }

            msalAccount = result?.account

            guard let msalAccount = msalAccount else {
                showResultText("Could not acquire token: No result or account returned")
                return
            }

            updateUI()

            showResultText("Signed in successfully: \( msalAccount.accountClaims!.description)")
        }
    }

    fileprivate func performMSALSignOut() {
        let parameters = MSALSignoutParameters(webviewParameters: webviewParams)
        parameters.signoutFromBrowser = true

        appContext.signout(with: msalAccount!, signoutParameters: parameters) { [weak self] (result: Bool, error: Error?) in
            guard let self = self else { return }

            if let error = error {
                showResultText("Error signing out: \(error)")
                return
            }

            if !result {
                showResultText("Error signing out: Method returned false")
                return
            }

            showResultText("Signed out successfully")
            msalAccount = nil

            updateUI()
        }
    }
}
