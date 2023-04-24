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

    var otpViewController: OTPViewController?

    var account: MSALNativeAuthUserAccount?

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            nativeAuth = try MSALNativeAuthPublicClientApplication(
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

        nativeAuth.signUp(username: email, password: password, delegate: self)
    }

    @IBAction func signInPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "email or password not set"
            return
        }

        print("Signing in with email \(email) and password \(password)")

        nativeAuth.signIn(username: email, password: password, delegate: self)
    }

    @IBAction func signOutPressed(_: Any) {
        guard account != nil else {
            print("signOutPressed: Not currently signed in")
            return
        }

        account = nil

        showResultText("Signed out")

        updateUI()
    }

    func updateOTPModal(
        errorMessage: String?,
        submittedCallback: @escaping ((_ otp: String) -> Void),
        resendCodeCallback: @escaping (() -> Void)
    ) {
        guard let otpViewController = otpViewController else {
            return
        }

        if let errorMessage {
            otpViewController.errorLabel.text = errorMessage
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
    }

    func showOTPModal(
        submittedCallback: @escaping ((_ otp: String) -> Void),
        resendCodeCallback: @escaping (() -> Void)
    ) {
        guard otpViewController == nil else {
            print("Unexpected error: OTP view controller already exists")
            return
        }

        otpViewController = storyboard?.instantiateViewController(
            withIdentifier: "OTPViewController") as? OTPViewController

        guard let otpViewController = otpViewController else {
            print("Error creating OTP view controller")
            return
        }

        updateOTPModal(errorMessage: nil,
                       submittedCallback: submittedCallback,
                       resendCodeCallback: resendCodeCallback)

        present(otpViewController, animated: true)
    }

    func dismissOTPModal() {
        guard otpViewController != nil else {
            print("Unexpected error: OTP view controller is nil")
            return
        }

        dismiss(animated: true)
        otpViewController = nil
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        let signedIn = (account != nil)

        signUpButton.isEnabled = !signedIn
        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
    }
}
// MARK: - Sign Up delegates

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

        showOTPModal(submittedCallback: { [weak self] otp in
                         guard let self else { return }

                         newState.submitCode(code: otp, delegate: self)
                     },
                     resendCodeCallback: { [weak self] in
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

            updateOTPModal(errorMessage: "Check the code and try again",
                           submittedCallback: { [weak self] otp in
                               guard let self else { return }

                               newState.submitCode(code: otp, delegate: self)
                           }, resendCodeCallback: { [weak self] in
                               guard let self else { return }

                               newState.resendCode(delegate: self)
                           })
        case .redirect:
            showResultText("Unable to sign up: Web UX required")
            dismissOTPModal()
        default:
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? String(error.type.rawValue))")
            dismissOTPModal()
        }
    }

    func onSignUpAttributesRequired(newState _: MSAL.SignUpAttributesRequiredState) {
        showResultText("Unexpected result while signing up: Attributes Required")
        dismissOTPModal()
    }

    func onPasswordRequired(newState _: MSAL.SignUpPasswordRequiredState) {
        showResultText("Unexpected result while signing up: Password Required")
        dismissOTPModal()
    }

    func onSignUpCompleted() {
        showResultText("Signed up successfully!")
        dismissOTPModal()
    }
}

extension EmailAndPasswordViewController: SignUpResendCodeDelegate {
    func onSignUpResendCodeError(error: MSAL.ResendCodeError, newState _: MSAL.SignUpCodeSentState?) {
        print("ResendCodeSignUpDelegate: onResendCodeSignUpError: \(error)")

        showResultText("Unexpected error while requesting new code")
        dismissOTPModal()
    }

    func onSignUpResendCodeSent(newState: MSAL.SignUpCodeSentState, displayName _: String, codeLength _: Int) {


        updateOTPModal(errorMessage: nil,
                       submittedCallback: { [weak self] otp in
                           guard let self else { return }

                           newState.submitCode(code: otp, delegate: self)
                       }, resendCodeCallback: { [weak self] in
                           guard let self else { return }

                           newState.resendCode(delegate: self)
                       })
    }
}

// MARK: - Sign In delegates

extension EmailAndPasswordViewController: SignInStartDelegate {
    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccount) {
        showResultText("Signed in successfully. Access Token: \(result.accessToken)")

        account = result

        updateUI()
    }

    func onSignInError(error: MSAL.SignInStartError) {
        print("SignInStartDelegate: onSignInError: \(error)")

        switch error.type {
        case .userNotFound, .invalidPassword, .invalidUsername:
            showResultText("Invalid username or password")
        default:
            showResultText("Error while signing in: \(error.errorDescription ?? String(error.type.rawValue))")
        }
    }

    func onSignInCodeSent(newState: MSAL.SignInCodeSentState, displayName: String, codeLength: Int) {
        showResultText("Unexpected result while signing in: Verification required")
    }
}
// MARK: - Sign In delegates
extension EmailAndPasswordViewController: SignInStartDelegate {
    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccount) {
        showResultText("Signed in successfully. Access Token: \(result.accessToken)")

        account = result

        updateUI()
    }

    func onSignInError(error: MSAL.SignInStartError) {
        print("SignInStartDelegate: onSignInError: \(error)")

        switch error.type {
        case .userNotFound, .invalidPassword, .invalidUsername:
            showResultText("Invalid username or password")
        default:
            showResultText("Error while signing in: \(error.errorDescription ?? String(error.type.rawValue))")
        }
    }

    func onSignInCodeSent(newState: MSAL.SignInCodeSentState, displayName: String, codeLength: Int) {
        showResultText("Unexpected result while signing in: Verification required")
    }
}

// MARK: - Sign In delegates

extension EmailAndPasswordViewController: SignInStartDelegate {
    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccount) {
        showResultText("Signed in successfully. Access Token: \(result.accessToken)")

        account = result

        updateUI()
    }

    func onSignInError(error: MSAL.SignInStartError) {
        print("SignInStartDelegate: onSignInError: \(error)")

        switch error.type {
        case .userNotFound, .invalidPassword, .invalidUsername:
            showResultText("Invalid username or password")
        default:
            showResultText("Error while signing in: \(error.errorDescription ?? String(error.type.rawValue))")
        }
    }

    func onSignInCodeSent(newState: MSAL.SignInCodeSentState, displayName: String, codeLength: Int) {
        showResultText("Unexpected result while signing in: Verification required")
    }
}
