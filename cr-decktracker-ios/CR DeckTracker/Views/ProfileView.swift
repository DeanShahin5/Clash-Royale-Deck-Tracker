import SwiftUI

struct ProfileView: View {
    @StateObject private var playerService = PlayerService.shared
    @StateObject private var authService = AuthService.shared

    var body: some View {
        ZStack {
            // Background - Clean dark theme
            Color(hex: "0F1419")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "A569BD"))
                                .frame(width: 70, height: 70)
                                .shadow(color: Color(hex: "A569BD").opacity(0.4), radius: 15, x: 0, y: 5)

                            Image(systemName: "person.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }

                        if let playerStats = playerService.playerStats {
                            Text(playerStats.name)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)

                            HStack(spacing: 4) {
                                Text("Level \(playerStats.level)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .tracking(2)
                                    .foregroundColor(.white.opacity(0.6))

                                Text("•")
                                    .foregroundColor(.white.opacity(0.4))

                                Text(playerStats.arena.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .tracking(2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        } else {
                            Text("My Profile")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)

                            Text("PLAYER STATISTICS")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.top, 20)

                    // Loading or error state
                    if playerService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding(.vertical, 40)
                    } else if !playerService.errorMessage.isEmpty {
                        Text(playerService.errorMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "ff6b6b"))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 40)
                            .padding(.horizontal, 20)
                    } else if let stats = playerService.playerStats {
                        // Player Stats Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Color(hex: "4A90E2"))
                                    .shadow(color: Color(hex: "4A90E2").opacity(0.5), radius: 8, x: 0, y: 2)
                                Text("Player Stats")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            VStack(spacing: 16) {
                                StatRow(icon: "trophy.fill", label: "Trophies", value: "\(stats.trophies)")
                                StatRow(icon: "target", label: "Best Trophies", value: "\(stats.best_trophies)")
                                StatRow(icon: "gamecontroller.fill", label: "Total Battles", value: "\(stats.total_battles)")
                                StatRow(icon: "chart.line.uptrend.xyaxis", label: "Win Rate", value: String(format: "%.1f%%", stats.win_rate))
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)

                        // Battle Stats Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(Color(hex: "E74C3C"))
                                    .shadow(color: Color(hex: "E74C3C").opacity(0.5), radius: 8, x: 0, y: 2)
                                Text("Battle Stats")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            HStack(spacing: 20) {
                                BattleStatBox(label: "WINS", value: "\(stats.wins)", color: Color(hex: "1ABC9C"))
                                BattleStatBox(label: "LOSSES", value: "\(stats.losses)", color: Color(hex: "E74C3C"))
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)

                        // Recent Matches Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(Color(hex: "3498DB"))
                                    .shadow(color: Color(hex: "3498DB").opacity(0.5), radius: 8, x: 0, y: 2)
                                Text("Recent Matches")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            if stats.recent_battles.isEmpty {
                                Text("No recent battles")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 30)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(stats.recent_battles.prefix(5), id: \.battle_time) { battle in
                                        BattleRow(battle: battle)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)

                        // Top Decks Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .foregroundColor(Color(hex: "A569BD"))
                                    .shadow(color: Color(hex: "A569BD").opacity(0.5), radius: 8, x: 0, y: 2)
                                Text("Most Used Decks")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                            }

                            if stats.top_decks.isEmpty {
                                Text("No ranked battles yet")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 30)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(Array(stats.top_decks.enumerated()), id: \.offset) { index, deck in
                                        DeckUsageRow(rank: index + 1, deck: deck)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                    } else {
                        // No player tag set
                        VStack(spacing: 16) {
                            Text("No player tag found")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))

                            Text("Set your player tag in account settings")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.vertical, 40)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
            }
        }
        .onAppear {
            if let playerTag = authService.currentUser?.player_tag {
                Task {
                    try? await playerService.fetchPlayerStats(playerTag: playerTag)
                }
            }
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 14))
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

struct BattleStatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct BattleRow: View {
    let battle: BattleInfo

    var resultColor: Color {
        guard let result = battle.result else { return .white }
        switch result {
        case "win": return Color(hex: "00d4aa")
        case "loss": return Color(hex: "ff6b6b")
        default: return .white.opacity(0.7)
        }
    }

    var resultIcon: String {
        guard let result = battle.result else { return "minus.circle" }
        switch result {
        case "win": return "checkmark.circle.fill"
        case "loss": return "xmark.circle.fill"
        default: return "equal.circle"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Top row: Result icon, game mode, score
            HStack(spacing: 12) {
                Image(systemName: resultIcon)
                    .foregroundColor(resultColor)
                    .font(.system(size: 20, weight: .bold))

                VStack(alignment: .leading, spacing: 4) {
                    Text(battle.formattedType)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if let arena = battle.arena {
                        Text(arena)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(battle.crowns) - \(battle.opponent_crowns)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    if let result = battle.result {
                        Text(result.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(resultColor)
                    }
                }
            }

            // Bottom row: Opponent info and trophies
            HStack(spacing: 8) {
                if let opponentName = battle.opponent_name {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))

                    Text(opponentName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                if let playerTrophies = battle.player_trophies, let opponentTrophies = battle.opponent_trophies {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "FFD700"))

                        Text("\(playerTrophies)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))

                        Text("vs")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))

                        Text("\(opponentTrophies)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            // Time
            Text(battle.formattedTime)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(resultColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct DeckUsageRow: View {
    let rank: Int
    let deck: TopDeck

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("#\(rank)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(deck.confidence * 100))% usage")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Display deck cards in a grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
                ForEach(deck.deck, id: \.self) { card in
                    VStack(spacing: 4) {
                        Text(String(card.prefix(2)))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }
}
