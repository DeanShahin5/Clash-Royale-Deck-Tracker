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
    @State private var ocrText = "Pick a screenshot to OCR"
    @State private var playerName = ""
    @State private var clanName = ""
    @State private var result = ""
    
    let apiBase = URL(string: "http://127.0.0.1:8001")!

    var body: some View {
        VStack(spacing: 12) {
            Text("Clash Royale Deck Tracker")
                .font(.title3)
                .bold()

            PhotosPicker("Pick Screenshot", selection: $item, matching: .images)
                .padding(.bottom, 6)

            TextEditor(text: $ocrText)
                .frame(height: 80)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray))
                .padding(.horizontal)

            VStack(spacing: 8) {
                TextField("Player name", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                
                TextField("Clan name (not tag)", text: $clanName)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
            }
            .padding(.horizontal)

            HStack {
                Button("Use OCR as name") {
                    playerName = ocrText
                }
                Button("Resolve → Predict") {
                    Task { await resolveAndPredict() }
                }
            }

            ScrollView {
                Text(result)
                    .padding()
            }
        }
        .padding()
        .onChange(of: item) { _ in Task { await handlePick() } }
    }

    func handlePick() async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            do {
                ocrText = try await ocr(from: img)
            } catch {
                ocrText = "OCR failed: \(error.localizedDescription)"
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
        result = "Searching for player in clans named '\(clanName)'…"
        guard !playerName.isEmpty, !clanName.isEmpty else {
            result = "Enter both player name and clan name."
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
                    result = "HTTP \(httpResponse.statusCode)\n\(rawText)"
                }
                return
            }
            
            let resolved = try JSONDecoder().decode(ResolveResp.self, from: data1)

            // 2) Predict
            result = "Found \(resolved.name) (\(resolved.confidence)% match)\nFetching decks…"
            let url = apiBase.appendingPathComponent("/predict/\(resolved.player_tag)")
            let (data2, _) = try await URLSession.shared.data(from: url)
            let pred = try JSONDecoder().decode(PredictResp.self, from: data2)

            if pred.top3.isEmpty {
                result = "Found \(resolved.name), but no recent battle history available."
                return
            }

            let lines = pred.top3.enumerated().map { (i, d) in
                "\(i+1). \(d.deck.joined(separator: ", "))  (\(Int(d.confidence * 100))%)"
            }.joined(separator: "\n")

            result = "Top decks for \(resolved.name):\n\(lines)"
        } catch let decodingError as DecodingError {
            result = "Decoding error: \(decodingError)"
        } catch {
            result = "Error: \(error.localizedDescription)"
        }
    }
}
