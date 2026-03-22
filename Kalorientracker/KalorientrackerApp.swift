import SwiftUI
import SwiftData

@main
struct KalorientrackerApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [FoodEntry.self, UserProfile.self])
    }
}
