import SwiftUI
import SwiftData

struct FavoritesSheet: View {
    let onAdd: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp, order: .reverse) private var allEntries: [FoodEntry]

    private var favorites: [FoodEntry] {
        allEntries.filter { $0.isFavorite }
    }

    /// Recent unique foods (last 20, deduplicated by name)
    private var recentFoods: [FoodEntry] {
        var seen = Set<String>()
        var result: [FoodEntry] = []
        for entry in allEntries where !entry.isFavorite {
            if seen.insert(entry.name).inserted {
                result.append(entry)
            }
            if result.count >= 20 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        if favorites.isEmpty && recentFoods.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "star.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Constants.Colors.textSecondary)
                                Text("Noch keine Favoriten")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Markiere Einträge als Favorit, um sie hier schnell wiederzufinden.")
                                    .font(.subheadline)
                                    .foregroundStyle(Constants.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 60)
                        }

                        // Favorites
                        if !favorites.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(Constants.Colors.warning)
                                    Text("Favoriten")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal)

                                ForEach(favorites) { entry in
                                    QuickAddRow(entry: entry) {
                                        addFromEntry(entry)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // Recent
                        if !recentFoods.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(Constants.Colors.textSecondary)
                                    Text("Zuletzt gegessen")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal)

                                ForEach(recentFoods) { entry in
                                    QuickAddRow(entry: entry) {
                                        addFromEntry(entry)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Favoriten & Verlauf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(Constants.Colors.textSecondary)
                }
            }
        }
    }

    private func addFromEntry(_ source: FoodEntry) {
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
            analysisSource: source.source,
            mealCategory: MealCategory.fromCurrentTime()
        )
        onAdd(entry)
        dismiss()
    }
}

struct QuickAddRow: View {
    let entry: FoodEntry
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Constants.Colors.surface)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.caption)
                            .foregroundStyle(Constants.Colors.textSecondary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(entry.calories) kcal")
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Constants.Colors.gradientStart)
            }
        }
        .padding(12)
        .background(Constants.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Constants.Colors.glassBorder, lineWidth: 0.5)
        )
    }
}
