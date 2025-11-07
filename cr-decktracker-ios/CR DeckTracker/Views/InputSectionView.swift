import SwiftUI
import PhotosUI

struct InputSectionView: View {
    @Binding var playerName: String
    @Binding var clanName: String
    @Binding var isLoading: Bool
    @Binding var gameMode: String
    @Binding var ocrText: String
    @Binding var item: PhotosPickerItem?
    let onFindDecks: () -> Void
    let onUseAsPlayerName: () -> Void

    @State private var showingImageSourceAction = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?

    private var isButtonDisabled: Bool {
        playerName.isEmpty || clanName.isEmpty || isLoading
    }

    var body: some View {
        VStack(spacing: 18) {
            // Header
            HStack {
                Label("Player Information", systemImage: "person.text.rectangle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "2C3E50"))
                Spacer()
            }

            // OCR Scan Button - Prominent at top
            Button(action: {
                showingImageSourceAction = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: Color(hex: "4A90E2").opacity(0.3), radius: 6, x: 0, y: 3)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ocrText == "Tap to scan screenshot" ? "Scan Player Name" : ocrText)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(ocrText == "Tap to scan screenshot" ? Color(hex: "2C3E50") : Color(hex: "1e3a5f"))
                            .lineLimit(1)

                        Text(ocrText == "Tap to scan screenshot" ? "Camera or Library" : "Tap to scan again")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "7F8C8D"))
                    }

                    Spacer()

                    if ocrText != "Tap to scan screenshot" && ocrText != "Scanning..." {
                        Button(action: onUseAsPlayerName) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(Color(hex: "4A90E2"))
                                    .font(.system(size: 20))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: "F8F9FA"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "2C3E50"), lineWidth: 2)
                )
            }
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
            .onChange(of: capturedImage) { newImage in
                if let image = newImage {
                    Task {
                        await processImage(image)
                    }
                }
            }

            // Game Mode Picker - Below scanner
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundColor(Color(hex: "4A90E2"))
                        .font(.system(size: 12))
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

            // Input Fields
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

            // Find Decks Button
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
