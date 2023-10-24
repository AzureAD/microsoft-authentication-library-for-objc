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

class ResetPasswordViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    var nativeAuth: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?
    var newPasswordViewController: NewPasswordViewController?

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
    }

    @IBAction func resetPasswordPressed(_: Any) {
        guard let email = emailTextField.text, !email.isEmpty
        else {
            resultTextView.text = "Invalid email address"
            return
        }

        print("Resetting password for email \(email)")

        showResultText("")

        nativeAuth.resetPassword(username: email, delegate: self)
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }
}

extension ResetPasswordViewController: ResetPasswordStartDelegate {
    func onResetPasswordCodeRequired(
        newState: MSAL.ResetPasswordCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSALNativeAuthChannelType,
        codeLength _: Int
    ) {
        print("ResetPasswordStartDelegate: onResetPasswordCodeRequired: \(newState)")

        showVerifyCodeModal(submitCallback: { [weak self] code in
                                guard let self = self else { return }

                                newState.submitCode(code: code, delegate: self)
                            },
                            resendCallback: { [weak self] in
                                guard let self = self else { return }

                                newState.resendCode(delegate: self)
                            })
    }

    func onResetPasswordError(error: MSAL.ResetPasswordStartError) {
        switch error.type {
        case .invalidUsername, .userNotFound:
            showResultText("Unable to reset password: The email is invalid")
        case .userDoesNotHavePassword:
            showResultText("Unable to reset password: No password associated with email address")
        default:
            showResultText("Unable to reset password. Error: \(error.errorDescription ?? String(error.type.rawValue))")
        }
    }
}

extension ResetPasswordViewController: ResetPasswordResendCodeDelegate {
    func onResetPasswordResendCodeError(
        error: ResendCodeError,
        newState _: MSAL.ResetPasswordCodeRequiredState?
    ) {
        print("ResetPasswordResendCodeDelegate: onResetPasswordResendCodeError: \(error)")

        showResultText("Unexpected error while requesting new code")
        dismissVerifyCodeModal()
    }

    func onResetPasswordResendCodeRequired(
        newState: MSAL.ResetPasswordCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSALNativeAuthChannelType,
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

extension ResetPasswordViewController: ResetPasswordVerifyCodeDelegate {
    func onResetPasswordVerifyCodeError(
        error: MSAL.VerifyCodeError,
        newState: MSAL.ResetPasswordCodeRequiredState?
    ) {
        switch error.type {
        case .invalidCode:
            guard let newState = newState else {
                print("Unexpected state. Received invalidCode but newState is nil")

                showResultText("Internal error verifying code")
                return
            }

            updateVerifyCodeModal(errorMessage: "Check the code and try again",
                                  submitCallback: { [weak self] code in
                                      guard let self = self else { return }

                                      newState.submitCode(code: code, delegate: self)
                                  }, resendCallback: { [weak self] in
                                      guard let self = self else { return }

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

    func onPasswordRequired(newState: MSAL.ResetPasswordRequiredState) {
        dismissVerifyCodeModal { [self] in
            showNewPasswordModal { [weak self] password in
                guard let self = self else { return }

                newState.submitPassword(password: password, delegate: self)
            }
        }
    }
}

extension ResetPasswordViewController: ResetPasswordRequiredDelegate {
    func onResetPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.ResetPasswordRequiredState?) {
        switch error.type {
        case .invalidPassword:
            guard let newState = newState else {
                print("Unexpected state. Received invalidPassword but newState is nil")

                showResultText("Internal error verifying password")
                return
            }

            updateNewPasswordModal(errorMessage: "Invalid password",
                                   submittedCallback: { password in
                                       newState.submitPassword(password: password, delegate: self)
                                   })
        default:
            showResultText("Error setting password: \(error.errorDescription ?? String(error.type.rawValue))")
            dismissNewPasswordModal()
        }
    }

    func onResetPasswordCompleted() {
        showResultText("Password reset successfully")
        dismissNewPasswordModal()
    }
}

// MARK: - Verify Code modal methods

extension ResetPasswordViewController {
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

    func dismissVerifyCodeModal(completion: (() -> Void)? = nil) {
        guard verifyCodeViewController != nil else {
            print("Unexpected error: Verify Code view controller is nil")
            return
        }

        dismiss(animated: true, completion: completion)
        verifyCodeViewController = nil
    }
}

// MARK: - New Password modal methods

extension ResetPasswordViewController {
    func showNewPasswordModal(submittedCallback: @escaping ((_ password: String) -> Void)) {
        newPasswordViewController = storyboard?.instantiateViewController(
            withIdentifier: "NewPasswordViewController") as? NewPasswordViewController

        guard let newPasswordViewController = newPasswordViewController else {
            print("Error creating password view controller")
            return
        }

        newPasswordViewController.onSubmit = submittedCallback

        present(newPasswordViewController, animated: true)
    }

    func updateNewPasswordModal(
        errorMessage: String?,
        submittedCallback: @escaping ((_ password: String) -> Void)
    ) {
        guard let newPasswordViewController = newPasswordViewController else {
            return
        }

        if let errorMessage = errorMessage {
            newPasswordViewController.errorLabel.text = errorMessage
        }

        newPasswordViewController.onSubmit = { password in
            DispatchQueue.main.async {
                submittedCallback(password)
            }
        }
    }

    func dismissNewPasswordModal() {
        guard newPasswordViewController != nil else {
            print("Unexpected error: Password view controller is nil")
            return
        }

        dismiss(animated: true)

        newPasswordViewController = nil
    }
}
