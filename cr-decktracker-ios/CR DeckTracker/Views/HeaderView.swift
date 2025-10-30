import SwiftUI

struct HeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer glow layers for soft blue emanation
                Circle()
                    .fill(Color(hex: "4A90E2").opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                Circle()
                    .fill(Color(hex: "4A90E2").opacity(0.2))
                    .frame(width: 90, height: 90)
                    .blur(radius: 15)

                // Main crown circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "4A90E2").opacity(0.5), radius: 25, x: 0, y: 0)
                    .shadow(color: Color(hex: "4A90E2").opacity(0.3), radius: 15, x: 0, y: 5)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Deck Tracker")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "2C3E50"))

            Text("CLASH ROYALE")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundColor(Color(hex: "4A90E2"))
        }
        .padding(.vertical, 20)
    }
}
