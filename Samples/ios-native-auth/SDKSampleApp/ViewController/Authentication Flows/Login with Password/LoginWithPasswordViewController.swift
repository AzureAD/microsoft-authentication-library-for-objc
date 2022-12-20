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

final class LoginWithPasswordViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var forgotPasswordButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!

    // MARK: - Variables

    private var clientAuthSdk: IClientAuthSDKCommunicator?
    private var signingIn = false

    private lazy var toggleSecureEntryButton: UIButton = {
        let button = UIButton(frame: .init(x: 0, y: 0, width: 30, height: 30))
        button.setImage(secureEntryIcon, for: .normal)
        button.addTarget(
            self, action: #selector(toggleSecureEntryButtonDidTap), for: .touchUpInside)

        return button
    }()

    private var secureEntryIcon: UIImage? {
        passwordTextField.isSecureTextEntry
            ? UIImage(systemName: "eye.slash.fill") : UIImage(systemName: "eye.fill")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Private methods

    private func setupUI() {
        title = "Login with Password"
        navigationController?.navigationBar.prefersLargeTitles = false

        loginButton.isEnabled = false
        forgotPasswordButton.isEnabled = false

        addKeyboardHandling(scrollView: scrollView)
        configureTextFields()

        loginButton.configurationUpdateHandler = { [unowned self] button in
            var config = button.configuration
            config?.showsActivityIndicator = self.signingIn
            config?.imagePlacement = self.signingIn ? .leading : .trailing
            config?.title = self.signingIn ? "Signing In..." : "Sign In"
            button.isEnabled = button.isEnabled && !self.signingIn
            button.configuration = config
        }
    }

    private func configureTextFields() {
        emailTextField.layer.borderColor = UIColor.red.cgColor
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .emailAddress
        emailTextField.autocorrectionType = .no
        addTextFieldDidChangeListener(emailTextField)

        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .password
        passwordTextField.autocorrectionType = .no
        passwordTextField.rightViewMode = .always
        passwordTextField.rightView = toggleSecureEntryButton
        addTextFieldDidChangeListener(passwordTextField)
    }

    private func addTextFieldDidChangeListener(_ textField: UITextField) {
        textField.addTarget(
            self,
            action: #selector(textFieldDidChange),
            for: UIControl.Event.editingChanged
        )
    }

    private func updateValidationUI() {
        let validEmailInput = FieldValidator.check(.email(emailTextField.text))
        let validPasswordInput = !(passwordTextField.text?.isEmpty ?? true)

        emailTextField.layer.borderWidth = validEmailInput ? 0 : 1
        loginButton.isEnabled = validEmailInput && validPasswordInput
        forgotPasswordButton.isEnabled = validEmailInput
    }

    // MARK: - Actions

    @IBAction private func loginButtonDidTap(_ sender: UIButton) {
        guard let clientAuthSdk = clientAuthSdk, let email = emailTextField.text?.lowercased(),
            let password = passwordTextField.text
        else {
            return
        }
        signingIn = true

        clientAuthSdk.signIn(emailOrNumber: email, password: password, scope: []) { [weak self] accessToken, error in
            guard error == nil, let accessToken = accessToken else {
                self?.showAlert(message: "Credentials not found")
                return
            }

            let loggedInViewController = LoggedInViewController.instantiate(
                data: .init(
                    clientAuthSdk: clientAuthSdk,
                    accessToken: accessToken,
                    userReference: email
                )
            )

            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(
                    loggedInViewController, animated: true)
            }
        }
    }

    @IBAction private func forgotPasswordButtonDidTap(_ sender: UIButton) {
        guard let clientAuthSdk = clientAuthSdk else { return }

        let emailScreenViewController = EmailScreenViewController.instantiate(
            data: .init(
                clientAuthSdk: clientAuthSdk,
                email: emailTextField.text
            )
        )

        navigationController?.pushViewController(emailScreenViewController, animated: true)
    }

    @objc private func toggleSecureEntryButtonDidTap() {
        passwordTextField.isSecureTextEntry.toggle()
        toggleSecureEntryButton.setImage(secureEntryIcon, for: .normal)
    }

    @objc private func textFieldDidChange() {
        updateValidationUI()
    }
}

extension LoginWithPasswordViewController {

    static func instantiate(clientAuthSdk: IClientAuthSDKCommunicator) -> Self {
        let storyboard = UIStoryboard(name: "LoginWithPassword", bundle: nil)
        // swiftlint:disable force_cast
        let loginViewController =
            storyboard.instantiateViewController(withIdentifier: "LoginWithPasswordViewController")
            as! Self
        // swiftlint:enable force_cast

        loginViewController.clientAuthSdk = clientAuthSdk
        return loginViewController
    }
}
