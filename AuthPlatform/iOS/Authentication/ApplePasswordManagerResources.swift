import Foundation
import UIKit

/// Read-only, versioned snapshot of Apple's Password Manager Resources.
/// Include the JSON files in the containing app target's Copy Bundle Resources phase.
public final class ApplePasswordManagerResources {
    public static let shared = ApplePasswordManagerResources()

    private struct PasswordRule: Decodable {
        let descriptor: String
        let exactDomainOnly: Bool?
        enum CodingKeys: String, CodingKey {
            case descriptor = "password-rules"
            case exactDomainOnly = "exact-domain-match-only"
        }
    }

    private struct SharedCredentialGroup: Decodable {
        let shared: [String]
    }

    private let passwordRules: [String: PasswordRule]
    private let sharedCredentialGroups: [SharedCredentialGroup]
    private let historicalGroups: [SharedCredentialGroup]
    private let changePasswordURLs: [String: String]
    private let twoFactorAppendDomains: Set<String>

    private init(bundle: Bundle = .main) {
        let directory = "ApplePasswordManager"
        passwordRules = Self.decode([String: PasswordRule].self, file: "password-rules", directory: directory, bundle: bundle) ?? [:]
        sharedCredentialGroups = Self.decode([SharedCredentialGroup].self, file: "shared-credentials", directory: directory, bundle: bundle) ?? []
        historicalGroups = Self.decode([SharedCredentialGroup].self, file: "shared-credentials-historical", directory: directory, bundle: bundle) ?? []
        changePasswordURLs = Self.decode([String: String].self, file: "change-password-URLs", directory: directory, bundle: bundle) ?? [:]
        twoFactorAppendDomains = Set(Self.decode([String].self, file: "websites-that-append-2fa-to-password", directory: directory, bundle: bundle) ?? [])
    }

    private static func decode<T: Decodable>(_ type: T.Type, file: String, directory: String, bundle: Bundle) -> T? {
        guard let url = bundle.url(forResource: file, withExtension: "json", subdirectory: directory),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    public func passwordRuleDescriptor(for hostOrURL: String) -> String? {
        guard let host = Self.normalizedHost(hostOrURL) else { return nil }
        let candidates = passwordRules.keys
            .filter { host == $0 || host.hasSuffix("." + $0) }
            .sorted { $0.count > $1.count }
        guard let match = candidates.first, let rule = passwordRules[match] else { return nil }
        if rule.exactDomainOnly == true && host != match { return nil }
        return rule.descriptor
    }

    public func passwordRules(for hostOrURL: String) -> UITextInputPasswordRules? {
        guard let descriptor = passwordRuleDescriptor(for: hostOrURL) else { return nil }
        return UITextInputPasswordRules(descriptor: descriptor)
    }

    /// Returns related domains for suggestion context only. Never use this mapping
    /// to silently release a saved credential to a different website.
    public func relatedCredentialDomains(for hostOrURL: String) -> [String] {
        guard let host = Self.normalizedHost(hostOrURL) else { return [] }
        return sharedCredentialGroups.first(where: { $0.shared.contains(host) })?.shared ?? []
    }

    public func historicallyRelatedCredentialDomains(for hostOrURL: String) -> [String] {
        guard let host = Self.normalizedHost(hostOrURL) else { return [] }
        return historicalGroups.first(where: { $0.shared.contains(host) })?.shared ?? []
    }

    public func changePasswordURL(for hostOrURL: String) -> URL? {
        guard let host = Self.normalizedHost(hostOrURL),
              let entry = changePasswordURLs.keys
                .filter({ host == $0 || host.hasSuffix("." + $0) })
                .max(by: { $0.count < $1.count }),
              let value = changePasswordURLs[entry]
        else { return nil }
        return URL(string: value)
    }

    public func requiresAppendingOneTimeCode(toPasswordFor hostOrURL: String) -> Bool {
        guard let host = Self.normalizedHost(hostOrURL) else { return false }
        return twoFactorAppendDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private static func normalizedHost(_ value: String) -> String? {
        let candidate = value.contains("://") ? value : "https://" + value
        guard let host = URLComponents(string: candidate)?.host?.lowercased(),
              !host.isEmpty, !host.contains("..")
        else { return nil }
        return host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

/// Apply these content types to the corresponding UIKit fields in the sign-in UI.
public enum AuthAutoFillConfiguration {
    public static func configureUsername(_ field: UITextField) {
        field.textContentType = .username
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
    }

    public static func configureCurrentPassword(_ field: UITextField) {
        field.textContentType = .password
        field.isSecureTextEntry = true
    }

    public static func configureNewPassword(_ field: UITextField, for hostOrURL: String) {
        field.textContentType = .newPassword
        field.isSecureTextEntry = true
        field.passwordRules = ApplePasswordManagerResources.shared.passwordRules(for: hostOrURL)
    }

    public static func configureOneTimeCode(_ field: UITextField) {
        field.textContentType = .oneTimeCode
        field.keyboardType = .numberPad
    }
}
