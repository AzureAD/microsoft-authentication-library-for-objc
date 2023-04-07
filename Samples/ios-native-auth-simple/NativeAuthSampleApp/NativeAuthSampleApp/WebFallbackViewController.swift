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

    var appContext: MSALNativeAuthPublicClientApplication!
    var legacyAppContext: MSALPublicClientApplication!

    var msalAccount: MSALAccount?
    var webviewParams: MSALWebviewParameters!
    var msalAuthority: MSALAuthority!

    let kClientId = "14de7ba1-6089-4f1a-a72f-896d0388aa43"
    let kAuthority = "https://login.microsoftonline.com/RoCustomers.onmicrosoft.com"

    override func viewDidLoad() {
        super.viewDidLoad()

        appContext = MSALNativeAuthPublicClientApplication(
            configuration: MSALNativeAuthPublicClientApplicationConfig(
                clientId: kClientId,
                authority: URL(string: kAuthority)!,
                tenantName: "tenant"))

        let authority = try! MSALAuthority(url: URL(string: kAuthority)!)

        legacyAppContext = try! MSALPublicClientApplication(
            configuration: MSALPublicClientApplicationConfig(
                clientId: kClientId,
                redirectUri: nil,
                authority: authority))

        webviewParams = MSALWebviewParameters(authPresentationViewController: self)
    }

    func doFallback() {
        let parameters = MSALInteractiveTokenParameters(scopes: ["User.Read"], webviewParameters: webviewParams)
        parameters.authority = msalAuthority

        legacyAppContext.acquireToken(with: parameters) { [self] (result: MSALResult?, error: Error?) in
            if let error = error {
                print("Error acquiring token: \(error)")
                return
            }

            guard let result = result else {
                print("Could not acquire token: No result returned")
                return
            }

            msalAccount = result.account

            updateUI()

            showResultText("Signed in successfully: \(String(describing: msalAccount!.accountClaims!.description))")

            print("Access token is \(result.accessToken)")
        }
    }

    @IBAction func signInPressed(_ sender: Any) {
        doFallback()
    }

    @IBAction func signOutPressed(_ sender: Any) {
        let parameters = MSALSignoutParameters(webviewParameters: webviewParams)

        legacyAppContext.signout(with: msalAccount!, signoutParameters: parameters) { [self] (result: Bool, error: Error?) in
            showResultText("Signed out successfully")

            msalAccount = nil

            updateUI()
        }
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        let signedIn = msalAccount != nil

        if signedIn {
            signInButton.isEnabled = false
            signOutButton.isEnabled = true
        } else {
            signInButton.isEnabled = true
            signOutButton.isEnabled = false
        }
    }
}
