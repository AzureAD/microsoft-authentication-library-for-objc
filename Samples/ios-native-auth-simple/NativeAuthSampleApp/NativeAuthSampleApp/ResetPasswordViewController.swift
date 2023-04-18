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

import UIKit

class ResetPasswordViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func resetPasswordPressed(_ sender: Any) {
        showOTPModal()
    }

    func showOTPModal() {
        guard let otpViewController = storyboard?.instantiateViewController(
            withIdentifier: "OTPViewController") as? OTPViewController else {
            return
        }

        otpViewController.otpSubmittedCallback = { [weak self] otp in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                showResultText("Submitted OTP: \(otp)")
                
                dismiss(animated: true) { [weak self] in
                    self?.showNewPasswordModal()
                }
            }
        }

        present(otpViewController, animated: true)
    }

    func showNewPasswordModal() {
        guard let newPasswordViewController = storyboard?.instantiateViewController(
            withIdentifier: "NewPasswordViewController") as? NewPasswordViewController else {
            return
        }

        newPasswordViewController.passwordSubmittedCallback = { [weak self] password in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                showResultText("Submitted new Password: \(password)")
                dismiss(animated: true)
            }
        }

        present(newPasswordViewController, animated: true)
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }
}
