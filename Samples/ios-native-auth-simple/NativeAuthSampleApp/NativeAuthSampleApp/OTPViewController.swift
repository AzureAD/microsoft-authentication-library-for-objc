//
//  OTPViewController.swift
//  NativeAuthSampleApp
//
//  Created by Rodhan Hickey on 27/03/2023.
//

import UIKit

class OTPViewController: UIViewController {

    var otpSubmittedCallback: ((_ otp: String)->())?

    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var otpTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }   

    @IBAction func resendPressed(_ sender: Any) {
    }

    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func submitPressed(_ sender: Any) {
        guard let otp = otpTextField.text else {
            return
        }

        otpSubmittedCallback?(otp)
    }
}
