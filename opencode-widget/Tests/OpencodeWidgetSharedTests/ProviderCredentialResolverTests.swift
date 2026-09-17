import Foundation
import XCTest
@testable import OpencodeWidgetShared

final class ProviderCredentialResolverTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var legacyAuthURL: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-credentials-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        legacyAuthURL = temporaryDirectory.appendingPathComponent("auth.json")
        defaultsSuiteName = "ProviderCredentialResolverTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
    }

    override func tearDownWithError() throws {
        if let defaultsSuiteName {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        try? FileManager.default.removeItem(at: temporaryDirectory)
        defaults = nil
        defaultsSuiteName = nil
        legacyAuthURL = nil
        temporaryDirectory = nil
    }

    func testKeychainValueOverridesOnlyItsMatchingLegacyCredential() async throws {
        try writeLegacyCredentials()
        let store = InMemoryProviderCredentialStore()
        await store.upsert("synthetic-keychain-deepseek", for: .deepseek)
        let resolver = ProviderCredentialResolver(store: store, authPath: legacyAuthURL.path)

        let deepSeek = await resolver.resolve(.deepseek)
        let miniMax = await resolver.resolve(.minimax)

        XCTAssertTrue(deepSeek == "synthetic-keychain-deepseek")
        XCTAssertTrue(miniMax == "synthetic-legacy-minimax")
    }

    func testProvidersIndependentlyFallBackToMatchingLegacyKeys() async throws {
        try writeLegacyCredentials()
        let resolver = ProviderCredentialResolver(
            store: InMemoryProviderCredentialStore(),
            authPath: legacyAuthURL.path
        )

        XCTAssertTrue(await resolver.resolve(.deepseek) == "synthetic-legacy-deepseek")
        XCTAssertTrue(await resolver.resolve(.minimax) == "synthetic-legacy-minimax")
    }

    func testRemovingOneKeychainCredentialRestoresOnlyThatLegacyFallbackWithoutMutatingFile() async throws {
        try writeLegacyCredentials()
        let originalLegacyBytes = try Data(contentsOf: legacyAuthURL)
        let store = InMemoryProviderCredentialStore()
        await store.upsert("synthetic-keychain-deepseek", for: .deepseek)
        await store.upsert("synthetic-keychain-minimax", for: .minimax)
        let resolver = ProviderCredentialResolver(store: store, authPath: legacyAuthURL.path)

        await store.remove(for: .deepseek)

        XCTAssertTrue(await resolver.resolve(.deepseek) == "synthetic-legacy-deepseek")
        XCTAssertTrue(await resolver.resolve(.minimax) == "synthetic-keychain-minimax")
        XCTAssertEqual(try Data(contentsOf: legacyAuthURL), originalLegacyBytes)
    }

    func testInvalidOrMissingLegacyJSONProducesNoFallback() async throws {
        let resolver = ProviderCredentialResolver(
            store: InMemoryProviderCredentialStore(),
            authPath: legacyAuthURL.path
        )

        XCTAssertNil(await resolver.resolve(.deepseek))
        try Data("not-json".utf8).write(to: legacyAuthURL)
        XCTAssertNil(await resolver.resolve(.minimax))
    }

    func testResolutionDoesNotPersistSyntheticCredentialOutsideKeychain() async throws {
        try writeLegacyCredentials()
        let syntheticCredential = "synthetic-keychain-deepseek"
        let store = InMemoryProviderCredentialStore()
        await store.upsert(syntheticCredential, for: .deepseek)
        let resolver = ProviderCredentialResolver(store: store, authPath: legacyAuthURL.path)
        let cacheFixtureURL = temporaryDirectory.appendingPathComponent("widget-data.json")
        try Data("{\"cache\":true}".utf8).write(to: cacheFixtureURL)

        _ = await resolver.resolve(.deepseek)

        let serializedDefaults = String(describing: defaults.dictionaryRepresentation())
        let cacheFixture = try Data(contentsOf: cacheFixtureURL)
        XCTAssertFalse(serializedDefaults.contains(syntheticCredential))
        XCTAssertFalse(cacheFixture.contains(Data(syntheticCredential.utf8)))
    }

    private func writeLegacyCredentials() throws {
        let json = """
        {
          "deepseek": { "key": "synthetic-legacy-deepseek" },
          "minimax": { "key": "synthetic-legacy-minimax" }
        }
        """
        try Data(json.utf8).write(to: legacyAuthURL)
    }
}

private actor InMemoryProviderCredentialStore: ProviderCredentialStore {
    private var credentials: [ProviderID: String] = [:]

    func upsert(_ credential: String, for provider: ProviderID) {
        credentials[provider] = credential
    }

    func read(for provider: ProviderID) -> String? {
        credentials[provider]
    }

    func remove(for provider: ProviderID) {
        credentials.removeValue(forKey: provider)
    }
}
