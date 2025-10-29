import Foundation
import Combine

struct ClanMemberStats: Codable, Identifiable {
    let name: String
    let tag: String
    let donations: Int
    let donations_received: Int
    let war_attacks: Int
    let total_war_attacks: Int
    let battles: Int
    let wins: Int
    let losses: Int
    let ranked_battles: Int
    let ranked_wins: Int
    let ranked_losses: Int
    let ranked_avg_crowns: Double
    let ladder_battles: Int
    let ladder_wins: Int
    let ladder_losses: Int
    let ladder_avg_crowns: Double
    let last_seen: String?

    var id: String { tag }

    var totalDonations: Int {
        donations + donations_received
    }

    var warParticipationRate: Double {
        guard total_war_attacks > 0 else { return 0 }
        return Double(war_attacks) / Double(total_war_attacks)
    }

    var winRate: Double {
        let totalGames = wins + losses
        guard totalGames > 0 else { return 0 }
        return Double(wins) / Double(totalGames)
    }

    var rankedWinRate: Double {
        let totalGames = ranked_wins + ranked_losses
        guard totalGames > 0 else { return 0 }
        return Double(ranked_wins) / Double(totalGames)
    }

    var ladderWinRate: Double {
        let totalGames = ladder_wins + ladder_losses
        guard totalGames > 0 else { return 0 }
        return Double(ladder_wins) / Double(totalGames)
    }
}

struct ClanStatsResponse: Codable {
    let clan_name: String
    let clan_tag: String
    let members: [ClanMemberStats]
    let time_period: String
    let is_tracked: Bool
    let tracking_since: String?
}

struct TrackClanResponse: Codable {
    let message: String
    let clan_tag: String
    let clan_name: String
    let tracking_started: String
    let snapshot_created: Bool
}

enum ClanError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

class ClanService: ObservableObject {
    static let shared = ClanService()

    @Published var clanStats: ClanStatsResponse?
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let baseURL = "http://127.0.0.1:8001"

    @MainActor
    func fetchClanStats(clanTag: String, timePeriod: String) async throws -> ClanStatsResponse {
        isLoading = true
        errorMessage = ""

        // Encode clan tag
        let encodedTag = clanTag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clanTag

        guard let url = URL(string: "\(baseURL)/clan/\(encodedTag)/stats?time_period=\(timePeriod)") else {
            isLoading = false
            throw ClanError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                isLoading = false
                throw ClanError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let stats = try JSONDecoder().decode(ClanStatsResponse.self, from: data)
                self.clanStats = stats
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
                throw ClanError.networkError(NSError(domain: "ClanService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        } catch let error as ClanError {
            isLoading = false
            errorMessage = error.localizedDescription ?? "An error occurred"
            throw error
        } catch {
            isLoading = false
            errorMessage = "An unexpected error occurred"
            throw ClanError.networkError(error)
        }
    }

    @MainActor
    func startTracking(clanTag: String, token: String) async throws -> TrackClanResponse {
        let encodedTag = clanTag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clanTag

        guard let url = URL(string: "\(baseURL)/clan/\(encodedTag)/track") else {
            throw ClanError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClanError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let trackResponse = try JSONDecoder().decode(TrackClanResponse.self, from: data)
                return trackResponse
            } else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ClanError.networkError(NSError(domain: "ClanService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        } catch let error as ClanError {
            throw error
        } catch {
            throw ClanError.networkError(error)
        }
    }
}
