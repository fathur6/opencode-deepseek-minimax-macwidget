import Foundation
import XCTest
@testable import OpencodeWidgetApp
@testable import OpencodeWidgetShared

@MainActor
final class ProviderSettingsTests: XCTestCase {
    func testFooterUsesNativeSettingsLinkBetweenRefreshAndQuit() {
        XCTAssertEqual(MenuContent.footerActions.map(\.rawValue), ["Refresh", "Settings", "Quit"])
        XCTAssertTrue(MenuContent.usesNativeSettingsLink)
    }

    func testVisibleCardsFollowInjectedPreferencesImmediatelyAndSupportChartsOnly() {
        let suiteName = "ProviderSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = ProviderDisplayPreferences(defaults: defaults)

        preferences.setCardVisible(false, for: .minimax)
        XCTAssertEqual(MenuContent.visibleCards(preferences: preferences), [.deepseek, .openAI])

        for provider in ProviderID.allCases {
            preferences.setCardVisible(false, for: provider)
        }
        XCTAssertEqual(MenuContent.visibleCards(preferences: preferences), [])
    }

    func testIndependentValidSavesRouteToTheirOwnProviderAndRetainOnlyStatus() async {
        let store = FakeCredentialStore()
        let validator = FakeProviderValidator(results: [.deepseek: true, .minimax: true])
        let coordinator = ProviderSetupCoordinator(validator: validator, credentialStore: store)

        await coordinator.save(candidate: "deepseek-test-secret", for: .deepseek)
        await coordinator.save(candidate: "minimax-test-secret", for: .minimax)

        let deepseekValue = await store.value(for: .deepseek)
        let minimaxValue = await store.value(for: .minimax)
        let validatedProviders = await validator.recordedProviders()
        XCTAssertEqual(deepseekValue, "deepseek-test-secret")
        XCTAssertEqual(minimaxValue, "minimax-test-secret")
        XCTAssertEqual(validatedProviders, [.deepseek, .minimax])
        XCTAssertEqual(coordinator.status(for: .deepseek), .saved)
        XCTAssertEqual(coordinator.status(for: .minimax), .saved)
        XCTAssertFalse(coordinator.statusText(for: .deepseek).contains("deepseek-test-secret"))
        XCTAssertFalse(coordinator.statusText(for: .minimax).contains("minimax-test-secret"))
    }

    func testFailedValidationPreservesExistingCredentialAndSameKeyReplacementIsStable() async {
        let store = FakeCredentialStore(values: [.deepseek: "working-secret"])
        let failedValidator = FakeProviderValidator(results: [.deepseek: false])
        let coordinator = ProviderSetupCoordinator(validator: failedValidator, credentialStore: store)

        await coordinator.save(candidate: "invalid-replacement", for: .deepseek)

        let valueAfterFailure = await store.value(for: .deepseek)
        XCTAssertEqual(valueAfterFailure, "working-secret")
        XCTAssertEqual(coordinator.status(for: .deepseek), .validationFailed)
        XCTAssertFalse(coordinator.statusText(for: .deepseek).contains("invalid-replacement"))

        let stableValidator = FakeProviderValidator(results: [.deepseek: true])
        let stableCoordinator = ProviderSetupCoordinator(validator: stableValidator, credentialStore: store)
        await stableCoordinator.save(candidate: "working-secret", for: .deepseek)

        let stableValue = await store.value(for: .deepseek)
        XCTAssertEqual(stableValue, "working-secret")
        XCTAssertEqual(stableCoordinator.status(for: .deepseek), .saved)
    }

    func testDelayedValidationCannotOverwriteNewerSuccessfulSaveForTheSameProvider() async {
        let store = FakeCredentialStore()
        let validator = DelayedProviderValidator()
        let coordinator = ProviderSetupCoordinator(validator: validator, credentialStore: store)

        let firstSave = Task { @MainActor in
            await coordinator.save(candidate: "first-secret", for: .deepseek)
        }
        await validator.waitForFirstRequest()

        await coordinator.save(candidate: "second-secret", for: .deepseek)
        await validator.finishFirstRequest()
        await firstSave.value

        let finalValue = await store.value(for: .deepseek)
        XCTAssertEqual(finalValue, "second-secret")
        XCTAssertEqual(coordinator.status(for: .deepseek), .saved)
        XCTAssertFalse(coordinator.statusText(for: .deepseek).contains("first-secret"))
        XCTAssertFalse(coordinator.statusText(for: .deepseek).contains("second-secret"))
    }

