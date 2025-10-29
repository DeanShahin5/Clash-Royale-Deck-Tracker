import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authService = AuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var playerTag = ""
    @State private var clanTag = ""

    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isSignUpMode = false

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "FF8C00"), Color(hex: "FFA500")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .shadow(color: Color(hex: "FF8C00").opacity(0.5), radius: 20, x: 0, y: 10)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(isSignUpMode ? "Sign Up" : "Login")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text(isSignUpMode ? "Create your account" : "Welcome back")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 40)
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)

                SecureField("", text: $password, prompt: Text("Password").foregroundColor(.white.opacity(0.4)))
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 22)

                SecureField("", text: $confirmPassword, prompt: Text("Confirm Password").foregroundColor(.white.opacity(0.4)))
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.25))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var submitButton: some View {
        Button(action: {
            Task { await handleAuth() }
        }) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: isSignUpMode ? "person.badge.plus" : "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(isSignUpMode ? "Sign Up" : "Login")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "FF8C00"), Color(hex: "FFA500")]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
            .shadow(color: Color(hex: "FF8C00").opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .disabled(isLoading || !isFormValid)
        .opacity((isLoading || !isFormValid) ? 0.6 : 1.0)
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1e2a50"),
                    Color(hex: "1f2d5c"),
                    Color(hex: "1a2345")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerView

                    // Form
                    VStack(spacing: 16) {
                        // Email
                        ModernTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email,
                            accentColor: Color(hex: "FF8C00")
                        )

                        // Password
                        passwordField

                        // Confirm Password (Sign Up only)
                        if isSignUpMode {
                            confirmPasswordField
                        }

                        // Optional fields for Sign Up
                        if isSignUpMode {
                            ModernTextField(
                                icon: "number",
                                placeholder: "Player Tag (Optional)",
                                text: $playerTag,
                                accentColor: Color(hex: "3B7DD6")
                            )

                            ModernTextField(
                                icon: "flag.fill",
                                placeholder: "Clan Tag (Optional)",
                                text: $clanTag,
                                accentColor: Color(hex: "8E44AD")
                            )
                        }

                        // Error message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "ff6b6b"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }

                        // Submit button
                        submitButton

                        // Toggle mode
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSignUpMode.toggle()
                                errorMessage = ""
                                confirmPassword = ""
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUpMode ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.white.opacity(0.6))
                                Text(isSignUpMode ? "Login" : "Sign Up")
                                    .foregroundColor(Color(hex: "FF8C00"))
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 14, design: .rounded))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
        }
        .onChange(of: authService.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                dismiss()
            }
        }
    }

    private func handleAuth() async {
        isLoading = true
        errorMessage = ""

        // Email validation
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address"
            isLoading = false
            return
        }

        // Password confirmation check for sign up
        if isSignUpMode {
            if password.isEmpty {
                errorMessage = "Password cannot be empty"
                isLoading = false
                return
            }

            if password != confirmPassword {
                errorMessage = "Passwords do not match"
                isLoading = false
                return
            }

            if password.count < 6 {
                errorMessage = "Password must be at least 6 characters"
                isLoading = false
                return
            }
        }

        do {
            if isSignUpMode {
                _ = try await authService.register(
                    email: email,
                    password: password,
                    playerTag: playerTag.isEmpty ? nil : playerTag,
                    clanTag: clanTag.isEmpty ? nil : clanTag
                )
            } else {
                _ = try await authService.login(email: email, password: password)
            }

            // Success - view will dismiss automatically via onChange
        } catch let error as AuthError {
            errorMessage = error.localizedDescription ?? "An error occurred"
        } catch {
            errorMessage = "An unexpected error occurred"
        }

        isLoading = false
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
