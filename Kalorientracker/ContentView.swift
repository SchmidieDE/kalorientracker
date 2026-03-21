import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Heute", systemImage: "fork.knife")
                }
                .tag(0)

            StatisticsView()
                .tabItem {
                    Label("Statistik", systemImage: "chart.bar.fill")
                }
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.circle.fill")
                }
                .tag(2)
        }
        .tint(Constants.Colors.gradientStart)
    }
}
