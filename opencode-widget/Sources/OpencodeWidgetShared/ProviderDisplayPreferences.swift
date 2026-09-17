import Foundation

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

public final class ProviderDisplayPreferences {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isCardVisible(_ provider: ProviderID) -> Bool {
        defaults.object(forKey: provider.displayPreferenceKey) as? Bool ?? true
    }

    public func setCardVisible(_ isVisible: Bool, for provider: ProviderID) {
        defaults.set(isVisible, forKey: provider.displayPreferenceKey)
    }
}

public enum ProviderCardLayout {
    public static func visibleCards(preferences: ProviderDisplayPreferences) -> [ProviderID] {
        ProviderID.allCases.filter(preferences.isCardVisible)
    }
}
