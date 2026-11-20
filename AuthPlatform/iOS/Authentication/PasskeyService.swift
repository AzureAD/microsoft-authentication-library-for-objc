import AuthenticationServices
import Foundation

/// Starts Apple passkey registration/authentication UI.
/// The server must create and verify the WebAuthn challenge and attestation/assertion.
/// Never treat this delegate callback alone as proof of server-side authentication.
@MainActor
final class PasskeyService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var authorizationController: ASAuthorizationController?
    private let presentationAnchor: ASPresentationAnchor

    init(presentationAnchor: ASPresentationAnchor) {
        self.presentationAnchor = presentationAnchor
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }

    func authorize(_ requests: [ASAuthorizationRequest]) async throws -> ASAuthorization {
        guard continuation == nil else {
            throw PasskeyServiceError.requestAlreadyInProgress
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: requests)
            authorizationController = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        finish(.success(authorization), from: controller)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error), from: controller)
    }

    private func finish(_ result: Result<ASAuthorization, Error>, from controller: ASAuthorizationController) {
        guard authorizationController === controller else { return }

        authorizationController = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

private enum PasskeyServiceError: Error {
    case requestAlreadyInProgress
}
