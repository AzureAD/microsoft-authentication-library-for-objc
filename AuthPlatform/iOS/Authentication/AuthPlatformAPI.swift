import Foundation
import Security

struct AuthTokenResponse: Decodable {
    let userID: UUID
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let accessTokenExpiresIn: Int
    let emailVerified: Bool

    enum CodingKeys: String, CodingKey {
        case userID, accessToken, refreshToken, tokenType, accessTokenExpiresIn, emailVerified
    }
}

enum AuthPlatformAPIError: LocalizedError {
    case missingBaseURL
    case invalidResponse
    case rejected(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL: return "Set AUTH_API_BASE_URL in the app Info.plist to your HTTPS AuthPlatform server URL."
        case .invalidResponse: return "The authentication server returned an invalid response."
        case let .rejected(code, message): return "Authentication failed (HTTP \(code)): \(message)"
        }
    }
}

final class AuthPlatformAPI {
    private let baseURL: URL
    private let session: URLSession

    init(bundle: Bundle = .main, session: URLSession = .shared) throws {
        guard let raw = bundle.object(forInfoDictionaryKey: "AUTH_API_BASE_URL") as? String,
              let url = URL(string: raw),
              url.scheme == "https" || url.host == "127.0.0.1" || url.host == "localhost"
        else { throw AuthPlatformAPIError.missingBaseURL }
        baseURL = url
        self.session = session
    }

    func login(email: String, password: String) async throws -> AuthTokenResponse {
        var request = URLRequest(url: baseURL.appending(path: "/v1/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LoginRequest(email: email, password: password))
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode(AuthTokenResponse.self, from: data)
    }

    func refresh(refreshToken: String) async throws -> AuthTokenResponse {
        var request = URLRequest(url: baseURL.appending(path: "/v1/auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken))
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode(AuthTokenResponse.self, from: data)
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AuthPlatformAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AuthPlatformAPIError.rejected(http.statusCode, message)
        }
    }
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}

/// Keeps refresh tokens in the app/extension shared Keychain group; never UserDefaults.
enum AuthSessionVault {
    private static let service = "com.example.authplatform.session"
    private static let account = "refresh-token"

    static func save(refreshToken: String) throws {
        let data = Data(refreshToken.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let update: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add.merge(update) { _, new in new }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AuthSessionVaultError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw AuthSessionVaultError.keychain(status)
        }
    }

    static func refreshToken() throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = Bundle.main.object(forInfoDictionaryKey: "CredentialKeychainAccessGroup") as? String {
            query[kSecAttrAccessGroup as String] = group
        }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw AuthSessionVaultError.keychain(status)
        }
        return value
    }

    enum AuthSessionVaultError: Error {
        case keychain(OSStatus)
    }
}
