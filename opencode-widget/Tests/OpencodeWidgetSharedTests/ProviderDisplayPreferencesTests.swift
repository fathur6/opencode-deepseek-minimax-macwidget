import XCTest
@testable import OpencodeWidgetShared

final class ProviderDisplayPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ProviderDisplayPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewMissingMalformedAndLegacyPreferencesDefaultAllProvidersToVisible() {
        let preferences = ProviderDisplayPreferences(defaults: defaults)

        XCTAssertEqual(ProviderID.allCases, [.deepseek, .minimax, .openAI])
        XCTAssertTrue(ProviderID.allCases.allSatisfy(preferences.isCardVisible))

        defaults.set("hidden", forKey: "provider-card-visible.deepseek")
        defaults.set(1, forKey: "provider-card-visible.minimax")
        defaults.set(["visible": false], forKey: "provider-card-visible.openai")

        XCTAssertTrue(ProviderID.allCases.allSatisfy(preferences.isCardVisible))

        defaults.set(false, forKey: "legacy-provider-cards-visible")

        XCTAssertTrue(ProviderID.allCases.allSatisfy(preferences.isCardVisible))
    }

    func testVisibilityPersistsIndependentlyAndSameValueWritesAreIdempotent() {
        let preferences = ProviderDisplayPreferences(defaults: defaults)

        preferences.setCardVisible(false, for: .deepseek)
        preferences.setCardVisible(false, for: .minimax)
        preferences.setCardVisible(false, for: .minimax)

        XCTAssertFalse(preferences.isCardVisible(.deepseek))
        XCTAssertFalse(preferences.isCardVisible(.minimax))
        XCTAssertTrue(preferences.isCardVisible(.openAI))

        let reloadedPreferences = ProviderDisplayPreferences(defaults: defaults)
        XCTAssertFalse(reloadedPreferences.isCardVisible(.deepseek))
        XCTAssertFalse(reloadedPreferences.isCardVisible(.minimax))
        XCTAssertTrue(reloadedPreferences.isCardVisible(.openAI))
    }

    func testRapidWritesRetainTheFinalSelectionForOnlyThatProvider() {
        let preferences = ProviderDisplayPreferences(defaults: defaults)
        preferences.setCardVisible(false, for: .minimax)

        for isVisible in [false, true, false, true] {
            preferences.setCardVisible(isVisible, for: .deepseek)
        }

        XCTAssertTrue(preferences.isCardVisible(.deepseek))
        XCTAssertFalse(preferences.isCardVisible(.minimax))
        XCTAssertTrue(preferences.isCardVisible(.openAI))
    }

    func testVisibleCardsFilterEveryCombinationInFixedProviderOrder() {
        let providers = ProviderID.allCases

        for mask in 0..<(1 << providers.count) {
            let preferences = ProviderDisplayPreferences(defaults: defaults)
            for (index, provider) in providers.enumerated() {
                preferences.setCardVisible(mask & (1 << index) != 0, for: provider)
            }

            let expected = providers.enumerated().compactMap { index, provider in
                mask & (1 << index) != 0 ? provider : nil
            }

            XCTAssertEqual(ProviderCardLayout.visibleCards(preferences: preferences), expected)
        }
    }

    func testAllHiddenProvidersProduceAnEmptyChartsOnlyLayout() {
        let preferences = ProviderDisplayPreferences(defaults: defaults)
        ProviderID.allCases.forEach { preferences.setCardVisible(false, for: $0) }

        XCTAssertTrue(ProviderCardLayout.visibleCards(preferences: preferences).isEmpty)
    }
}
