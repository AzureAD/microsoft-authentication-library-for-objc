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

class EmailAndPasswordViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    var appContext: MSALNativeAuthPublicClientApplication!

    var otpViewController: OTPViewController?

    var signedIn = false

    let kClientId = "14de7ba1-6089-4f1a-a72f-896d0388aa43"
    let kAuthority = "https://login.microsoftonline.com/RoCustomers.onmicrosoft.com"

    override func viewDidLoad() {
        super.viewDidLoad()

        let authority = try! MSALAuthority(url: URL(string: kAuthority)!)

        appContext = try! MSALNativeAuthPublicClientApplication(
            configuration: MSALPublicClientApplicationConfig(
                clientId: kClientId,
                redirectUri: nil,
                authority: authority),
                challengeTypes: [.oob, .password])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // TODO: Call appContext.getUserAccount() and update UI accordingly
    }

    @IBAction func signUpTapped(_ sender: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "email or password not set"
            return
        }

        print("Signing up with email \(email) and password \(password)")
    }

    @IBAction func signInTapped(_ sender: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "email or password not set"
            return
        }

        print("Signing in with email \(email) and password \(password)")

        showOTPModal(submittedCallback: { [self] otp in
            showResultText("Submitted OTP: \(otp)")
            dismiss(animated: true)
        }, resendCodeCallback: { [self] in
            showResultText("Resending code")
        })
    }

    @IBAction func signOutTapped(_ sender: Any) {
        signedIn = false

        showResultText("Signed out")

        updateUI()
    }

    func showOTPModal(submittedCallback: @escaping ((_ otp: String) -> Void), resendCodeCallback: @escaping (() -> Void)) {
        otpViewController = storyboard?.instantiateViewController(withIdentifier: "OTPViewController") as? OTPViewController

        guard let otpViewController = otpViewController else {
            return
        }

        otpViewController.otpSubmittedCallback = { otp in
            DispatchQueue.main.async {
                submittedCallback(otp)
            }
        }

        otpViewController.resendCodeCallback = {
            DispatchQueue.main.async {
                resendCodeCallback()
            }
        }

        present(otpViewController, animated: true)
    }

    func showOTPErrorMessage(_ message: String) {
        otpViewController?.errorLabel.text = message
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        if signedIn {
            signUpButton.isEnabled = false
            signInButton.isEnabled = false
            signOutButton.isEnabled = true
        } else {
            signUpButton.isEnabled = true
            signInButton.isEnabled = true
            signOutButton.isEnabled = false
        }
    }

}
