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

import UIKit

final class PasswordResetViewController: UIViewController {

    struct Data {
        let clientAuthSdk: IClientAuthSDKCommunicator
        let referenceId: String
        let email: String
    }

    // MARK: - Outlets

    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var repeatPasswordTextField: UITextField!
    @IBOutlet private weak var updatePasswordButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!

    // MARK: - Variables

    private var data: Data?

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Private methods

    private func setupUI() {
        title = "Password Reset"
        navigationController?.navigationBar.prefersLargeTitles = false

        updatePasswordButton.isEnabled = false

        addKeyboardHandling(scrollView: scrollView)

        configurePasswordTextField(passwordTextField, newPassword: true)
        configurePasswordTextField(repeatPasswordTextField, newPassword: false)
    }

    private func configurePasswordTextField(_ textField: UITextField, newPassword: Bool) {
        textField.layer.borderColor = UIColor.red.cgColor
        textField.isSecureTextEntry = true
        textField.textContentType = newPassword ? .newPassword : .password
        textField.rightViewMode = .always
        textField.autocorrectionType = .no
        textField.rightView =
            newPassword
            ? makeToggleSecureEntryButton(action: #selector(passwordSecureEntryButtonDidTap))
            : makeToggleSecureEntryButton(action: #selector(repeatPasswordSecureEntryButtonDidTap))
        textField.addTarget(
            self,
            action: #selector(textFieldDidChange),
            for: UIControl.Event.editingChanged
        )
    }

    private func makeToggleSecureEntryButton(action: Selector) -> UIButton {
        let button = UIButton(frame: .init(x: 0, y: 0, width: 30, height: 30))
        button.setImage(UIImage(systemName: "eye.slash.fill"), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)

        return button
    }

    // MARK: - Actions

    @objc private func passwordSecureEntryButtonDidTap() {
        toggleSecureEntryButton(textField: passwordTextField)
    }

    @objc private func repeatPasswordSecureEntryButtonDidTap() {
        toggleSecureEntryButton(textField: repeatPasswordTextField)
    }

    private func toggleSecureEntryButton(textField: UITextField) {
        textField.isSecureTextEntry.toggle()
        let buttonImage = UIImage(
            systemName: textField.isSecureTextEntry ? "eye.slash.fill" : "eye.fill")
        (textField.rightView as? UIButton)?.setImage(buttonImage, for: .normal)
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        let isPasswordValid = FieldValidator.check(.password(passwordTextField.text))
        let isPasswordRepeatValid =
            FieldValidator.check(.repeatPassword(repeatPasswordTextField.text))
            && passwordTextField.text == repeatPasswordTextField.text

        switch textField {
        case passwordTextField:
            passwordTextField.layer.borderWidth = isPasswordValid ? 0 : 1
        case repeatPasswordTextField:
            repeatPasswordTextField.layer.borderWidth = isPasswordRepeatValid ? 0 : 1
        default:
            break
        }

        updatePasswordButton.isEnabled = isPasswordValid && isPasswordRepeatValid
    }

    @IBAction private func updatePasswordButtonDidTap(_ sender: UIButton) {
        guard let data = data, let password = passwordTextField.text else { return }

        data.clientAuthSdk.resetPassword(
            email: data.email,
            password: password,
            referenceId: data.referenceId
        ) { [weak self] accessToken, error in
            guard error == nil, let accessToken = accessToken else {
                self?.showAlert(message: error as? String ?? "An error occurred")
                return
            }

            DispatchQueue.main.async {
                self?.showSuccessMessageAndLogUserIn(data: data, accessToken: accessToken)
            }
        }
    }

    private func showSuccessMessageAndLogUserIn(data: Data, accessToken: String) {
        showAlert(message: "Your password has been succesfully updated") { _ in
            let loggedInViewController = LoggedInViewController.instantiate(
                data: .init(
                    clientAuthSdk: data.clientAuthSdk,
                    accessToken: accessToken,
                    userReference: data.email.lowercased()
                )
            )

            self.navigationController?.pushViewController(loggedInViewController, animated: true)
        }
    }

}

extension PasswordResetViewController {

    static func instantiate(data: Data) -> Self {
        let storyboard = UIStoryboard(name: "ResetPassword", bundle: nil)
        // swiftlint:disable force_cast
        let viewController =
            storyboard.instantiateViewController(withIdentifier: "PasswordResetViewController")
            as! Self
        // swiftlint:enable force_cast

        viewController.data = data
        return viewController
    }
}
