import SwiftUI
import PhotosUI

struct MainTabView: View {
    @State private var selectedTab = 1 // Start with Scanner tab (center)
    @State private var showLoginSheet = false
    @State private var showAccountDetails = false
    @StateObject private var authService = AuthService.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedTab) {
                // Clan Tab
                ClanView()
                    .tabItem {
                        Label("My Clan", systemImage: "chart.bar.fill")
                    }
                    .tag(0)

                // Scanner Tab (Default/Center)
                ScannerView()
                    .tabItem {
                        Label("Scanner", systemImage: "viewfinder")
                    }
                    .tag(1)

                // Profile Tab
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(2)
            }
            .accentColor(Color(hex: "4A90E2"))

            // Profile Icon Button (Top-Right)
            Button(action: {
                if authService.isLoggedIn {
                    showAccountDetails = true
                } else {
                    showLoginSheet = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(
                            authService.isLoggedIn
                            ? LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "10B981"), Color(hex: "059669")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: (authService.isLoggedIn ? Color(hex: "10B981") : Color(hex: "4A90E2")).opacity(0.4), radius: 8, x: 0, y: 4)

                    Image(systemName: authService.isLoggedIn ? "checkmark.circle.fill" : "person.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 50)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
        }
        .sheet(isPresented: $showAccountDetails) {
            AccountDetailsView()
        }
    }
}

// Renamed ContentView to ScannerView for clarity
struct ScannerView: View {
    // MARK: - State
    @State private var item: PhotosPickerItem?
    @State private var ocrText = "Tap to scan screenshot"
    @State private var playerName = ""
    @State private var clanName = ""
    @State private var gameMode = "ranked"  // Default to ranked mode
    @State private var isLoading = false
    @State private var statusMessage = ""

    // Results
    @State private var predictedDecks: [Deck] = []
    @State private var resolvedPlayerName = ""
    @State private var errorMessage = ""

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                VStack(spacing: 24) {
                    HeaderView()

                    OCRSectionView(
                        item: $item,
                        ocrText: $ocrText,
                        onUseAsPlayerName: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                playerName = ocrText
                            }
                        }
                    )

                    InputSectionView(
                        playerName: $playerName,
                        clanName: $clanName,
                        isLoading: $isLoading,
                        gameMode: $gameMode,
                        onFindDecks: {
                            Task { await resolveAndPredict() }
                        }
                    )

                    if isLoading {
                        LoadingView(statusMessage: statusMessage)
                    } else if !predictedDecks.isEmpty {
                        ResultsView(
                            decks: predictedDecks,
                            playerName: resolvedPlayerName
                        )
                    } else if !errorMessage.isEmpty {
                        ErrorView(errorMessage: errorMessage)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
            }
        }
        .onChange(of: item) { _ in
            Task { await handlePhotoPick() }
        }
        .onAppear(perform: setupShareExtensionListener)
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "E5E7EB"),
                Color(hex: "D1D5DB"),
                Color(hex: "E5E7EB")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Photo Handling
    private func handlePhotoPick() async {
        guard let item else { return }

        ocrText = "Scanning..."

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                ocrText = "Failed to load image"
            }
            return
        }

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

    // MARK: - API Integration
    private func resolveAndPredict() async {
        // Reset state
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isLoading = true
            statusMessage = "Searching for player..."
            predictedDecks = []
            resolvedPlayerName = ""
            errorMessage = ""
        }

        // Validate input
        guard !playerName.isEmpty, !clanName.isEmpty else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isLoading = false
                errorMessage = "Please enter both player name and clan name"
            }
            return
        }

        do {
            // Call API with selected game mode
            let (player, prediction) = try await APIService.shared.resolveAndPredict(
                playerName: playerName,
                clanName: clanName,
                gameMode: gameMode
            )

            // Update UI with results
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isLoading = false
                predictedDecks = prediction.top3
                resolvedPlayerName = "\(player.name) • \(player.confidence)% match"

                // Check if no battles found
                if prediction.top3.isEmpty {
                    let modeName = gameMode == "ladder" ? "Ladder (Trophy Road)" : (gameMode == "ranked" ? "Ranked (Path of Legend)" : "")
                    errorMessage = "Found \(player.name) but no \(modeName) battles available"
                    predictedDecks = []
                }
            }
        } catch let error as APIError {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isLoading = false
                errorMessage = error.localizedDescription ?? "An unknown error occurred"
            }
        } catch {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isLoading = false
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Share Extension Support
    private func setupShareExtensionListener() {
        // Listen for notifications from Share Extension
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ScannedTextReceived"),
            object: nil,
            queue: .main
        ) { notification in
            if let text = notification.userInfo?["text"] as? String {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    self.playerName = text
                    self.ocrText = text
                }
            }
        }

        // Check for shared data from Share Extension
        if let sharedDefaults = UserDefaults(suiteName: "group.com.dean.decktracker"),
           let text = sharedDefaults.string(forKey: "lastScannedText"),
           let date = sharedDefaults.object(forKey: "lastScanDate") as? Date {

            // Only use if recent (within last 10 seconds)
            if Date().timeIntervalSince(date) < 10 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    self.playerName = text
                    self.ocrText = text
                }
                // Clear it after use
                sharedDefaults.removeObject(forKey: "lastScannedText")
            }
        }
    }
}
