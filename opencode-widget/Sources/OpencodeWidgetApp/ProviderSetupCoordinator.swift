import AppKit
import Foundation
import Observation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

protocol ProviderSetupValidator: Sendable {
    func validate(candidate: String, for provider: ProviderID) async -> Bool
}

struct DataFetcherProviderSetupValidator: ProviderSetupValidator {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func validate(candidate: String, for provider: ProviderID) async -> Bool {
        switch provider {
        case .deepseek:
            await DataFetcher.fetchDeepseekBalance(apiKey: candidate, session: session) != nil
        case .minimax:
            await DataFetcher.fetchMiniMaxUsage(apiKey: candidate, session: session) != nil
        case .openAI:
            false
        }
    }
}

@MainActor
protocol ProviderPasteboardWriter: AnyObject {
    func copy(_ value: String)
}

@MainActor
final class SystemProviderPasteboardWriter: ProviderPasteboardWriter {
    func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

enum ProviderSetupStatus: Equatable {
    case idle
    case validating
    case saved
    case validationFailed
    case storageFailed
    case removed
}

enum CodexConnectionStatus: Equatable {
    case connected
    case notConnected
}

@MainActor
@Observable
final class ProviderSetupCoordinator {
    private let validator: any ProviderSetupValidator
    private let credentialStore: any ProviderCredentialStore
    private let pasteboardWriter: any ProviderPasteboardWriter
    private var saveGenerations: [ProviderID: Int] = [:]
    private var setupStatuses: [ProviderID: ProviderSetupStatus] = [:]

    private(set) var codexStatus: CodexConnectionStatus

    convenience init() {
        self.init(
            validator: DataFetcherProviderSetupValidator(),
            credentialStore: KeychainProviderCredentialStore(),
            pasteboardWriter: SystemProviderPasteboardWriter(),
            codexAvailability: { AuthReader.hasUsableCodexSession() }
        )
    }

    convenience init(validator: any ProviderSetupValidator, credentialStore: any ProviderCredentialStore) {
        self.init(
            validator: validator,
            credentialStore: credentialStore,
            pasteboardWriter: SystemProviderPasteboardWriter(),
            codexAvailability: { AuthReader.hasUsableCodexSession() }
        )
    }

    init(
        validator: any ProviderSetupValidator,
        credentialStore: any ProviderCredentialStore,
        pasteboardWriter: any ProviderPasteboardWriter,
        codexAvailability: @escaping () -> Bool
    ) {
        self.validator = validator
        self.credentialStore = credentialStore
        self.pasteboardWriter = pasteboardWriter
        self.codexStatus = codexAvailability() ? .connected : .notConnected
    }

    func status(for provider: ProviderID) -> ProviderSetupStatus {
        setupStatuses[provider] ?? .idle
    }

    func statusText(for provider: ProviderID) -> String {
        switch status(for: provider) {
        case .idle:
            "Not configured"
        case .validating:
            "Validating connection…"
        case .saved:
            "Configured"
        case .validationFailed:
            "Validation failed"
        case .storageFailed:
            "Could not save credential"
        case .removed:
            "Credential removed"
        }
    }

    var codexStatusText: String {
        switch codexStatus {
        case .connected:
            "Connected"
        case .notConnected:
            "Not connected"
        }
    }

    func isSaving(_ provider: ProviderID) -> Bool {
        status(for: provider) == .validating
    }

    func save(candidate: String, for provider: ProviderID) async {
        guard provider == .deepseek || provider == .minimax else { return }
        let credential = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            setupStatuses[provider] = .validationFailed
            return
        }

        let generation = nextGeneration(for: provider)
        setupStatuses[provider] = .validating

        let isValid = await validator.validate(candidate: credential, for: provider)
        guard generation == saveGenerations[provider] else { return }
        guard isValid else {
            setupStatuses[provider] = .validationFailed
            return
        }

        let storeError = await credentialStore.upsert(credential, for: provider)
        guard generation == saveGenerations[provider] else { return }
        setupStatuses[provider] = storeError == nil ? .saved : .storageFailed
    }

    func removeCredential(for provider: ProviderID) async {
        guard provider == .deepseek || provider == .minimax else { return }
        let generation = nextGeneration(for: provider)
        let storeError = await credentialStore.remove(for: provider)
        guard generation == saveGenerations[provider] else { return }
        setupStatuses[provider] = storeError == nil ? .removed : .storageFailed
    }

    func copyCodexLoginCommand() {
        pasteboardWriter.copy("codex login")
    }

    private func nextGeneration(for provider: ProviderID) -> Int {
        let next = (saveGenerations[provider] ?? 0) + 1
        saveGenerations[provider] = next
        return next
    }
}
