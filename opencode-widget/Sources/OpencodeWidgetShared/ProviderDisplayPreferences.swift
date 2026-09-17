import Foundation
import Observation

public enum ProviderID: String, CaseIterable, Sendable {
    case deepseek
    case minimax
    case openAI

    fileprivate var displayPreferenceKey: String {
        switch self {
        case .deepseek:
            "provider-card-visible.deepseek"
        case .minimax:
            "provider-card-visible.minimax"
        case .openAI:
            "provider-card-visible.openai"
        }
    }
}

@Observable
public final class ProviderDisplayPreferences {
    private let defaults: UserDefaults
    private var visibility: [ProviderID: Bool]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.visibility = Dictionary(uniqueKeysWithValues: ProviderID.allCases.map {
            ($0, defaults.object(forKey: $0.displayPreferenceKey) as? Bool ?? true)
        })
    }

    public func isCardVisible(_ provider: ProviderID) -> Bool {
        visibility[provider] ?? true
    }

    public func setCardVisible(_ isVisible: Bool, for provider: ProviderID) {
        visibility[provider] = isVisible
        defaults.set(isVisible, forKey: provider.displayPreferenceKey)
    }
}

public enum ProviderCardLayout {
    public static func visibleCards(preferences: ProviderDisplayPreferences) -> [ProviderID] {
        ProviderID.allCases.filter(preferences.isCardVisible)
    }
}
