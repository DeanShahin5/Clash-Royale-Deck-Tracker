import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int, String)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

class APIService {
    static let shared = APIService()

    private let baseURL = URL(string: "http://127.0.0.1:8001")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Resolve Player by Clan Name

    func resolvePlayer(playerName: String, clanName: String) async throws -> ResolveResponse {
        guard !playerName.isEmpty, !clanName.isEmpty else {
            throw APIError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent("/resolve_player_by_name")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ResolveByNameRequest(
            player_name: playerName,
            clan_name: clanName
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(httpResponse.statusCode, errorMessage)
            }
        }

        // Decode response
        do {
            let resolvedPlayer = try JSONDecoder().decode(ResolveResponse.self, from: data)
            return resolvedPlayer
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Predict Decks

    func predictDecks(playerTag: String, gameMode: String = "ranked") async throws -> PredictResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("/predict/\(playerTag)"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "game_mode", value: gameMode)
        ]

        guard let endpoint = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: endpoint)

        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(httpResponse.statusCode, errorMessage)
            }
        }

        // Decode response
        do {
            let prediction = try JSONDecoder().decode(PredictResponse.self, from: data)
            return prediction
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Combined Resolve and Predict

    func resolveAndPredict(playerName: String, clanName: String, gameMode: String = "ranked") async throws -> (player: ResolveResponse, prediction: PredictResponse) {
        // Step 1: Resolve player
        let resolvedPlayer = try await resolvePlayer(playerName: playerName, clanName: clanName)

        // Step 2: Predict decks with selected game mode
        let prediction = try await predictDecks(playerTag: resolvedPlayer.player_tag, gameMode: gameMode)

        return (resolvedPlayer, prediction)
    }
}
