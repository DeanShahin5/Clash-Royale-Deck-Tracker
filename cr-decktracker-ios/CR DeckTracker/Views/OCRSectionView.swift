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

            PhotosPicker(selection: $item, matching: .images) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Select Screenshot")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 12, x: 0, y: 6)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundColor(Color(hex: "667eea"))
                        .font(.system(size: 14))
                    Text("Scanned Text")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }

                Text(ocrText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(ocrText == "Tap to scan screenshot" ? .white.opacity(0.4) : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }

            if ocrText != "Tap to scan screenshot" {
                Button(action: onUseAsPlayerName) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Use as Player Name")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "667eea"))
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
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
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
