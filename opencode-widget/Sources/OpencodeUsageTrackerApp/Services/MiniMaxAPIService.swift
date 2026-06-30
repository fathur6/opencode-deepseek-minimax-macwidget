import Foundation
#if canImport(OpencodeWidgetShared)
import OpencodeWidgetShared
#endif

public enum MiniMaxAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid MiniMax API URL"
        case .invalidResponse: return "Invalid response from MiniMax"
        case .httpError(let code): return "HTTP error \(code)"
        case .decodingFailed: return "Failed to parse MiniMax usage"
        case .networkError(let error): return error.localizedDescription
        }
    }
}

public enum MiniMaxAPIService {
    static let usageURL = URL(string: "https://api.minimax.io/v1/api/openplatform/coding_plan/remains")!

    public static func fetchUsage(apiKey: String, session: URLSession = .shared) async throws -> [MiniMaxModelRemain] {
        var request = URLRequest(url: usageURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MiniMaxAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MiniMaxAPIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let planResponse = try decoder.decode(MiniMaxCodingPlanResponse.self, from: data)
            return planResponse.modelRemains
        } catch {
            throw MiniMaxAPIError.decodingFailed
        }
    }
}
