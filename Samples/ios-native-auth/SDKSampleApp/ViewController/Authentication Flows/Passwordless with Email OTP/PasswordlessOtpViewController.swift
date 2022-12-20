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

final class PasswordlessOtpViewController: UIViewController {

    struct Data {
        let clientAuthSdk: IClientAuthSDKCommunicator
        let email: String
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
        title = "Passwordless with email OTP"
        navigationController?.navigationBar.prefersLargeTitles = false

        submitButton.isEnabled = false

        addKeyboardHandling(scrollView: scrollView)
        configureTextFields()
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
        guard let data = data, let otpText = otpTextField.text else {
            return
        }

        submitting = true

        data.clientAuthSdk.signIn(
            email: data.email,
            otp: otpText,
            scope: [],
            referenceId: data.referenceId
        ) { [weak self] accessToken, error in
            self?.submitting = false

            guard error == nil, let accessToken = accessToken else {
                self?.showAlert(message: error as? String ?? "An error occurred")
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
                self?.navigationController?.pushViewController(
                    loggedInViewController, animated: true)
            }
        }
    }

    @objc private func textFieldDidChange() {
        let isOtpValid = FieldValidator.check(.otp(otpTextField.text))

        otpTextField.layer.borderWidth = isOtpValid ? 0 : 1
        submitButton.isEnabled = isOtpValid
    }
}

extension PasswordlessOtpViewController {

    static func instantiate(data: Data) -> Self {
        let storyboard = UIStoryboard(name: "PasswordlessWithEmailOTP", bundle: nil)
        // swiftlint:disable force_cast
        let otpVerificationViewController =
            storyboard.instantiateViewController(withIdentifier: "PasswordlessOtpViewController")
            as! Self
        // swiftlint:enable force_cast

        otpVerificationViewController.data = data
        return otpVerificationViewController
    }
}
