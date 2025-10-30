import SwiftUI

struct InputSectionView: View {
    @Binding var playerName: String
    @Binding var clanName: String
    @Binding var isLoading: Bool
    @Binding var gameMode: String
    let onFindDecks: () -> Void

    private var isButtonDisabled: Bool {
        playerName.isEmpty || clanName.isEmpty || isLoading
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Player Information", systemImage: "person.text.rectangle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "2C3E50"))
                Spacer()
            }

            // Game Mode Selector
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(Color(hex: "4A90E2"))
                        .font(.system(size: 14))
                    Text("Game Mode")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "7F8C8D"))
                    Spacer()
                }

                Picker("Game Mode", selection: $gameMode) {
                    Text("Ranked").tag("ranked")
                    Text("Ladder").tag("ladder")
                }
                .pickerStyle(.segmented)
                .colorMultiply(Color(hex: "4A90E2"))
            }

            VStack(spacing: 12) {
                ModernTextField(
                    icon: "person.fill",
                    placeholder: "Player Name",
                    text: $playerName,
                    accentColor: Color(hex: "4A90E2")
                )

                ModernTextField(
                    icon: "flag.fill",
                    placeholder: "Clan Name",
                    text: $clanName,
                    accentColor: Color(hex: "4A90E2")
                )
            }

            Button(action: onFindDecks) {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                        Text("Find Decks")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if isButtonDisabled {
                            Color(hex: "BDC3C7")
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(
                    color: isButtonDisabled ? .clear : Color(hex: "4A90E2").opacity(0.3),
                    radius: 12,
                    x: 0,
                    y: 6
                )
            }
            .disabled(isButtonDisabled)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isButtonDisabled)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
}
