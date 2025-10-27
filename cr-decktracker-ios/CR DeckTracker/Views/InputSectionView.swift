import SwiftUI

struct InputSectionView: View {
    @Binding var playerName: String
    @Binding var clanName: String
    @Binding var isLoading: Bool
    let onFindDecks: () -> Void

    private var isButtonDisabled: Bool {
        playerName.isEmpty || clanName.isEmpty || isLoading
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Player Information", systemImage: "person.text.rectangle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }

            VStack(spacing: 12) {
                ModernTextField(
                    icon: "person.fill",
                    placeholder: "Player Name",
                    text: $playerName,
                    accentColor: Color(hex: "4facfe")
                )

                ModernTextField(
                    icon: "flag.fill",
                    placeholder: "Clan Name",
                    text: $clanName,
                    accentColor: Color(hex: "00f2fe")
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
                            Color.gray.opacity(0.3)
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "f093fb"), Color(hex: "f5576c")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(
                    color: isButtonDisabled ? .clear : Color(hex: "f5576c").opacity(0.4),
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
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
}
