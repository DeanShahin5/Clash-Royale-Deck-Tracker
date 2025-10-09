import SwiftUI
import PhotosUI
import Vision
import UIKit

struct ResolveResp: Codable {
    let player_tag: String
    let name: String
    let confidence: Int
}

struct Deck: Codable {
    let deck: [String]
    let confidence: Double
}

struct PredictResp: Codable {
    let player_tag: String
    let top3: [Deck]
}

struct ContentView: View {
    @State private var item: PhotosPickerItem?
    @State private var ocrText = "Tap to scan screenshot"
    @State private var playerName = ""
    @State private var clanName = ""
    @State private var result = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    
    let apiBase = URL(string: "http://127.0.0.1:8001")!

    var body: some View {
        ZStack {
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    ocrCardView
                    inputCardView
                    resultsCardView
                    Spacer(minLength: 40)
                }
            }
        }
        .onChange(of: item) { _ in Task { await handlePick() } }
        .onAppear {
            // Listen for scanned text from Share Extension
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ScannedTextReceived"),
                object: nil,
                queue: .main
            ) { notification in
                if let text = notification.userInfo?["text"] as? String {
                    withAnimation {
                        self.playerName = text
                        self.ocrText = text
                    }
                }
            }
            
            // Check for shared data when app opens
            if let sharedDefaults = UserDefaults(suiteName: "group.com.dean.decktracker"),
               let text = sharedDefaults.string(forKey: "lastScannedText"),
               let date = sharedDefaults.object(forKey: "lastScanDate") as? Date {
                
                // Only use if recent (within last 10 seconds)
                if Date().timeIntervalSince(date) < 10 {
                    withAnimation {
                        self.playerName = text
                        self.ocrText = text
                    }
                    // Clear it
                    sharedDefaults.removeObject(forKey: "lastScannedText")
                }
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("Deck Tracker")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text("Clash Royale")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }
    
    private var ocrCardView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundColor(Color(hex: "5e72e4"))
                Text("Screenshot Scanner")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            PhotosPicker(selection: $item, matching: .images) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text("Pick Screenshot")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "5e72e4"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Text(ocrText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(ocrText == "Tap to scan screenshot" ? .white.opacity(0.5) : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            
            if ocrText != "Tap to scan screenshot" {
                Button(action: { playerName = ocrText }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Use as Player Name")
                            .font(.subheadline)
                    }
                    .foregroundColor(Color(hex: "5e72e4"))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var inputCardView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundColor(Color(hex: "11cdef"))
                Text("Player Details")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                CustomTextField(
                    icon: "person.fill",
                    placeholder: "Player Name",
                    text: $playerName
                )
                
                CustomTextField(
                    icon: "flag.filled.and.flag.crossed",
                    placeholder: "Clan Name",
                    text: $clanName
                )
            }
            
            Button(action: { Task { await resolveAndPredict() } }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                        Text("Find Decks")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    playerName.isEmpty || clanName.isEmpty
                    ? Color.gray.opacity(0.3)
                    : Color(hex: "11cdef")
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(playerName.isEmpty || clanName.isEmpty || isLoading)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var resultsCardView: some View {
        if !result.isEmpty {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: showSuccess ? "checkmark.circle.fill" : "list.bullet.rectangle")
                        .foregroundColor(showSuccess ? Color(hex: "2dce89") : Color(hex: "fb6340"))
                    Text("Results")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Text(result)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .padding(.horizontal)
            .transition(.scale.combined(with: .opacity))
        }
    }

    func handlePick() async {
        guard let item else { return }
        ocrText = "Scanning..."
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            do {
                let text = try await ocr(from: img)
                withAnimation {
                    ocrText = text.isEmpty ? "No text found" : text
                }
            } catch {
                withAnimation {
                    ocrText = "OCR failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func ocr(from image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { return "" }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg)
        try handler.perform([req])
        let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return lines.joined(separator: " ")
    }

    func resolveAndPredict() async {
        withAnimation {
            isLoading = true
            showSuccess = false
            result = "🔍 Searching for player in '\(clanName)'..."
        }
        
        guard !playerName.isEmpty, !clanName.isEmpty else {
            withAnimation {
                isLoading = false
                result = "⚠️ Please enter both player name and clan name"
            }
            return
        }
        
        do {
            // 1) Resolve by clan name
            var req = URLRequest(url: apiBase.appendingPathComponent("/resolve_player_by_name"))
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["player_name": playerName, "clan_name": clanName]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data1, response1) = try await URLSession.shared.data(for: req)
            
            if let httpResponse = response1 as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let rawText = String(data: data1, encoding: .utf8) {
                    withAnimation {
                        isLoading = false
                        result = "❌ Error \(httpResponse.statusCode)\n\n\(rawText)"
                    }
                }
                return
            }
            
            let resolved = try JSONDecoder().decode(ResolveResp.self, from: data1)

            // 2) Predict
            withAnimation {
                result = "✓ Found \(resolved.name) (\(resolved.confidence)% match)\n⏳ Loading battle history..."
            }
            
            let url = apiBase.appendingPathComponent("/predict/\(resolved.player_tag)")
            let (data2, _) = try await URLSession.shared.data(from: url)
            let pred = try JSONDecoder().decode(PredictResp.self, from: data2)

            if pred.top3.isEmpty {
                withAnimation {
                    isLoading = false
                    result = "✓ Found \(resolved.name)\n⚠️ No recent ranked battles available"
                }
                return
            }

            let lines = pred.top3.enumerated().map { (i, d) in
                let emoji = ["🥇", "🥈", "🥉"][i]
                let percentage = Int(d.confidence * 100)
                let cards = d.deck.joined(separator: " • ")
                return "\(emoji) Deck \(i+1) (\(percentage)%)\n   \(cards)"
            }.joined(separator: "\n\n")

            withAnimation {
                isLoading = false
                showSuccess = true
                result = "👑 \(resolved.name)\n━━━━━━━━━━━━━━━━━\n\n\(lines)"
            }
        } catch let decodingError as DecodingError {
            withAnimation {
                isLoading = false
                result = "❌ Decoding error:\n\(decodingError)"
            }
        } catch {
            withAnimation {
                isLoading = false
                result = "❌ Error:\n\(error.localizedDescription)"
            }
        }
    }
}

// Custom TextField Component
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 20)
            
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.5)))
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
