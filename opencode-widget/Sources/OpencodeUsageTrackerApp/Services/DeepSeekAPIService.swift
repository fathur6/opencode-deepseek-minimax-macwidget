import Foundation

public enum DeepSeekAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid DeepSeek API URL"
        case .invalidResponse: return "Invalid response from DeepSeek"
        case .httpError(let code): return "HTTP error \(code)"
        case .decodingFailed: return "Failed to parse DeepSeek balance"
        case .networkError(let error): return error.localizedDescription
        }
    }
}

public enum DeepSeekAPIService {
    static let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!

    public static func fetchBalance(apiKey: String, session: URLSession = .shared) async throws -> Double {
        var request = URLRequest(url: balanceURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeepSeekAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DeepSeekAPIError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let infos = json["balance_infos"] as? [[String: Any]],
              let first = infos.first,
              let balanceStr = first["total_balance"] as? String,
              let balance = Double(balanceStr) else {
            throw DeepSeekAPIError.decodingFailed
        }
        return balance
    }
}
