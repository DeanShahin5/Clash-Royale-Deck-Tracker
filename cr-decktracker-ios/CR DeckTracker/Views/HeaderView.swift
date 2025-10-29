import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "FF3B30"), Color(hex: "FF1744")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "FF3B30").opacity(0.6), radius: 20, x: 0, y: 10)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.white, Color(hex: "FFEBEE")]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text("Deck Tracker")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
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
