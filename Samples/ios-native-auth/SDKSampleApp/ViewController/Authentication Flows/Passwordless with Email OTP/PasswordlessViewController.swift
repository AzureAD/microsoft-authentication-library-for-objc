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

final class PasswordlessViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var nextButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!

    // MARK: - Variables

    private var clientAuthSdk: IClientAuthSDKCommunicator?

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Private methods

    private func setupUI() {
        title = "Passwordless with email OTP"
        navigationController?.navigationBar.prefersLargeTitles = false

        nextButton.isEnabled = false

        addKeyboardHandling(scrollView: scrollView)
        configureTextFields()
    }

    private func configureTextFields() {
        emailTextField.layer.borderColor = UIColor.red.cgColor
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .emailAddress
        emailTextField.autocorrectionType = .no

        emailTextField.addTarget(
            self,
            action: #selector(textFieldDidChange),
            for: UIControl.Event.editingChanged
        )
    }

    private func updateValidationUI() {
        let validEmailInput = FieldValidator.check(.email(emailTextField.text))

        emailTextField.layer.borderWidth = validEmailInput ? 0 : 1
        nextButton.isEnabled = validEmailInput
    }

    // MARK: - Actions

    @IBAction private func nextButtonDidTap(_ sender: UIButton) {
        guard let email = emailTextField.text, let clientAuthSdk = clientAuthSdk else { return }

        clientAuthSdk.startPasswordless(email: email) { [weak self] referenceId, error in
            guard error == nil, let referenceId = referenceId else {
                self?.showAlert(message: error as? String ?? "An error occurred")
                return
            }

            let otpViewController = PasswordlessOtpViewController.instantiate(
                data: .init(
                    clientAuthSdk: clientAuthSdk,
                    email: email,
                    referenceId: referenceId
                )
            )

            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(otpViewController, animated: true)
            }
        }
    }

    @objc private func textFieldDidChange() {
        updateValidationUI()
    }
}

extension PasswordlessViewController {

    static func instantiate(clientAuthSdk: IClientAuthSDKCommunicator) -> Self {
        let storyboard = UIStoryboard(name: "PasswordlessWithEmailOTP", bundle: nil)
        // swiftlint:disable force_cast
        let passwordlessViewController =
            storyboard.instantiateViewController(withIdentifier: "PasswordlessViewController")
            as! Self
        // swiftlint:enable force_cast

        passwordlessViewController.clientAuthSdk = clientAuthSdk

        return passwordlessViewController
    }
}