    func testRemovalIsScopedToSelectedProvider() async {
        let store = FakeCredentialStore(values: [.deepseek: "deepseek-secret", .minimax: "minimax-secret"])
        let coordinator = ProviderSetupCoordinator(
            validator: FakeProviderValidator(results: [:]),
            credentialStore: store
        )

        await coordinator.removeCredential(for: .deepseek)

        let removedValue = await store.value(for: .deepseek)
        let retainedValue = await store.value(for: .minimax)
        XCTAssertNil(removedValue)
        XCTAssertEqual(retainedValue, "minimax-secret")
        XCTAssertEqual(coordinator.status(for: .deepseek), .removed)
    }

    func testCodexStatusUsesAvailabilityOnlyAndCopyWritesExactFixedCommand() throws {
        let authPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-status-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: authPath) }

        try "{\"tokens\": {\"access_token\": \"codex-test-token\"}}".write(to: authPath, atomically: true, encoding: .utf8)
        XCTAssertTrue(AuthReader.hasUsableCodexSession(authPath: authPath.path))

        try "{\"tokens\": {\"access_token\": \"\"}}".write(to: authPath, atomically: true, encoding: .utf8)
        XCTAssertFalse(AuthReader.hasUsableCodexSession(authPath: authPath.path))
        try "{ malformed".write(to: authPath, atomically: true, encoding: .utf8)
        XCTAssertFalse(AuthReader.hasUsableCodexSession(authPath: authPath.path))

        let pasteboard = FakePasteboard()
        let coordinator = ProviderSetupCoordinator(
            validator: FakeProviderValidator(results: [:]),
            credentialStore: FakeCredentialStore(),
            pasteboardWriter: pasteboard,
            codexAvailability: { false }
        )

        XCTAssertEqual(coordinator.codexStatus, .notConnected)
        coordinator.copyCodexLoginCommand()

        XCTAssertEqual(pasteboard.lastCopiedValue, "codex login")
        XCTAssertFalse(coordinator.codexStatusText.contains("codex-test-token"))
    }
}

private actor FakeCredentialStore: ProviderCredentialStore {
    private var values: [ProviderID: String]

    init(values: [ProviderID: String] = [:]) {
        self.values = values
    }

    func upsert(_ credential: String, for provider: ProviderID) async -> ProviderCredentialStoreError? {
        values[provider] = credential
        return nil
    }

    func read(for provider: ProviderID) async -> ProviderCredentialReadResult {
        values[provider].map(ProviderCredentialReadResult.value) ?? .notFound
    }

    func remove(for provider: ProviderID) async -> ProviderCredentialStoreError? {
        values[provider] = nil
        return nil
    }

    func value(for provider: ProviderID) -> String? {
        values[provider]
    }
}

private actor FakeProviderValidator: ProviderSetupValidator {
    let results: [ProviderID: Bool]
    private(set) var providers: [ProviderID] = []

    init(results: [ProviderID: Bool]) {
        self.results = results
    }

    func validate(candidate: String, for provider: ProviderID) async -> Bool {
        providers.append(provider)
        return results[provider] ?? false
    }

    func recordedProviders() -> [ProviderID] {
        providers
    }
}

private actor DelayedProviderValidator: ProviderSetupValidator {
    private var firstRequestStarted = false
    private var firstRequestWaiter: CheckedContinuation<Void, Never>?
    private var firstRequestCompletion: CheckedContinuation<Bool, Never>?

    func validate(candidate: String, for provider: ProviderID) async -> Bool {
        guard candidate == "first-secret" else { return true }
        firstRequestStarted = true
        firstRequestWaiter?.resume()
        firstRequestWaiter = nil
        return await withCheckedContinuation { continuation in
            firstRequestCompletion = continuation
        }
    }

    func waitForFirstRequest() async {
        if firstRequestStarted { return }
        await withCheckedContinuation { continuation in
            firstRequestWaiter = continuation
        }
    }

    func finishFirstRequest() {
        firstRequestCompletion?.resume(returning: true)
        firstRequestCompletion = nil
    }
}

@MainActor
private final class FakePasteboard: ProviderPasteboardWriter {
    var lastCopiedValue: String?

    func copy(_ value: String) {
        lastCopiedValue = value
    }
}
