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

    var nativeAuth: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?

    var accountResult: MSALNativeAuthUserAccountResult?

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

        retrieveCachedAccount()
    }

    @IBAction func signUpPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing up with email \(email) and password")

        nativeAuth.signUpUsingPassword(username: email, password: password, delegate: self)
    }

    @IBAction func signInPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing in with email \(email) and password")

        nativeAuth.signInUsingPassword(username: email, password: password, delegate: self)
    }

    @IBAction func signOutPressed(_: Any) {
        guard accountResult != nil else {
            print("signOutPressed: Not currently signed in")
            return
        }
        accountResult?.signOut()

        accountResult = nil

        showResultText("Signed out")

        updateUI()
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        let signedIn = (accountResult != nil)

        signUpButton.isEnabled = !signedIn
        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
    }

    func retrieveCachedAccount() {
        accountResult = nativeAuth.getNativeAuthUserAccount()
        if let accountResult = accountResult, let homeAccountId = accountResult.account.homeAccountId?.identifier {
            print("Account found in cache: \(homeAccountId)")

            accountResult.getAccessToken(delegate: self)
        } else {
            print("No account found in cache")
        }
    }
}

// MARK: - Sign Up delegates

// MARK: SignUpPasswordStartDelegate

extension EmailAndPasswordViewController: SignUpPasswordStartDelegate {
    func onSignUpPasswordError(error: MSAL.SignUpPasswordStartError) {
        switch error.type {
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

    func onSignUpCodeRequired(newState: MSAL.SignUpCodeRequiredState,
                              sentTo _: String,
                              channelTargetType _: MSAL.MSALNativeAuthChannelType,
                              codeLength _: Int) {
        print("SignUpPasswordStartDelegate: onSignUpCodeRequired: \(newState)")

        showVerifyCodeModal(submitCallback: { [weak self] code in
                                guard let self = self else { return }

                                newState.submitCode(code: code, delegate: self)
                            },
                            resendCallback: { [weak self] in
                                guard let self = self else { return }

                                newState.resendCode(delegate: self)
                            })
    }
}

// MARK: SignUpVerifyCodeDelegate

extension EmailAndPasswordViewController: SignUpVerifyCodeDelegate {
    func onSignUpVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        switch error.type {
        case .invalidCode:
            guard let newState = newState else {
                print("Unexpected state. Received invalidCode but newState is nil")

                showResultText("Internal error verifying code")
                return
            }

            updateVerifyCodeModal(errorMessage: "Invalid code",
                                  submitCallback: { [weak self] code in
                                      guard let self = self else { return }

                                      newState.submitCode(code: code, delegate: self)
                                  }, resendCallback: { [weak self] in
                                      guard let self = self else { return }

                                      newState.resendCode(delegate: self)
                                  })
        default:
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? String(error.type.rawValue))")
            dismissVerifyCodeModal()
        }
    }

    func onSignUpCompleted(newState: MSAL.SignInAfterSignUpState) {
        showResultText("Signed up successfully!")
        dismissVerifyCodeModal()

        newState.signIn(delegate: self)
    }
}

// MARK: SignUpResendCodeDelegate

extension EmailAndPasswordViewController: SignUpResendCodeDelegate {
    func onSignUpResendCodeError(error: ResendCodeError) {
        print("ResendCodeSignUpDelegate: onResendCodeSignUpError: \(error)")

        showResultText("Unexpected error while requesting new code")
        dismissVerifyCodeModal()
    }

    func onSignUpResendCodeCodeRequired(
        newState: MSAL.SignUpCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSAL.MSALNativeAuthChannelType,
        codeLength _: Int
    ) {
        updateVerifyCodeModal(errorMessage: nil,
                              submitCallback: { [weak self] code in
                                  guard let self = self else { return }

                                  newState.submitCode(code: code, delegate: self)
                              }, resendCallback: { [weak self] in
                                  guard let self = self else { return }

                                  newState.resendCode(delegate: self)
                              })
    }
}

// MARK: SignInAfterSignUpDelegate

extension EmailAndPasswordViewController: SignInAfterSignUpDelegate {
    func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {
        showResultText("Error signing in after signing up.")
    }
}

// MARK: - Sign In delegates

// MARK: SignInPasswordStartDelegate

extension EmailAndPasswordViewController: SignInPasswordStartDelegate {
    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        print("Signed in: \(result.account.username ?? "")")

        accountResult = result

        result.getAccessToken(delegate: self)
    }

    func onSignInPasswordError(error: MSAL.SignInPasswordStartError) {
        print("SignInPasswordStartDelegate: onSignInPasswordError: \(error)")

        switch error.type {
        case .userNotFound, .invalidPassword, .invalidUsername:
            showResultText("Invalid username or password")
        default:
            showResultText("Error while signing in: \(error.errorDescription ?? String(error.type.rawValue))")
        }
    }
}

// MARK: - Credentials delegates

// MARK: CredentialsDelegate

extension EmailAndPasswordViewController: CredentialsDelegate {
    func onAccessTokenRetrieveCompleted(accessToken: String) {
        print("Access Token: \(accessToken)")
        showResultText("Signed in successfully. Access Token: \(accessToken)")
        updateUI()
    }

    func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        showResultText("Error retrieving access token: \(error.errorDescription ?? String(error.type.rawValue))")
    }
}

// MARK: - Verify Code modal methods

extension EmailAndPasswordViewController {
    func showVerifyCodeModal(
        submitCallback: @escaping (_ code: String) -> Void,
        resendCallback: @escaping () -> Void
    ) {
        verifyCodeViewController = storyboard?.instantiateViewController(
            withIdentifier: "VerifyCodeViewController") as? VerifyCodeViewController

        guard let verifyCodeViewController = verifyCodeViewController else {
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
        guard let verifyCodeViewController = verifyCodeViewController else {
            return
        }

        if let errorMessage = errorMessage {
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

    func dismissVerifyCodeModal() {
        guard verifyCodeViewController != nil else {
            print("Unexpected error: Verify Code view controller is nil")
            return
        }

        dismiss(animated: true)
        verifyCodeViewController = nil
    }
}
