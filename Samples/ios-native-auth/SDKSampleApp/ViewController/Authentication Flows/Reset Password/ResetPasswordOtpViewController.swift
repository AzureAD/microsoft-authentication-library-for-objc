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

final class ResetPasswordOtpViewController: UIViewController {

    struct Data {
        let clientAuthSdk: IClientAuthSDKCommunicator
        let referenceId: String
        let email: String
    }

    // MARK: - Outlets

    @IBOutlet private weak var otpTextField: UITextField!
    @IBOutlet private weak var submitButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!

    // MARK: - Variables

    private var data: Data?
    private var submitting = false

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Private methods

    private func setupUI() {
        title = "Password Reset"
        navigationController?.navigationBar.prefersLargeTitles = false

        submitButton.isEnabled = false

        addKeyboardHandling(scrollView: scrollView)
        configureTextFields()

        submitButton.configurationUpdateHandler = { [unowned self] button in
            var config = button.configuration
            config?.showsActivityIndicator = submitting
            config?.imagePlacement = submitting ? .leading : .trailing
            config?.title = submitting ? "Submitting..." : "Submit"
            button.isEnabled = button.isEnabled && !submitting
            button.configuration = config
        }
    }

    private func configureTextFields() {
        otpTextField.layer.borderColor = UIColor.red.cgColor
        otpTextField.keyboardType = .numberPad
        otpTextField.textContentType = .oneTimeCode
        addTextFieldDidChangeListener(otpTextField)
    }

    private func addTextFieldDidChangeListener(_ textField: UITextField) {
        textField.addTarget(
            self,
            action: #selector(textFieldDidChange),
            for: UIControl.Event.editingChanged
        )
    }

    // MARK: - Actions

    @IBAction private func submitButtonDidTap(_ sender: UIButton) {
        guard let data = data, let otp = otpTextField.text else {
            return
        }

        submitting = true

        data.clientAuthSdk.verify(referenceId: data.referenceId, otp: otp) { [weak self] success, error in
            self?.submitting = false

            guard error == nil, success else {
                self?.showAlert(message: error as? String ?? "Error verifying OTP")
                return
            }

            let passwordResetViewController = PasswordResetViewController.instantiate(
                data: .init(
                    clientAuthSdk: data.clientAuthSdk,
                    referenceId: data.referenceId,
                    email: data.email
                )
            )

            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(
                    passwordResetViewController, animated: true)
            }
        }
    }

    @objc private func textFieldDidChange() {
        let isValidInput = FieldValidator.check(.otp(otpTextField.text))
        otpTextField.layer.borderWidth = isValidInput ? 0 : 1
        submitButton.isEnabled = isValidInput
    }
}

extension ResetPasswordOtpViewController {

    static func instantiate(data: Data) -> Self {
        let storyboard = UIStoryboard(name: "ResetPassword", bundle: nil)
        // swiftlint:disable force_cast
        let viewController =
            storyboard.instantiateViewController(withIdentifier: "ResetPasswordOtpViewController")
            as! Self
        // swiftlint:enable force_cast

        viewController.data = data
        return viewController
    }
}
