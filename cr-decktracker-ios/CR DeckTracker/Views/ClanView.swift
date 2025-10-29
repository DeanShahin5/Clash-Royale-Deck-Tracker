import SwiftUI

enum SortField {
    case name, value1, value2, value3
}

enum StatCategory: String, CaseIterable {
    case donations = "Donations"
    case war = "War"
    case battles = "Battles"
    case ranked = "Ranked"
    case ladder = "Ladder"
}

struct ClanView: View {
    @StateObject private var clanService = ClanService.shared
    @StateObject private var authService = AuthService.shared

    @State private var selectedTimePeriod = "current"
    @State private var selectedCategory: StatCategory = .donations
    @State private var sortField: SortField = .value3
    @State private var sortAscending = false
    @State private var clanTag: String?
    @State private var showNoClanTagMessage = false

    var timePeriodDisplay: String {
        switch selectedTimePeriod {
        case "current":
            return "Current Cycle (This Week)"
        case "historical":
            if let trackingSince = clanService.clanStats?.tracking_since {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: trackingSince) {
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateStyle = .medium
                    return "Since \(displayFormatter.string(from: date))"
                }
            }
            return "Since Tracking Started"
        default:
            return "Current Cycle"
        }
    }

    var sortedMembers: [ClanMemberStats] {
        guard let stats = clanService.clanStats else { return [] }

        let sorted = stats.members.sorted { member1, member2 in
            let comparison: Bool

            switch selectedCategory {
            case .donations:
                switch sortField {
                case .name:
                    comparison = member1.name < member2.name
                case .value1:
                    comparison = member1.donations < member2.donations
                case .value2:
                    comparison = member1.donations_received < member2.donations_received
                case .value3:
                    comparison = member1.totalDonations < member2.totalDonations
                }
            case .war:
                switch sortField {
                case .name:
                    comparison = member1.name < member2.name
                case .value1:
                    comparison = member1.war_attacks < member2.war_attacks
                case .value2:
                    comparison = member1.total_war_attacks < member2.total_war_attacks
                case .value3:
                    comparison = member1.warParticipationRate < member2.warParticipationRate
                }
            case .battles:
                switch sortField {
                case .name:
                    comparison = member1.name < member2.name
                case .value1:
                    comparison = member1.battles < member2.battles
                case .value2:
                    comparison = member1.wins < member2.wins
                case .value3:
                    comparison = member1.losses < member2.losses
                }
            case .ranked:
                switch sortField {
                case .name:
                    comparison = member1.name < member2.name
                case .value1:
                    comparison = member1.ranked_battles < member2.ranked_battles
                case .value2:
                    comparison = member1.ranked_wins < member2.ranked_wins
                case .value3:
                    comparison = member1.ranked_losses < member2.ranked_losses
                }
            case .ladder:
                switch sortField {
                case .name:
                    comparison = member1.name < member2.name
                case .value1:
                    comparison = member1.ladder_battles < member2.ladder_battles
                case .value2:
                    comparison = member1.ladder_wins < member2.ladder_wins
                case .value3:
                    comparison = member1.ladder_losses < member2.ladder_losses
                }
            }
            return sortAscending ? comparison : !comparison
        }
        return sorted
    }

    var body: some View {
        ZStack {
            // Background - Clean dark theme
            Color(hex: "0F1419")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "4A90E2"))
                                .frame(width: 70, height: 70)
                                .shadow(color: Color(hex: "4A90E2").opacity(0.4), radius: 15, x: 0, y: 5)

                            Image(systemName: "flag.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text(clanService.clanStats?.clan_name ?? "My Clan")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("CLAN STATISTICS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 20)

                    // Live Stats Info (removed time period selector - showing current week only)
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Week Stats")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)

                            Text("Live data from Supercell API")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(Color(hex: "00d4aa"))
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // Stat Category Tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(StatCategory.allCases, id: \.self) { category in
                                CategoryTab(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = category
                                            sortField = .value3 // Reset to default sort
                                            sortAscending = false
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Stats Table
                    if showNoClanTagMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "FF8C00"))

                            Text("No Clan Tag Found")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("Please sign up and add your clan tag to view clan statistics")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 60)
                    } else if clanService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .padding(.vertical, 40)
                    } else if !clanService.errorMessage.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "ff6b6b"))

                            Text("Error Loading Stats")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(clanService.errorMessage)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            Button(action: {
                                Task { await loadClanStats() }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color(hex: "E74C3C"))
                                .cornerRadius(10)
                                .shadow(color: Color(hex: "E74C3C").opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.vertical, 40)
                    } else if clanService.clanStats != nil {
                        VStack(alignment: .leading, spacing: 16) {
                            // Table Header
                            StatsTableHeader(
                                category: selectedCategory,
                                sortField: $sortField,
                                ascending: $sortAscending
                            )

                            // Member Rows
                            ForEach(sortedMembers) { member in
                                StatsTableRow(member: member, category: selectedCategory)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 16) {
                            Text("No clan data loaded")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))

                            Button(action: {
                                Task { await loadClanStats() }
                            }) {
                                Text("Load Stats")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "1ABC9C"))
                                    .cornerRadius(10)
                                    .shadow(color: Color(hex: "1ABC9C").opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.vertical, 40)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
            }
        }
        .onAppear {
            // Use logged-in user's clan tag if available
            if let userClanTag = authService.currentUser?.clan_tag, !userClanTag.isEmpty {
                clanTag = userClanTag
                showNoClanTagMessage = false
                Task {
                    await loadClanStats()
                }
            } else {
                // No clan tag available
                showNoClanTagMessage = true
                clanTag = nil
            }
        }
    }

    private func loadClanStats() async {
        guard let tag = clanTag, !tag.isEmpty else {
            showNoClanTagMessage = true
            return
        }

        do {
            // Always use "week" for current week stats (live API data only)
            _ = try await clanService.fetchClanStats(clanTag: tag, timePeriod: "week")
        } catch {
            print("Error loading clan stats: \(error)")
        }
    }

    private func startTracking() async {
        guard let tag = clanTag, !tag.isEmpty else {
            clanService.errorMessage = "No clan tag available"
            return
        }

        guard let token = UserDefaults.standard.string(forKey: "auth_token") else {
            print("No auth token found")
            return
        }

        do {
            let response = try await clanService.startTracking(clanTag: tag, token: token)
            print("✅ Tracking started: \(response.message)")

            // Reload stats to show tracking banner
            await loadClanStats()
        } catch {
            print("Error starting tracking: \(error)")
            clanService.errorMessage = "Failed to start tracking. Please try again."
        }
    }
}

