import AuthenticationServices
import LocalAuthentication
import UIKit

/// Add this source to a separate iOS Credential Provider Extension target.
/// The containing app and extension must share a Keychain access group.
final class CredentialProviderViewController: ASCredentialProviderViewController {
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        let domains = serviceIdentifiers
            .filter { $0.type == .domain }
            .map(\.identifier)
        let matches = domains.flatMap { domain -> [StoredPasswordCredential] in
            (try? SharedCredentialVault.credentials(for: domain)) ?? []
        }
        guard !matches.isEmpty else {
            extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: -1))
            return
        }

        let picker = UIAlertController(title: "Choose a sign-in", message: nil, preferredStyle: .actionSheet)
        for item in matches {
            picker.addAction(UIAlertAction(title: "\(item.username) · \(item.service)", style: .default) { [weak self] _ in
                self?.authenticateAndProvide(item)
            })
        }
        picker.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: -1))
        })
        present(picker, animated: true)
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        do {
            guard let item = try SharedCredentialVault.credential(
                service: credentialIdentity.serviceIdentifier.identifier,
                username: credentialIdentity.user
            ) else {
                extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: -1))
                return
            }
            authenticateAndProvide(item)
        } catch {
            extensionContext.cancelRequest(withError: error)
        }
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // Do not release passwords silently. Require an explicit user-presence
        // authentication in the extension UI before returning a secret.
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: -2))
    }

    private func authenticateAndProvide(_ item: StoredPasswordCredential) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock a saved sign-in") { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard success else {
                    self.extensionContext.cancelRequest(withError: error ?? NSError(domain: ASExtensionErrorDomain, code: -1))
                    return
                }
                let credential = ASPasswordCredential(user: item.username, password: item.password)
                self.extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
            }
        }
    }
}
