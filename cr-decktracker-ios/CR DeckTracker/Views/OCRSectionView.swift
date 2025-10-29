import SwiftUI
import PhotosUI

struct OCRSectionView: View {
    @Binding var item: PhotosPickerItem?
    @Binding var ocrText: String
    let onUseAsPlayerName: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Screenshot Scanner", systemImage: "camera.viewfinder")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }

            // Interactive Scan Zone - Reduced Size
            PhotosPicker(selection: $item, matching: .images) {
                VStack(spacing: 12) {
                    // Camera Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Color(hex: "4A90E2").opacity(0.5), radius: 12, x: 0, y: 6)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 4) {
                        Text("Tap to Scan")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Select a screenshot")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.black.opacity(0.3))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .padding(.horizontal, 30)

            // Scanned Text Display
            if ocrText != "Tap to scan screenshot" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                            .foregroundColor(Color(hex: "3B7DD6"))
                            .font(.system(size: 14))
                        Text("Scanned Text")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }

                    Text(ocrText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(hex: "3B7DD6").opacity(0.3), lineWidth: 1)
                        )
                }
                .transition(.scale.combined(with: .opacity))

                Button(action: onUseAsPlayerName) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Use as Player Name")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "4A90E2"))
                    .padding(.vertical, 8)
                }
                .transition(.scale.combined(with: .opacity))
            }
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
