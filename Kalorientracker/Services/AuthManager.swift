import AuthenticationServices
import Foundation

struct AuthUser {
    let email: String
    let displayName: String?
    let accessToken: String
}

@MainActor
final class AuthManager: ObservableObject {
    @Published var user: AuthUser?
    @Published var isLoading = false
    @Published var error: String?

    private let defaults = UserDefaults.standard

    init() {
        // Restore saved session
        if let token = defaults.string(forKey: "auth_access_token"),
           let email = defaults.string(forKey: "auth_email") {
            let name = defaults.string(forKey: "auth_display_name")
            user = AuthUser(email: email, displayName: name, accessToken: token)
        }
    }

    var isLoggedIn: Bool { user != nil }
    var accessToken: String? { user?.accessToken }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8) else {
                error = "Apple Sign-In fehlgeschlagen"
                return
            }

            // Apple only provides name/email on FIRST sign-in — save immediately
            if let email = appleIDCredential.email {
                defaults.set(email, forKey: "auth_email")
            }
            let fullName = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !fullName.isEmpty {
                defaults.set(fullName, forKey: "auth_display_name")
            }

            isLoading = true
            self.error = nil

            Task {
                let result = await exchangeTokenWithSupabase(idToken: idToken, provider: "apple")
                isLoading = false
                if let result {
                    // Use email/name from Supabase response, fallback to saved values
                    let email = result.email ?? defaults.string(forKey: "auth_email") ?? "Unbekannt"
                    let displayName = result.displayName ?? defaults.string(forKey: "auth_display_name")

                    let authUser = AuthUser(email: email, displayName: displayName, accessToken: result.token)
                    self.user = authUser
                    defaults.set(result.token, forKey: "auth_access_token")
                    defaults.set(email, forKey: "auth_email")
                    if let displayName { defaults.set(displayName, forKey: "auth_display_name") }
                } else {
                    self.error = "Supabase-Anmeldung fehlgeschlagen"
                }
            }

        case .failure(let err):
            if (err as NSError).code != ASAuthorizationError.canceled.rawValue {
                error = err.localizedDescription
            }
        }
    }

    func signOut() {
        user = nil
        defaults.removeObject(forKey: "auth_access_token")
        defaults.removeObject(forKey: "auth_email")
        defaults.removeObject(forKey: "auth_display_name")
    }

    private struct SupabaseAuthResult {
        let token: String
        let email: String?
        let displayName: String?
    }

    private func exchangeTokenWithSupabase(idToken: String, provider: String) async -> SupabaseAuthResult? {
        guard let url = URL(string: "\(Constants.supabaseURL)/auth/v1/token?grant_type=id_token") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 15

        let body: [String: String] = ["provider": provider, "id_token": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let token = json?["access_token"] as? String else { return nil }

            // Extract user info from Supabase response
            let userJson = json?["user"] as? [String: Any]
            let email = userJson?["email"] as? String
            let userMeta = userJson?["user_metadata"] as? [String: Any]
            let displayName = userMeta?["full_name"] as? String
                ?? userMeta?["name"] as? String

            return SupabaseAuthResult(token: token, email: email, displayName: displayName)
        } catch {
            return nil
        }
    }
}
