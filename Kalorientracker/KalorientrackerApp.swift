import SwiftUI
import SwiftData

@main
struct KalorientrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [FoodEntry.self, UserProfile.self])
    }
}
