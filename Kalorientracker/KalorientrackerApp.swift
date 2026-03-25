import SwiftUI
import SwiftData
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        ModelDownloadManager.backgroundCompletionHandler = completionHandler
    }
}

@main
struct KalorientrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var syncService = SyncService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(syncService)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [FoodEntry.self, UserProfile.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var syncService: SyncService
    @Query private var profiles: [UserProfile]

    private var needsOnboarding: Bool {
        guard let profile = profiles.first else { return true }
        return !profile.hasCompletedOnboarding
    }

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView()
            } else {
                ContentView()
            }
        }
        .task {
            // Sync on app start if logged in
            if let token = authManager.accessToken {
                await syncService.pullEntries(accessToken: token, modelContext: modelContext)
            }
        }
    }
}
