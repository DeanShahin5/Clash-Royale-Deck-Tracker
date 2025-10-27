import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(gradient: Gradient(
                            gradient: Gradient(colors: [Color(hex: "FFD700"), Color(hex: "FFA500")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "FFD700").opacity(0.5), radius: 20, x: 0, y: 10)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(gradient: Gradient(
                            gradient: Gradient(colors: [.white, Color(hex: "FFF4E0")]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text("Deck Tracker")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(gradient: Gradient(
                        gradient: Gradient(colors: [.white, Color(hex: "E0E0E0")]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("CLASH ROYALE")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundColor(Color(hex: "FFD700"))
        }
        .padding(.vertical, 20)
    }
}
