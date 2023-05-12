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

class CustomAttributesViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!

    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    var appContext: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?

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
            print("Unable to initialize MSAL \(error)")
            showResultText("Unable to initialize MSAL")
        }
    }

    @IBAction func signUpPressed(_: Any) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty
        else {
            resultTextView.text = "Email or password not set"
            return
        }

        var attributes: [String: Any] = [:]

        if let firstName = firstNameTextField.text, !firstName.isEmpty {
            attributes["first_name"] = firstName
        }

        if let lastName = lastNameTextField.text, !lastName.isEmpty {
            attributes["last_name"] = lastName
        }

        print("Signing up with email \(email), password and attributes: \(attributes)")

        appContext.signUp(username: email,
                          password: password,
                          attributes: attributes,
                          delegate: self)
    }

    // MARK: - Verify Code modal methods

    func showVerifyCodeModal(
        submitCallback: @escaping (_ code: String) -> Void,
        resendCallback: @escaping () -> Void
    ) {
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

    func updateVerifyCodeModal(
        errorMessage: String?,
        submitCallback: @escaping (_ code: String) -> Void,
        resendCallback: @escaping () -> Void
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

    func dismissVerifyCodeModal(completion: (() -> Void)? = nil) {
        guard verifyCodeViewController != nil else {
            print("Unexpected error: Verify Code view controller is nil")
            return
        }

        dismiss(animated: true, completion: completion)
        verifyCodeViewController = nil
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }
}

extension CustomAttributesViewController: SignUpStartDelegate {
    func onSignUpError(error: MSAL.SignUpStartError) {
        switch error.type {
        case .userAlreadyExists:
            showResultText("Unable to sign up: User already exists")
        case .invalidPassword:
            showResultText("Unable to sign up: The password is invalid")
        case .invalidUsername:
            showResultText("Unable to sign up: The username is invalid")
        case .invalidAttributes:
            showResultText("Unable to sign up: One or more attributes are invalid")
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

extension CustomAttributesViewController: SignUpVerifyCodeDelegate {
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
        case .browserRequired:
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

extension CustomAttributesViewController: SignUpResendCodeDelegate {
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
