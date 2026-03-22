import SwiftUI
import SwiftData

@main
struct KalorientrackerApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [FoodEntry.self, UserProfile.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    private var needsOnboarding: Bool {
        guard let profile = profiles.first else { return true }
        return !profile.hasCompletedOnboarding
    }

    var body: some View {
        if needsOnboarding {
            OnboardingView()
        } else {
            ContentView()
        }
    }
}
