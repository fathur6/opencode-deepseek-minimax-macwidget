import Foundation

public enum UsageStatus: Comparable {
    case safe
    case warning
    case critical

    public init(usedPercentage: Double) {
        switch usedPercentage {
        case 0.0..<0.7:
            self = .safe
        case 0.7..<0.9:
            self = .warning
        default:
            self = .critical
        }
    }

    public var label: String {
        switch self {
        case .safe: return "Safe"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}
