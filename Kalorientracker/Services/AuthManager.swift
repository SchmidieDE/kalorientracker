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

            let email = appleIDCredential.email ?? defaults.string(forKey: "auth_email") ?? "apple@user"
            let fullName = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let displayName = fullName.isEmpty ? defaults.string(forKey: "auth_display_name") : fullName

            isLoading = true
            self.error = nil

            Task {
                let token = await exchangeTokenWithSupabase(idToken: idToken, provider: "apple")
                isLoading = false
                if let token {
                    let authUser = AuthUser(email: email, displayName: displayName, accessToken: token)
                    self.user = authUser
                    defaults.set(token, forKey: "auth_access_token")
                    defaults.set(email, forKey: "auth_email")
                    defaults.set(displayName, forKey: "auth_display_name")
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

    private func exchangeTokenWithSupabase(idToken: String, provider: String) async -> String? {
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
            return json?["access_token"] as? String
        } catch {
            return nil
        }
    }
}