struct CategoryTab: View {
    let category: StatCategory
    let isSelected: Bool
    let onTap: () -> Void

    var iconName: String {
        switch category {
        case .donations: return "gift.fill"
        case .war: return "flag.fill"
        case .battles: return "flame.fill"
        case .ranked: return "star.fill"
        case .ladder: return "trophy.fill"
        }
    }

    var accentColor: Color {
        switch category {
        case .donations: return Color(hex: "A569BD")  // Purple
        case .war: return Color(hex: "E74C3C")  // Red
        case .battles: return Color(hex: "3498DB")  // Blue
        case .ranked: return Color(hex: "4A90E2")  // Blue (Clash Royale theme)
        case .ladder: return Color(hex: "1ABC9C")  // Teal
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accentColor : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? accentColor : Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: isSelected ? accentColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
    }
}

struct StatsTableHeader: View {
    let category: StatCategory
    @Binding var sortField: SortField
    @Binding var ascending: Bool

    var columns: [(String, SortField)] {
        switch category {
        case .donations:
            return [("Name", .name), ("Given", .value1), ("Received", .value2), ("Total", .value3)]
        case .war:
            return [("Name", .name), ("Attacks", .value1), ("Total", .value2), ("Rate %", .value3)]
        case .battles:
            return [("Name", .name), ("Battles", .value1), ("Wins", .value2), ("Losses", .value3)]
        case .ranked:
            return [("Name", .name), ("Battles", .value1), ("Wins", .value2), ("Losses", .value3)]
        case .ladder:
            return [("Name", .name), ("Battles", .value1), ("Wins", .value2), ("Losses", .value3)]
        }
    }

