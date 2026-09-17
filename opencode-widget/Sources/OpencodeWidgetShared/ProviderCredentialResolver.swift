import Foundation

public struct ProviderCredentialResolver: Sendable {
    private let store: any ProviderCredentialStore
    private let authPath: String

    public init(
        store: any ProviderCredentialStore = KeychainProviderCredentialStore(),
        authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json"
    ) {
        self.store = store
        self.authPath = authPath
    }

    /// Resolves one provider from the app Keychain before reading its legacy value.
    /// The legacy OpenCode auth file is never written or deleted by this boundary.
    public func resolve(_ provider: ProviderID) async -> String? {
        if case let .value(credential) = await store.read(for: provider) {
            return credential
        }
        return AuthReader.readLegacyKey(for: provider, authPath: authPath)
    }
}
