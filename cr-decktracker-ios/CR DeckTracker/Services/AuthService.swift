import Foundation
import Combine

enum AuthError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        }
    }
}

struct AuthResponse: Codable {
    let token: String
    let email: String
    let player_tag: String?
    let clan_tag: String?
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let player_tag: String?
    let clan_tag: String?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct UpdateProfileRequest: Codable {
    let player_tag: String?
    let clan_tag: String?
}

class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isLoggedIn = false
    @Published var currentUser: AuthResponse?

    private let baseURL = "http://127.0.0.1:8001"
    private let tokenKey = "auth_token"

    private init() {
        // Check if user is already logged in
        if let token = getToken() {
            Task { @MainActor in
                await fetchCurrentUser(token: token)
            }
        }
    }

    @MainActor
    func register(email: String, password: String, playerTag: String?, clanTag: String?) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            throw AuthError.invalidURL
        }

        let request = RegisterRequest(
            email: email,
            password: password,
            player_tag: playerTag,
            clan_tag: clanTag
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                saveToken(authResponse.token)
                self.currentUser = authResponse
                self.isLoggedIn = true
                return authResponse
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.serverError(errorMessage)
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }

    @MainActor
    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw AuthError.invalidURL
        }

        let request = LoginRequest(email: email, password: password)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                saveToken(authResponse.token)
                self.currentUser = authResponse
                self.isLoggedIn = true
                return authResponse
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.serverError(errorMessage)
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }

    @MainActor
    func updateProfile(playerTag: String?, clanTag: String?) async throws {
        guard let url = URL(string: "\(baseURL)/auth/update-profile") else {
            throw AuthError.invalidURL
        }

        guard let token = getToken() else {
            throw AuthError.serverError("Not authenticated")
        }

        let request = UpdateProfileRequest(
            player_tag: playerTag,
            clan_tag: clanTag
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                saveToken(authResponse.token)
                self.currentUser = authResponse
                return
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.serverError(errorMessage)
            }
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error)
        }
    }

    @MainActor
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        self.currentUser = nil
        self.isLoggedIn = false
    }

    @MainActor
    private func fetchCurrentUser(token: String) async {
        guard let url = URL(string: "\(baseURL)/auth/me") else { return }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                self.currentUser = authResponse
                self.isLoggedIn = true
            } else {
                // Token is invalid, remove it
                logout()
            }
        } catch {
            print("Error fetching current user: \(error)")
            logout()
        }
    }

    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    private func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }
}
