import SwiftUI

struct DeckCardView: View {
    let deck: Deck
    let rank: Int

    // Primary color for text/icons
    private var rankPrimaryColor: Color {
        switch rank {
        case 1:
            return Color(hex: "4A90E2")
        case 2:
            return Color(hex: "5B9BD5")
        case 3:
            return Color(hex: "7FB3D5")
        default:
            return .gray
        }
    }

    // Gradient for backgrounds
    private var rankGradient: LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "5B9BD5"), Color(hex: "7FB3D5")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "7FB3D5"), Color(hex: "A4C9E0")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
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
                        .foregroundColor(Color(hex: "2C3E50"))

                    HStack(spacing: 8) {
                        Text("\(Int(deck.confidence * 100))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(rankPrimaryColor)

                        Text("confidence")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "7F8C8D"))
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
                        .fill(Color(hex: "E0E6ED"))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(rankGradient)
                        .frame(width: geometry.size.width * deck.confidence, height: 8)
                        .shadow(color: rankPrimaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            .frame(height: 8)

            Divider()
                .background(Color(hex: "E0E6ED"))

            // Cards
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(Color(hex: "7F8C8D"))
                        .font(.system(size: 12))

                    Text("CARDS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(Color(hex: "7F8C8D"))
                }

                FlowLayout(spacing: 8) {
                    ForEach(deck.deck, id: \.self) { card in
                        Text(card)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "2C3E50"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "F5F7FA"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color(hex: "E0E6ED"), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [rankPrimaryColor.opacity(0.3), Color(hex: "E0E6ED")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
    }
}
