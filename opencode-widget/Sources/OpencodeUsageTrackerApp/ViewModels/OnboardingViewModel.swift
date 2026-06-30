import Foundation
import Observation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

@MainActor
@Observable
final class OnboardingViewModel {
    var deepseekKey = ""
    var minimaxKey = ""
    var statusMessage = ""
    var isLoading = false

    private let authPath: String

    init(authPath: String = "\(NSHomeDirectory())/.local/share/opencode/auth.json") {
        self.authPath = authPath
    }

    func verifyAndSave(session: URLSession = .shared, onComplete: @escaping () -> Void) async {
        guard !deepseekKey.isEmpty, !minimaxKey.isEmpty else { return }
        isLoading = true
        statusMessage = "Verifying..."

        do {
            _ = try await DeepSeekAPIService.fetchBalance(apiKey: deepseekKey, session: session)
        } catch {
            statusMessage = "DeepSeek key verification failed: \(error.localizedDescription)"
            isLoading = false
            return
        }

        do {
            _ = try await MiniMaxAPIService.fetchUsage(apiKey: minimaxKey, session: session)
        } catch {
            statusMessage = "MiniMax key verification failed: \(error.localizedDescription)"
            isLoading = false
            return
        }

        let authDict: [String: [String: String]] = [
            "deepseek": ["key": deepseekKey],
            "minimax": ["key": minimaxKey],
        ]
        let url = URL(fileURLWithPath: authPath)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: authDict, options: .prettyPrinted) {
            try? data.write(to: url)
        }

        statusMessage = ""
        isLoading = false
        onComplete()
    }
}
