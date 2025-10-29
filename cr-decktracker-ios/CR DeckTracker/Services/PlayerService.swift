import Foundation
import Combine

struct BattleInfo: Codable {
    let type: String
    let battle_time: String
    let result: String?
    let crowns: Int
    let opponent_crowns: Int
    let deck: [String]
    let arena: String?
    let player_trophies: Int?
    let opponent_name: String?
    let opponent_trophies: Int?

    var formattedType: String {
        switch type {
        case "pathOfLegend":
            return "Path of Legend"
        case "ladder":
            return "Ladder"
        case "challenge":
            return "Challenge"
        case "tournament":
            return "Tournament"
        case "friendly":
            return "Friendly Battle"
        case "clanMate":
            return "Clan Mate"
        case "riverRacePvP":
            return "River Race"
        case "riverRaceDuel":
            return "River Duel"
        default:
            return type.capitalized
        }
    }

    var formattedTime: String {
        // Parse battleTime format: "20250128T123456.000Z"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")

        if let date = formatter.date(from: battle_time) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return battle_time
    }
}

struct TopDeck: Codable {
    let deck: [String]
    let confidence: Double
}

struct PlayerStatsResponse: Codable {
    let player_tag: String
    let name: String
    let trophies: Int
    let best_trophies: Int
    let level: Int
    let arena: String
    let clan: String?
    let clan_tag: String?
    let total_battles: Int
    let wins: Int
    let losses: Int
    let win_rate: Double
    let recent_battles: [BattleInfo]
    let top_decks: [TopDeck]
}

enum PlayerServiceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

class PlayerService: ObservableObject {
    static let shared = PlayerService()

    @Published var playerStats: PlayerStatsResponse?
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let baseURL = "http://127.0.0.1:8001"

    @MainActor
    func fetchPlayerStats(playerTag: String) async throws -> PlayerStatsResponse {
        isLoading = true
        errorMessage = ""

        // Encode player tag
        let encodedTag = playerTag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? playerTag

        guard let url = URL(string: "\(baseURL)/player/\(encodedTag)/stats") else {
            isLoading = false
            throw PlayerServiceError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                isLoading = false
                throw PlayerServiceError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let stats = try JSONDecoder().decode(PlayerStatsResponse.self, from: data)
                self.playerStats = stats
                isLoading = false
                return stats
            } else {
                // Try to parse error detail from JSON response
                var errorMsg = "Unknown error"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = json["detail"] as? String {
                    errorMsg = detail
                } else {
                    errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                }

                isLoading = false
                errorMessage = errorMsg
                throw PlayerServiceError.networkError(NSError(domain: "PlayerService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        } catch let error as PlayerServiceError {
            isLoading = false
            errorMessage = error.localizedDescription ?? "An error occurred"
            throw error
        } catch {
            isLoading = false
            errorMessage = "An unexpected error occurred"
            throw PlayerServiceError.networkError(error)
        }
    }
}
