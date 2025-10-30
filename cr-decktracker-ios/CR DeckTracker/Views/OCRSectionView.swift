import SwiftUI
import PhotosUI

struct OCRSectionView: View {
    @Binding var item: PhotosPickerItem?
    @Binding var ocrText: String
    let onUseAsPlayerName: () -> Void

    @State private var showingImageSourceAction = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Screenshot Scanner", systemImage: "camera.viewfinder")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "2C3E50"))
                Spacer()
            }

            // Interactive Scan Zone - 80% Size
            Button(action: {
                showingImageSourceAction = true
            }) {
                VStack(spacing: 10) {
                    // Camera Icon (80% of 56 = 44.8)
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 45, height: 45)
                            .shadow(color: Color(hex: "4A90E2").opacity(0.3), radius: 6, x: 0, y: 3)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 3) {
                        Text("Tap to Scan")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "2C3E50"))

                        Text("Camera or Library")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "7F8C8D"))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background(Color(hex: "F5F7FA"))
                .cornerRadius(11)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.6, dash: [6.4, 4.8])
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
            .confirmationDialog("Choose Image Source", isPresented: $showingImageSourceAction, titleVisibility: .hidden) {
                Button("📷 Take Photo") {
                    showingCamera = true
                }
                Button("🖼️ Choose from Library") {
                    showingPhotoLibrary = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $capturedImage, sourceType: .photoLibrary)
            }

            // Scanned Text Display
            if ocrText != "Tap to scan screenshot" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                            .foregroundColor(Color(hex: "4A90E2"))
                            .font(.system(size: 14))
                        Text("Scanned Text")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "7F8C8D"))
                        Spacer()
                    }

                    Text(ocrText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "2C3E50"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(hex: "F5F7FA"))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(hex: "4A90E2").opacity(0.2), lineWidth: 1)
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
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .onChange(of: capturedImage) { newImage in
            if let image = newImage {
                Task {
                    await processImage(image)
                }
            }
        }
    }

    private func processImage(_ image: UIImage) async {
        ocrText = "Scanning..."

        do {
            let text = try await OCRService.shared.extractText(from: image)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                ocrText = text
            }
        } catch {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                ocrText = error.localizedDescription
            }
        }
    }
}
