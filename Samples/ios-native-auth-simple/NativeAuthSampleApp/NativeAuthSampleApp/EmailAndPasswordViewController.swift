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

class EmailAndPasswordViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    var appContext: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?

    var signedIn = false

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            appContext = try MSALNativeAuthPublicClientApplication(
                configuration: MSALPublicClientApplicationConfig(
                    clientId: Configuration.clientId,
                    redirectUri: nil,
                    authority: Configuration.authority
                ),
                challengeTypes: [.oob, .password]
            )
        } catch {
            showResultText("Unable to initialize MSAL")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @IBAction func signUpPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing up with email \(email) and password \(password)")

        appContext.signUp(username: email, password: password, delegate: self)
    }

    @IBAction func signInPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "email or password not set"
            return
        }

        print("Signing in with email \(email) and password \(password)")

        signedIn = true

        showResultText("Signed in")

        updateUI()
    }

    @IBAction func signOutPressed(_: Any) {
        signedIn = false

        showResultText("Signed out")

        updateUI()
    }

    func updateVerifyCodeModal(
        errorMessage: String?,
        submitCallback: @escaping ((_ code: String) -> Void),
        resendCallback: @escaping (() -> Void)
    ) {
        guard let verifyCodeViewController else {
            return
        }

        if let errorMessage {
            verifyCodeViewController.errorLabel.text = errorMessage
        }

        verifyCodeViewController.onSubmit = { code in
            DispatchQueue.main.async {
                submitCallback(code)
            }
        }

        verifyCodeViewController.onResend = {
            DispatchQueue.main.async {
                resendCallback()
            }
        }
    }

    func showVerifyCodeModal(
        submitCallback: @escaping ((_ code: String) -> Void),
        resendCallback: @escaping (() -> Void)
    ) {
        guard verifyCodeViewController == nil else {
            print("Unexpected error: Verify Code view controller already exists")
            return
        }

        verifyCodeViewController = storyboard?.instantiateViewController(
            withIdentifier: "VerifyCodeViewController") as? VerifyCodeViewController

        guard let verifyCodeViewController else {
            print("Error creating Verify Code view controller")
            return
        }

        updateVerifyCodeModal(errorMessage: nil,
                              submitCallback: submitCallback,
                              resendCallback: resendCallback)

        present(verifyCodeViewController, animated: true)
    }

    func dismissVerifyCodeModal() {
        guard verifyCodeViewController != nil else {
            print("Unexpected error: Verify Code view controller is nil")
            return
        }

        dismiss(animated: true)
        verifyCodeViewController = nil
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        signUpButton.isEnabled = !signedIn
        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
    }
}

extension EmailAndPasswordViewController: SignUpStartDelegate {
    func onSignUpError(error: MSAL.SignUpStartError) {
        switch error.type {
        case .redirect:
            showResultText("Unable to sign up: Web UX required")
        case .userAlreadyExists:
            showResultText("Unable to sign up: User already exists")
        case .invalidPassword:
            showResultText("Unable to sign up: The password is invalid")
        case .invalidUsername:
            showResultText("Unable to sign up: The username is invalid")
        default:
            showResultText("Unexpected error signing up: \(error.errorDescription ?? String(error.type.rawValue))")
        }
    }

    func onSignUpCodeSent(newState: MSAL.SignUpCodeSentState, displayName _: String, codeLength _: Int) {
        print("SignUpStartDelegate: onSignUpCodeSent: \(newState)")

        showResultText("Email verification required")

        showVerifyCodeModal(submitCallback: { [weak self] code in
                                guard let self else { return }

                                newState.submitCode(code: code, delegate: self)
                            },
                            resendCallback: { [weak self] in
                                guard let self else { return }

                                newState.resendCode(delegate: self)
                            })
    }
}

extension EmailAndPasswordViewController: SignUpVerifyCodeDelegate {
    func onSignUpVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignUpCodeSentState?) {
        switch error.type {
        case .invalidCode:
            guard let newState else {
                print("Unexpected state. Received invalidCode but newState is nil")

                showResultText("Internal error verifying code")
                return
            }

            updateVerifyCodeModal(errorMessage: "Invalid code",
                                  submitCallback: { [weak self] code in
                                      guard let self else { return }

                                      newState.submitCode(code: code, delegate: self)
                                  }, resendCallback: { [weak self] in
                                      guard let self else { return }

                                      newState.resendCode(delegate: self)
                                  })
        case .redirect:
            showResultText("Unable to sign up: Web UX required")
            dismissVerifyCodeModal()
        default:
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? String(error.type.rawValue))")
            dismissVerifyCodeModal()
        }
    }

    func onSignUpAttributesRequired(newState _: MSAL.SignUpAttributesRequiredState) {
        showResultText("Unexpected result while signing up: Attributes Required")
        dismissVerifyCodeModal()
    }

    func onPasswordRequired(newState _: MSAL.SignUpPasswordRequiredState) {
        showResultText("Unexpected result while signing up: Password Required")
        dismissVerifyCodeModal()
    }

    func onSignUpCompleted() {
        showResultText("Signed up successfully!")
        dismissVerifyCodeModal()
    }
}

extension EmailAndPasswordViewController: SignUpResendCodeDelegate {
    func onSignUpResendCodeError(error: MSAL.ResendCodeError, newState _: MSAL.SignUpCodeSentState?) {
        print("ResendCodeSignUpDelegate: onResendCodeSignUpError: \(error)")

        showResultText("Unexpected error while requesting new code")
        dismissVerifyCodeModal()
    }

    func onSignUpResendCodeSent(newState: MSAL.SignUpCodeSentState, displayName _: String, codeLength _: Int) {
        updateVerifyCodeModal(errorMessage: nil,
                              submitCallback: { [weak self] code in
                                  guard let self else { return }

                                  newState.submitCode(code: code, delegate: self)
                              }, resendCallback: { [weak self] in
                                  guard let self else { return }

                                  newState.resendCode(delegate: self)
                              })
    }
}
