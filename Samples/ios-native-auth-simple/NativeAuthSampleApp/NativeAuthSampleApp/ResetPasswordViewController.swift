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
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "OTPViewController") as? OTPViewController else {
            return
        }

        vc.otpSubmittedCallback = { [self] otp in
            DispatchQueue.main.async { [self] in
                Task {
                    showResultText("Submitted OTP: \(otp)")

                    dismiss(animated: true) {
                        self.showNewPasswordModal()
                    }

                }
            }
        }

        present(vc, animated: true)
    }

    func showNewPasswordModal() {
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "NewPasswordViewController") as? NewPasswordViewController else {
            return
        }

        vc.passwordSubmittedCallback = { [self] password in
            DispatchQueue.main.async { [self] in
                Task {
                    showResultText("Submitted new Password: \(password)")
                    dismiss(animated: true)
                }
            }
        }

        present(vc, animated: true)
    }



    func showResultText(_ text: String) {
        resultTextView.text = text
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
