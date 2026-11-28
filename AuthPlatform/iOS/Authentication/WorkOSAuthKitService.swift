import AuthenticationServices
import Foundation
import UIKit
import WorkOS

/// Native WorkOS AuthKit sign-in. Uses the public client + PKCE; never accepts an API key.
@MainActor
final class WorkOSAuthKitService: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct Tokens {
        let accessToken: String
        let refreshToken: String
    }

    enum SignInError: LocalizedError {
        case missingConfiguration
        case invalidCallback
        case stateMismatch
        case unableToStart

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Set AUTH_WORKOS_CLIENT_ID and AUTH_WORKOS_REDIRECT_URI in the app Info.plist."
            case .invalidCallback:
                return "WorkOS returned an invalid authentication callback."
            case .stateMismatch:
                return "The WorkOS authentication state did not match. Please try again."
            case .unableToStart:
                return "The secure WorkOS sign-in session could not be started."
            }
        }
    }

    private var webAuthenticationSession: ASWebAuthenticationSession?

    func signIn(bundle: Bundle = .main) async throws -> Tokens {
        guard
            let clientID = bundle.object(forInfoDictionaryKey: "AUTH_WORKOS_CLIENT_ID") as? String,
            !clientID.isEmpty,
            let redirectURI = bundle.object(forInfoDictionaryKey: "AUTH_WORKOS_REDIRECT_URI") as? String,
            let redirect = URL(string: redirectURI),
            let callbackScheme = redirect.scheme
        else {
            throw SignInError.missingConfiguration
        }

        let client = PublicClient(clientID: clientID)
        let authorization = try client.getAuthorizationUrlWithPKCE(
            redirectUri: redirectURI,
            provider: "authkit"
        )

        let callbackURL = try await beginBrowserAuthentication(
            url: authorization.url,
            callbackScheme: callbackScheme
        )

        guard
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw SignInError.invalidCallback
        }

        guard returnedState == authorization.state else {
            throw SignInError.stateMismatch
        }

        let authentication = try await client.authenticateWithCode(
            code: code,
            codeVerifier: authorization.codeVerifier
        )

        return Tokens(
            accessToken: authentication.accessToken,
            refreshToken: authentication.refreshToken
        )
    }

    private func beginBrowserAuthentication(
        url: URL,
        callbackScheme: String
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                self.webAuthenticationSession = nil
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: SignInError.invalidCallback)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthenticationSession = session

            guard session.start() else {
                self.webAuthenticationSession = nil
                continuation.resume(throwing: SignInError.unableToStart)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
