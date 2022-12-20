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

final class SignUpWithPasswordViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var repeatPasswordTextField: UITextField!
    @IBOutlet private weak var givenNameTextField: UITextField!
    @IBOutlet private weak var surnameTextField: UITextField!
    @IBOutlet private weak var signUpButton: UIButton!

    // MARK: - Variables

    private var signingUp = false
    private var clientAuthSdk: IClientAuthSDKCommunicator?

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Private methods

    private func setupUI() {
        title = "SignUp with Password"
        navigationController?.navigationBar.prefersLargeTitles = false
        signUpButton.isEnabled = false

        addKeyboardHandling(scrollView: scrollView)
        configureTextFields()

        signUpButton.configurationUpdateHandler = { [unowned self] button in
            var config = button.configuration
            config?.showsActivityIndicator = self.signingUp
            config?.imagePlacement = self.signingUp ? .leading : .trailing
            config?.title = self.signingUp ? "Creating..." : "Create new user"
            button.isEnabled = button.isEnabled && !self.signingUp
            button.configuration = config
        }
    }

    private func configureTextFields() {
        configureEmailTextField()
        configurePasswordTextField(passwordTextField, newPassword: true)
        configurePasswordTextField(repeatPasswordTextField, newPassword: false)
        configurePersonalInformationTextFields()
    }

    private func configureEmailTextField() {
        emailTextField.layer.borderColor = UIColor.red.cgColor
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .emailAddress
        emailTextField.autocorrectionType = .no
        addTextFieldDidChangeListener(emailTextField)
    }

    private func configurePasswordTextField(_ textField: UITextField, newPassword: Bool) {
        textField.layer.borderColor = UIColor.red.cgColor
        textField.isSecureTextEntry = true
        textField.textContentType = newPassword ? .newPassword : .password
        textField.autocorrectionType = .no
        textField.rightViewMode = .always
        textField.rightView =
            newPassword
            ? makeToggleSecureEntryButton(action: #selector(passwordSecureEntryButtonDidTap))
            : makeToggleSecureEntryButton(action: #selector(repeatPasswordSecureEntryButtonDidTap))
        addTextFieldDidChangeListener(textField)
    }

    private func configurePersonalInformationTextFields() {
        givenNameTextField.textContentType = .givenName
        surnameTextField.textContentType = .familyName
    }

    private func makeToggleSecureEntryButton(action: Selector) -> UIButton {
        let button = UIButton(frame: .init(x: 0, y: 0, width: 30, height: 30))
        button.setImage(UIImage(systemName: "eye.slash.fill"), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)

        return button
    }

    private func addTextFieldDidChangeListener(_ textField: UITextField) {
        textField.addTarget(
            self,
            action: #selector(textFieldDidChange),
            for: UIControl.Event.editingChanged
        )
    }

    // MARK: - Actions

    @IBAction private func signUpButtonDidTap(_ sender: UIButton) {
        guard let email = emailTextField.text, let password = passwordTextField.text,
            let clientAuthSdk = clientAuthSdk
        else {
            return
        }

        var userClaims: [String: String] = [:]

        if let givenName = givenNameTextField.text {
            userClaims["givenName"] = givenName
        }

        if let surname = surnameTextField.text {
            userClaims["surname"] = surname
        }

        signingUp = true

        clientAuthSdk.signUp(
            emailOrNumber: email,
            password: password,
            userClaims: userClaims
        ) { [weak self] referenceId, error in
            self?.signingUp = false
            guard error == nil, let referenceId = referenceId else {
                self?.showAlert(message: "Sign Up error")
                return
            }

            let emailVerificationViewController =
                SignUpEmailOtpVerificationViewController.instantiate(
                    data: .init(
                        clientAuthSdk: clientAuthSdk,
                        email: email,
                        password: password,
                        referenceId: referenceId
                    )
                )

            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(
                    emailVerificationViewController, animated: true)
            }
        }
    }

    @objc private func passwordSecureEntryButtonDidTap() {
        toggleSecureEntryButton(on: passwordTextField)
    }

    @objc private func repeatPasswordSecureEntryButtonDidTap() {
        toggleSecureEntryButton(on: repeatPasswordTextField)
    }

    private func toggleSecureEntryButton(on textField: UITextField) {
        textField.isSecureTextEntry.toggle()
        let buttonImage = UIImage(
            systemName: textField.isSecureTextEntry ? "eye.slash.fill" : "eye.fill")
        (textField.rightView as? UIButton)?.setImage(buttonImage, for: .normal)
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        let isEmailValid = FieldValidator.check(.email(emailTextField.text))
        let isPasswordValid = FieldValidator.check(.password(passwordTextField.text))
        let isPasswordRepeatValid =
            FieldValidator.check(.repeatPassword(passwordTextField.text))
            && passwordTextField.text == repeatPasswordTextField.text

        switch textField {
        case emailTextField:
            emailTextField.layer.borderWidth = isEmailValid ? 0 : 1
        case passwordTextField:
            passwordTextField.layer.borderWidth = isPasswordValid ? 0 : 1
        case repeatPasswordTextField:
            repeatPasswordTextField.layer.borderWidth = isPasswordRepeatValid ? 0 : 1
        default:
            break
        }

        signUpButton.isEnabled = isEmailValid && isPasswordValid && isPasswordRepeatValid
    }
}

extension SignUpWithPasswordViewController {

    static func instantiate(clientAuthSdk: IClientAuthSDKCommunicator) -> Self {
        let storyboard = UIStoryboard(name: "SignUpWithPassword", bundle: nil)
        // swiftlint:disable force_cast
        let signUpViewController =
            storyboard.instantiateViewController(withIdentifier: "SignUpViewController") as! Self
        // swiftlint:enable force_cast

        signUpViewController.clientAuthSdk = clientAuthSdk
        return signUpViewController
    }
}