    var accentColor: Color {
        switch category {
        case .donations: return Color(hex: "A569BD")
        case .war: return Color(hex: "E74C3C")
        case .battles: return Color(hex: "3498DB")
        case .ranked: return Color(hex: "4A90E2")
        case .ladder: return Color(hex: "1ABC9C")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(columns, id: \.0) { column in
                if column.0 == "Name" {
                    SortableHeaderButton(title: column.0, field: column.1, currentField: $sortField, ascending: $ascending, accentColor: accentColor)
                        .frame(minWidth: 100, alignment: .leading)
                } else {
                    SortableHeaderButton(title: column.0, field: column.1, currentField: $sortField, ascending: $ascending, accentColor: accentColor)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

struct StatsTableRow: View {
    let member: ClanMemberStats
    let category: StatCategory

    var body: some View {
        HStack(spacing: 8) {
            // Name (always first)
            Text(member.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(minWidth: 100, alignment: .leading)

            // Category-specific columns
            switch category {
            case .donations:
                Text("\(member.donations)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)

                Text("\(member.donations_received)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)

                Text("\(member.totalDonations)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "00d4aa"))
                    .frame(maxWidth: .infinity)

            case .war:
                Text("\(member.war_attacks)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)

                Text("\(member.total_war_attacks)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)

                Text(String(format: "%.0f%%", member.warParticipationRate * 100))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(member.warParticipationRate >= 0.75 ? Color(hex: "00d4aa") : .white.opacity(0.8))
                    .frame(maxWidth: .infinity)

            case .battles:
                Text("\(member.battles)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)

                Text("\(member.wins)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "00d4aa"))
                    .frame(maxWidth: .infinity)

                Text("\(member.losses)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "ff6b6b"))
                    .frame(maxWidth: .infinity)

            case .ranked:
                Text("\(member.ranked_battles)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)

                Text("\(member.ranked_wins)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "00d4aa"))
                    .frame(maxWidth: .infinity)

                Text("\(member.ranked_losses)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "ff6b6b"))
                    .frame(maxWidth: .infinity)

            case .ladder:
                Text("\(member.ladder_battles)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)

                Text("\(member.ladder_wins)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "00d4aa"))
                    .frame(maxWidth: .infinity)

                Text("\(member.ladder_losses)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "ff6b6b"))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

struct SortableHeaderButton: View {
    let title: String
    let field: SortField
    @Binding var currentField: SortField
    @Binding var ascending: Bool
    let accentColor: Color

    var body: some View {
        Button(action: {
            if currentField == field {
                ascending.toggle()
            } else {
                currentField = field
                ascending = false
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(currentField == field ? accentColor : .white.opacity(0.7))

                if currentField == field {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(accentColor)
                }
            }
        }
    }
}

struct TrackingStatusBanner: View {
    let trackingSince: String

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: trackingSince) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return trackingSince
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "00d4aa"))
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("Tracking Active")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Since \(formattedDate)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "00d4aa").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "00d4aa").opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

struct StartTrackingBanner: View {
    let onStartTracking: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color(hex: "FF8C00"))
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Tracking Stats")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Track historical donations, battles & medals over time")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button(action: onStartTracking) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14))
                    Text("Start Tracking")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "FF8C00"), Color(hex: "FFA500")]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: Color(hex: "FF8C00").opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "FF8C00").opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}
