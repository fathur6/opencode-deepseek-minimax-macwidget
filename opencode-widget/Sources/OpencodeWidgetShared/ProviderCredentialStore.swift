import Foundation
import Security

public enum ProviderCredentialIdentity {
    public static let service = "com.fathur6.opencode-widget.provider-credentials"
    public static let deepseekAccount = "deepseek-api-key"
    public static let minimaxAccount = "minimax-api-key"

    public static func account(for provider: ProviderID) -> String? {
        switch provider {
        case .deepseek:
            deepseekAccount
        case .minimax:
            minimaxAccount
        case .openAI:
            nil
        }
    }
}

public enum ProviderCredentialStoreError: Error, Equatable, Sendable {
    case invalidCredential
    case keychainStatus(Int32)
}

public enum ProviderCredentialReadResult: Sendable, Equatable {
    case value(String)
    case notFound
    case failure(ProviderCredentialStoreError)
}

public protocol ProviderCredentialStore: Sendable {
    func upsert(_ credential: String, for provider: ProviderID) async -> ProviderCredentialStoreError?
    func read(for provider: ProviderID) async -> ProviderCredentialReadResult
    func remove(for provider: ProviderID) async -> ProviderCredentialStoreError?
}

public final class KeychainProviderCredentialStore: ProviderCredentialStore, @unchecked Sendable {
    public init() {}

    public func upsert(_ credential: String, for provider: ProviderID) async -> ProviderCredentialStoreError? {
        await Task.detached(priority: .utility) {
            Self.upsertCredential(credential, for: provider)
        }.value
    }

    public func read(for provider: ProviderID) async -> ProviderCredentialReadResult {
        await Task.detached(priority: .utility) {
            Self.readCredential(for: provider)
        }.value
    }

    public func remove(for provider: ProviderID) async -> ProviderCredentialStoreError? {
        await Task.detached(priority: .utility) {
            Self.removeCredential(for: provider)
        }.value
    }

    private static func upsertCredential(_ credential: String, for provider: ProviderID) -> ProviderCredentialStoreError? {
        guard !credential.isEmpty, let match = keychainMatch(for: provider) else {
            return .invalidCredential
        }

        let update = [kSecValueData: Data(credential.utf8)] as CFDictionary
        let updateStatus = SecItemUpdate(match as CFDictionary, update)
        if updateStatus == errSecSuccess {
            return nil
        }
        guard updateStatus == errSecItemNotFound else {
            return .keychainStatus(Int32(updateStatus))
        }

        var attributes = match
        attributes[kSecValueData] = Data(credential.utf8)
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        return addStatus == errSecSuccess ? nil : .keychainStatus(Int32(addStatus))
    }

    private static func readCredential(for provider: ProviderID) -> ProviderCredentialReadResult {
        guard var query = keychainMatch(for: provider) else {
            return .notFound
        }
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return .notFound
        }
        guard status == errSecSuccess else {
            return .failure(.keychainStatus(Int32(status)))
        }
        guard let data = item as? Data,
              let credential = String(data: data, encoding: .utf8),
              !credential.isEmpty else {
            return .failure(.keychainStatus(Int32(errSecDecode)))
        }
        return .value(credential)
    }

    private static func removeCredential(for provider: ProviderID) -> ProviderCredentialStoreError? {
        guard let match = keychainMatch(for: provider) else {
            return nil
        }
        let status = SecItemDelete(match as CFDictionary)
        return (status == errSecSuccess || status == errSecItemNotFound) ? nil : .keychainStatus(Int32(status))
    }

    private static func keychainMatch(for provider: ProviderID) -> [CFString: Any]? {
        guard let account = ProviderCredentialIdentity.account(for: provider) else {
            return nil
        }
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: ProviderCredentialIdentity.service,
            kSecAttrAccount: account,
        ]
    }
}
