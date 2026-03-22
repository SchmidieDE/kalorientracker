import SwiftUI

struct AnalysisResultCard: View {
    let result: NutritionResult
    let onSave: (MealCategory) -> Void
    let onDiscard: () -> Void

    @State private var selectedMeal: MealCategory = MealCategory.fromCurrentTime()

    var body: some View {
        VStack(spacing: 20) {
            // Food name
            Text(result.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Calorie count
            Text("\(result.calories)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Constants.Colors.gradientStart, Constants.Colors.gradientEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("Kalorien")
                .font(.subheadline)
                .foregroundStyle(Constants.Colors.textSecondary)
                .offset(y: -12)

            // Macro bars
            VStack(spacing: 12) {
                let maxVal = max(result.protein, max(result.carbs, result.fat))
                MacroBar(label: "Protein", value: result.protein, color: Constants.Colors.proteinColor, maxValue: max(maxVal, 1))
                MacroBar(label: "Kohlenhydrate", value: result.carbs, color: Constants.Colors.carbsColor, maxValue: max(maxVal, 1))
                MacroBar(label: "Fett", value: result.fat, color: Constants.Colors.fatColor, maxValue: max(maxVal, 1))
            }

            // Portion
            HStack {
                Image(systemName: "scalemass")
                    .foregroundStyle(Constants.Colors.textSecondary)
                Text(result.portionDescription)
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            // Confidence
            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(Double(i) < (result.confidence * 5.0) ? Constants.Colors.gradientStart : Constants.Colors.surface)
                        .frame(width: 8, height: 8)
                }
                Text(result.confidence > 0.8 ? "Sehr sicher" : result.confidence > 0.5 ? "Sicher" : "Schätzung")
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            // Suggestion
            if let suggestion = result.suggestions, !suggestion.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Constants.Colors.warning)
                        .font(.caption)
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(Constants.Colors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Meal category picker
            HStack(spacing: 6) {
                ForEach(MealCategory.allCases) { cat in
                    Button {
                        selectedMeal = cat
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: cat.icon)
                                .font(.caption2)
                            Text(cat.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedMeal == cat ? .white : Constants.Colors.textSecondary)
                        .background(selectedMeal == cat ? AnyShapeStyle(Constants.Colors.accentGradient) : AnyShapeStyle(Constants.Colors.surface))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Action buttons
            VStack(spacing: 10) {
                GradientButton("Speichern", icon: "checkmark") {
                    onSave(selectedMeal)
                }
                SecondaryButton(title: "Verwerfen") {
                    onDiscard()
                }
            }
        }
        .glassCard()
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let color: Color
    let maxValue: Double

    private var ratio: Double {
        maxValue > 0 ? value / maxValue : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Constants.Colors.textSecondary)
                .frame(width: 90, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(geo.size.width * ratio, 0))
                }
            }
            .frame(height: 8)

            Text("\(value.cleanString)g")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 45, alignment: .trailing)
        }
    }
}
