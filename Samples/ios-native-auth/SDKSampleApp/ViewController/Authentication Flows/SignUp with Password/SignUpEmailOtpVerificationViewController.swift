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

final class SignUpEmailOtpVerificationViewController: UIViewController {

    struct Data {
        let clientAuthSdk: IClientAuthSDKCommunicator
        let email: String
        let password: String
        let referenceId: String
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
        title = "Sign Up with Password"
        navigationController?.navigationBar.prefersLargeTitles = false

        submitButton.isEnabled = false

        addKeyboardHandling(scrollView: scrollView)
        configureTextFields()

        submitButton.configurationUpdateHandler = { [unowned self] button in
            var config = button.configuration
            config?.showsActivityIndicator = self.submitting
            config?.imagePlacement = self.submitting ? .leading : .trailing
            config?.title = self.submitting ? "Submitting..." : "Submit"
            button.isEnabled = button.isEnabled && !self.submitting
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
        guard let data = data, let otp = otpTextField.text else { return }

        submitting = true

        data.clientAuthSdk.verify(referenceId: data.referenceId, otp: otp) { [weak self] success, error in
            self?.submitting = false
            guard error == nil, success else {
                self?.showAlert(message: error as? String ?? "Error verifying OTP")
                return
            }

            self?.performLogin(with: data)
        }
    }

    private func performLogin(with data: Data) {
        data.clientAuthSdk.signIn(
            emailOrNumber: data.email,
            password: data.password,
            scope: []
        ) { [weak self] accessToken, error in
            self?.loginCallback(accessToken, error, data: data)
        }
    }

    private func loginCallback(_ accessToken: String?, _ error: Error?, data: Data) {
        guard let accessToken = accessToken else {
            showAlert(message: "Credentials not found")
            return
        }

        let loggedInViewController = LoggedInViewController.instantiate(
            data: .init(
                clientAuthSdk: data.clientAuthSdk,
                accessToken: accessToken,
                userReference: data.email
            )
        )

        DispatchQueue.main.async {
            self.navigationController?.pushViewController(loggedInViewController, animated: true)
        }
    }

    @objc private func textFieldDidChange() {
        let isOtpValid = FieldValidator.check(.otp(otpTextField.text))

        otpTextField.layer.borderWidth = isOtpValid ? 0 : 1
        submitButton.isEnabled = isOtpValid
    }
}

extension SignUpEmailOtpVerificationViewController {

    static func instantiate(data: Data) -> Self {
        let storyboard = UIStoryboard(name: "SignUpWithPassword", bundle: nil)
        // swiftlint:disable force_cast
        let emailVerificationViewController =
            storyboard.instantiateViewController(
                withIdentifier: "SignUpEmailVerificationViewController")
            as! Self
        // swiftlint:enable force_cast

        emailVerificationViewController.data = data
        return emailVerificationViewController
    }
}
