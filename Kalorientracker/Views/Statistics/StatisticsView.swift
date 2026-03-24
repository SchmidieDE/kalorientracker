import SwiftUI
import SwiftData
import Charts

enum TimeRange: String, CaseIterable {
    case week = "7 Tage"
    case month = "30 Tage"
    case quarter = "90 Tage"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

struct DailyData: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @State private var selectedRange: TimeRange = .week

    private var targetCalories: Int { profiles.first?.recommendedCalories ?? 2000 }

    private var dailyData: [DailyData] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -selectedRange.days, to: Date())!

        let filtered = allEntries.filter { $0.timestamp >= startDate }

        var grouped: [Date: (cal: Int, p: Double, c: Double, f: Double)] = [:]
        for entry in filtered {
            let day = calendar.startOfDay(for: entry.timestamp)
            var existing = grouped[day] ?? (0, 0, 0, 0)
            existing.cal += entry.calories
            existing.p += entry.protein
            existing.c += entry.carbs
            existing.f += entry.fat
            grouped[day] = existing
        }

        // Fill missing days with 0
        var result: [DailyData] = []
        for i in 0..<selectedRange.days {
            let day = calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: Date()))!
            let data = grouped[day]
            result.append(DailyData(date: day, calories: data?.cal ?? 0, protein: data?.p ?? 0, carbs: data?.c ?? 0, fat: data?.f ?? 0))
        }

        return result.reversed()
    }

    private var averageCalories: Int {
        let nonZero = dailyData.filter { $0.calories > 0 }
        guard !nonZero.isEmpty else { return 0 }
        return nonZero.reduce(0) { $0 + $1.calories } / nonZero.count
    }

    private var trackedDays: Int {
        dailyData.filter { $0.calories > 0 }.count
    }

    private var favorites: [FoodEntry] {
        allEntries.filter { $0.isFavorite }
    }

    private var uniqueFavorites: [FoodEntry] {
        var seen = Set<String>()
        return favorites.filter { seen.insert($0.name).inserted }
    }

    private func addFavoriteAsEntry(_ source: FoodEntry) {
        let entry = FoodEntry(
            name: source.name,
            calories: source.calories,
            protein: source.protein,
            carbs: source.carbs,
            fat: source.fat,
            confidence: 1.0,
            imageData: source.imageData,
            portionDescription: source.portionDescription,
            suggestion: source.suggestion,
            emoji: source.emoji,
            analysisSource: source.source,
            mealCategory: MealCategory.fromCurrentTime()
        )
        modelContext.insert(entry)
        ToastManager.shared.show("Eintrag hinzugefügt")
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Statistik")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Time range picker
                    Picker("Zeitraum", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Summary cards
                    HStack(spacing: 12) {
                        StatCard(title: "Durchschnitt", value: "\(averageCalories)", unit: "kcal/Tag", color: Constants.Colors.gradientStart)
                        StatCard(title: "Getrackt", value: "\(trackedDays)", unit: "Tage", color: Constants.Colors.gradientEnd)
                    }
                    .padding(.horizontal)

                    // Daily calorie chart
                    DailyCalorieChart(data: dailyData, target: targetCalories, dayCount: selectedRange.days)
                        .padding(.horizontal)

                    // Macro breakdown
                    MacroBreakdownChart(data: dailyData)
                        .padding(.horizontal)

                    // Saved favorites
                    if !favorites.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Constants.Colors.warning)
                                Text("Gespeicherte Favoriten")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(favorites.count)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Constants.Colors.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Constants.Colors.surface)
                                    .clipShape(Capsule())
                            }

                            ForEach(uniqueFavorites) { entry in
                                QuickAddRow(entry: entry) {
                                    addFavoriteAsEntry(entry)
                                }
                            }
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Constants.Colors.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }
}
