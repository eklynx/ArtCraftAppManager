import Foundation
import Security

/// Keychain-backed optional GitHub token (REQ-REG-11).
struct KeychainTokenProvider: TokenProviding {
    static let service = "com.eklynx.ArtCraftAppManager.github-token"
    var account = "github"

    func token() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let token, !token.isEmpty else { return }
        SecItemAdd(base.merging([kSecValueData as String: Data(token.utf8)]) { $1 } as CFDictionary, nil)
    }
}
