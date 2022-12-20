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

extension UIViewController {

    // Show Alert

    func showAlert(message: String, handler: ((UIAlertAction) -> Void)? = nil) {
        let dialogMessage = UIAlertController(
            title: "Alert", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: handler)
        dialogMessage.addAction(okAction)
        if Thread.isMainThread {
            self.present(dialogMessage, animated: true, completion: nil)
        } else {
            DispatchQueue.main.async {
                self.present(dialogMessage, animated: true, completion: nil)
            }
        }
    }

    // Keyboard Handling with ScrollView

    func addKeyboardHandling(scrollView: UIScrollView) {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.keyboardWillShow(scrollView: scrollView, notification: notification)
        }

        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: nil
        ) { _ in
            scrollView.contentInset = .zero
            scrollView.scrollIndicatorInsets = .zero
        }

        addDismissKeyboardWithTapGesture()
    }

    private func keyboardWillShow(scrollView: UIScrollView, notification: Notification) {
        guard
            let keyboardSize =
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
                .cgRectValue
        else {
            return
        }

        let contentInsets = UIEdgeInsets(
            top: 0.0, left: 0.0, bottom: keyboardSize.height, right: 0.0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }

    // Dismiss Keyboard with a tap gesture

    func addDismissKeyboardWithTapGesture() {
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        )
    }
}
