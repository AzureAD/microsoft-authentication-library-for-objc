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

final class InitialViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - IBOutlets

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var logoImageView: UIImageView!

    // MARK: - Enum

    private enum Flow: String, CaseIterable {
        case signUpWithPassword = "SignUp with Password"  // Placeholder for DevOps push checks
        case loginWithPassword = "Login with Password"  // Placeholder for DevOps push checks
        case susiWithOtp = "Passwordless with email OTP"
        case resetPassword = "Reset Password"  // Placeholder for DevOps push checks
    }

    // MARK: - Variables

    private let clientAuthSDKCommunicator: IClientAuthSDKCommunicator = ClientAuthSDKCommunicator()

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Private methods

    private func setupUI() {
        navigationController?.navigationBar.prefersLargeTitles = true
        setupTexts()
    }

    private func setupTexts() {
        title = "ClientAuth Sample"
    }

    // MARK: Table view methods

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Flow.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell =
            self.tableView.dequeueReusableCell(withIdentifier: "userFlowTableViewCell")
            as! UserFlowTableViewCell
        // swiftlint:enable force_cast
        cell.userFlowNameLabel?.text = Flow.allCases[indexPath.row].rawValue
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewController: UIViewController
        let selectedFlow = Flow.allCases[indexPath.row]

        switch selectedFlow {
        case .signUpWithPassword:
            viewController = SignUpWithPasswordViewController.instantiate(
                clientAuthSdk: clientAuthSDKCommunicator)
        case .loginWithPassword:
            viewController = LoginWithPasswordViewController.instantiate(
                clientAuthSdk: clientAuthSDKCommunicator)
        case .susiWithOtp:
            viewController = PasswordlessViewController.instantiate(
                clientAuthSdk: clientAuthSDKCommunicator)
        case .resetPassword:
            viewController = EmailScreenViewController.instantiate(
                data: .init(clientAuthSdk: clientAuthSDKCommunicator, email: nil))
        }

        navigationController?.pushViewController(viewController, animated: true)
    }
}
