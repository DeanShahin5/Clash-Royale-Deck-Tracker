import SwiftUI

struct DeckCardView: View {
    let deck: Deck
    let rank: Int

    // Primary color for text/icons
    private var rankPrimaryColor: Color {
        switch rank {
        case 1:
            return Color(hex: "FFD700")
        case 2:
            return Color(hex: "C0C0C0")
        case 3:
            return Color(hex: "CD7F32")
        default:
            return .gray
        }
    }

    // Gradient for backgrounds
    private var rankGradient: LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(gradient: Gradient(
                gradient: Gradient(colors: [Color(hex: "FFD700"), Color(hex: "FFA500")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(gradient: Gradient(
                gradient: Gradient(colors: [Color(hex: "C0C0C0"), Color(hex: "A8A8A8")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(gradient: Gradient(
                gradient: Gradient(colors: [Color(hex: "CD7F32"), Color(hex: "B87333")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(gradient: Gradient(
                gradient: Gradient(colors: [.gray]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var rankEmoji: String {
        ["🥇", "🥈", "🥉"][rank - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(rankGradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: rankPrimaryColor.opacity(0.5), radius: 8, x: 0, y: 4)

                    Text(rankEmoji)
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Deck #\(rank)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Text("\(Int(deck.confidence * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(rankPrimaryColor)

                        Text("confidence")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                Image(systemName: "chart.bar.fill")
                    .foregroundColor(rankPrimaryColor)
                    .font(.system(size: 20))
            }

            // Confidence Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(rankGradient)
                        .frame(width: geometry.size.width * deck.confidence, height: 8)
                        .shadow(color: rankPrimaryColor.opacity(0.6), radius: 4, x: 0, y: 2)
                }
            }
            .frame(height: 8)

            Divider()
                .background(Color.white.opacity(0.1))

            // Cards
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 12))

                    Text("CARDS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.6))
                }

                FlowLayout(spacing: 8) {
                    ForEach(deck.deck, id: \.self) { card in
                        Text(card)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(gradient: Gradient(
                                gradient: Gradient(colors: [rankPrimaryColor.opacity(0.3), Color.white.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}
