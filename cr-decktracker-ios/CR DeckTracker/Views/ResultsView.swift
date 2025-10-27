import SwiftUI

struct ResultsView: View {
    let decks: [Deck]
    let playerName: String

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(
                        LinearGradient(gradient: Gradient(
                            gradient: Gradient(colors: [Color(hex: "FFD700"), Color(hex: "FFA500")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.system(size: 20, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Predicted Decks")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if !playerName.isEmpty {
                        Text(playerName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Color(hex: "00d4aa"))
                    .font(.system(size: 24))
            }
            .padding(.horizontal, 20)

            VStack(spacing: 14) {
                ForEach(Array(decks.enumerated()), id: \.offset) { index, deck in
                    DeckCardView(deck: deck, rank: index + 1)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
    }
}
