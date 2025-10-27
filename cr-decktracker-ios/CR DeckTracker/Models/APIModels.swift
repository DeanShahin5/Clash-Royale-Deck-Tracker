import Foundation

// MARK: - API Request Models

struct ResolveByNameRequest: Codable {
    let player_name: String
    let clan_name: String
}

// MARK: - API Response Models

struct ResolveResponse: Codable {
    let player_tag: String
    let name: String
    let confidence: Int
}

struct Deck: Codable, Identifiable {
    let deck: [String]
    let confidence: Double

    var id: String {
        deck.joined(separator: "-")
    }
}

struct PredictResponse: Codable {
    let player_tag: String
    let top3: [Deck]
    let cached: Bool?
}
