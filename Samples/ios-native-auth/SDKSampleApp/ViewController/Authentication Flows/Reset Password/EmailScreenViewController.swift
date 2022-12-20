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

final class EmailScreenViewController: UIViewController {

    struct Data {
        let clientAuthSdk: IClientAuthSDKCommunicator
        let email: String?
    }

    // MARK: - Outlets

    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var nextButton: UIButton!
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

        addKeyboardHandling(scrollView: scrollView)
        configureTextFields()

        nextButton.isEnabled = FieldValidator.check(.email(emailTextField.text))
    }

    private func configureTextFields() {
        emailTextField.layer.borderColor = UIColor.red.cgColor
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .emailAddress
        emailTextField.autocorrectionType = .no
        emailTextField.text = data?.email

        emailTextField.addTarget(
            self,
            action: #selector(textFieldDidChange),
            for: UIControl.Event.editingChanged
        )
    }

    private func updateValidationUI() {
        let isValidInput = FieldValidator.check(.email(emailTextField.text))
        emailTextField.layer.borderWidth = isValidInput ? 0 : 1
        nextButton.isEnabled = isValidInput
    }

    // MARK: - Actions

    @IBAction private func nextButtonDidTap(_ sender: UIButton) {
        guard let email = emailTextField.text, let clientAuthSdk = data?.clientAuthSdk else {
            return
        }

        clientAuthSdk.startResetPassword(email: email) { [weak self] referenceId, error in
            guard error == nil, let referenceId = referenceId else {
                self?.showAlert(message: error as? String ?? "An error occurred")
                return
            }

            let otpViewController = ResetPasswordOtpViewController.instantiate(
                data: .init(
                    clientAuthSdk: clientAuthSdk,
                    referenceId: referenceId,
                    email: email
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

extension EmailScreenViewController {

    static func instantiate(data: Data) -> Self {
        let storyboard = UIStoryboard(name: "ResetPassword", bundle: nil)

        // swiftlint:disable force_cast
        let viewController =
            storyboard.instantiateViewController(withIdentifier: "EmailScreenViewController")
            as! Self
        // swiftlint:enable force_cast

        viewController.data = data

        return viewController
    }
}
