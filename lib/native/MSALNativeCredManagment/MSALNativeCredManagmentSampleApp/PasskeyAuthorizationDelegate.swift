//
//  PasskeyAuthorizationDelegate.swift
//  MSALNativeCredManagmentSampleApp
//
//  Created by Serhii Demchenko on 2026-05-28.
//

import AuthenticationServices
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Delegate that handles passkey (platform public key credential) authorization results.
class PasskeyAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    enum PasskeyResult {
        case success(ASAuthorizationPlatformPublicKeyCredentialRegistration)
        case failure(Error)
    }

    private let completion: (PasskeyResult) -> Void

    init(completion: @escaping (PasskeyResult) -> Void) {
        self.completion = completion
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.keyWindow ?? NSWindow()
        #else
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? UIWindow()
        #endif
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential
                as? ASAuthorizationPlatformPublicKeyCredentialRegistration else {
            let error = NSError(
                domain: "PasskeyError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unexpected credential type returned."]
            )
            completion(.failure(error))
            return
        }
        completion(.success(credential))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        completion(.failure(error))
    }
}
