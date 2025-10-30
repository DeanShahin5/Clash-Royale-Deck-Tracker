import SwiftUI

struct AccountDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared

    @State private var playerTag = ""
    @State private var clanTag = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showLogoutAlert = false

    var body: some View {
        ZStack {
            // Background - Grey theme matching Scanner
            Color(hex: "E5E7EB")
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

                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Account Settings")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Manage your profile")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .padding(.top, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "1e3a5f"), Color(hex: "0F1419")]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Form Card
                    VStack(alignment: .leading, spacing: 20) {
                        // Email (read-only)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(Color(hex: "4A90E2"))
                                    .font(.system(size: 14))
                                Text("Email")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "7F8C8D"))
                                Spacer()
                            }

                            Text(authService.currentUser?.email ?? "No email")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "2C3E50"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color(hex: "F5F7FA"))
                                .cornerRadius(10)
                        }

                        // Player Tag (editable)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "number")
                                    .foregroundColor(Color(hex: "4A90E2"))
                                    .font(.system(size: 14))
                                Text("Player Tag")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "7F8C8D"))
                                Spacer()
                            }

                            ModernTextField(
                                icon: "number",
                                placeholder: "Player Tag (e.g., #ABC123)",
                                text: $playerTag,
                                accentColor: Color(hex: "4A90E2")
                            )
                        }

                        // Clan Tag (editable)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(Color(hex: "4A90E2"))
                                    .font(.system(size: 14))
                                Text("Clan Tag")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "7F8C8D"))
                                Spacer()
                            }

                            ModernTextField(
                                icon: "flag.fill",
                                placeholder: "Clan Tag (e.g., #XYZ789)",
                                text: $clanTag,
                                accentColor: Color(hex: "4A90E2")
                            )
                        }

                        // Messages
                        if !successMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "00d4aa"))
                                Text(successMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(hex: "2C3E50"))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "00d4aa").opacity(0.1))
                            .cornerRadius(10)
                        }

                        if !errorMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(Color(hex: "ff6b6b"))
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(hex: "2C3E50"))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "ff6b6b").opacity(0.1))
                            .cornerRadius(10)
                        }

                        // Save Changes Button
                        Button(action: {
                            Task { await saveChanges() }
                        }) {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Save Changes")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "4A90E2"), Color(hex: "5B9BD5")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "4A90E2").opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.6 : 1.0)

                        // Log Out Button
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.right.square.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Log Out")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "E74C3C"))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "E74C3C").opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
                    )
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                authService.logout()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .onAppear {
            // Load current values
            playerTag = authService.currentUser?.player_tag ?? ""
            clanTag = authService.currentUser?.clan_tag ?? ""
        }
    }

    private func saveChanges() async {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        do {
            try await authService.updateProfile(
                playerTag: playerTag.isEmpty ? nil : playerTag,
                clanTag: clanTag.isEmpty ? nil : clanTag
            )

            successMessage = "Profile updated successfully!"

            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                successMessage = ""
            }
        } catch let error as AuthError {
            errorMessage = error.localizedDescription ?? "Failed to update profile"
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }
}
