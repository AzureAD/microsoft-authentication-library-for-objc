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

final class LoggedInViewController: UIViewController {

    struct Data {
        let clientAuthSdk: IClientAuthSDKCommunicator
        let accessToken: String
        let userReference: String
    }

    // MARK: - Outlets

    @IBOutlet private weak var loggedInUserReferenceLabel: UILabel!
    @IBOutlet private weak var signOutButton: UIButton!
    @IBOutlet private weak var accessTokenTextView: UITextView!

    // MARK: - Variables

    private var data: Data?
    private var signingOut = false

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Private methods

    private func setupUI() {
        title = "Logged In"
        navigationController?.navigationBar.prefersLargeTitles = false

        accessTokenTextView.text = data?.accessToken
        loggedInUserReferenceLabel.text = data?.userReference

        signOutButton.configurationUpdateHandler = { [unowned self] button in
            var config = button.configuration
            config?.showsActivityIndicator = self.signingOut
            config?.imagePlacement = self.signingOut ? .leading : .trailing
            config?.title = self.signingOut ? "Signing Out..." : "Sign Out"
            button.isEnabled = !self.signingOut
            button.configuration = config
        }
    }

    // MARK: - Actions

    @IBAction private func signOutButtonTapped(_ sender: Any) {
        guard let clientAuthSdk = data?.clientAuthSdk else { return }

        signingOut = true
        clientAuthSdk.signOut { [weak self] isSuccess, error in
            self?.signingOut = false

            guard error == nil, isSuccess else {
                self?.showAlert(message: "An error occurred")
                return
            }

            DispatchQueue.main.async {
                self?.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
}

extension LoggedInViewController {
    static func instantiate(data: Data) -> Self {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        // swiftlint:disable force_cast
        let loggedInViewController =
            storyboard.instantiateViewController(withIdentifier: "LoggedInViewController") as! Self
        // swiftlint:enable force_cast

        loggedInViewController.data = data
        return loggedInViewController
    }
}
