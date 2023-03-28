//
//  NewPasswordViewController.swift
//  NativeAuthSampleApp
//
//  Created by Rodhan Hickey on 28/03/2023.
//

import UIKit

class NewPasswordViewController: UIViewController {

    var passwordSubmittedCallback: ((_ otp: String)->())?

    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var passwordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func cancelPressed(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func submitPressed(_ sender: Any) {
        guard let password = passwordTextField.text else {
            return
        }

        passwordSubmittedCallback?(password)
    }

}
