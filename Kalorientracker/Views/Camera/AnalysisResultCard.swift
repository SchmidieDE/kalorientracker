import SwiftUI

struct AnalysisResultCard: View {
    let result: NutritionResult
    let onSave: () -> Void
    let onDiscard: () -> Void

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
                MacroBar(label: "Protein", value: result.protein, color: Constants.Colors.proteinColor, maxValue: max(result.protein, max(result.carbs, result.fat)))
                MacroBar(label: "Kohlenhydrate", value: result.carbs, color: Constants.Colors.carbsColor, maxValue: max(result.protein, max(result.carbs, result.fat)))
                MacroBar(label: "Fett", value: result.fat, color: Constants.Colors.fatColor, maxValue: max(result.protein, max(result.carbs, result.fat)))
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
                        .fill(Double(i) / 5.0 < result.confidence ? Constants.Colors.gradientStart : Constants.Colors.surface)
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

            // Action buttons
            VStack(spacing: 10) {
                GradientButton("Speichern", icon: "checkmark") {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    onSave()
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
                        .frame(width: geo.size.width * ratio)
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
