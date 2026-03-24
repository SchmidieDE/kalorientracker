import SwiftUI

struct AnalysisResultCard: View {
    let result: NutritionResult
    let onSave: (NutritionResult, MealCategory) -> Void
    let onDiscard: () -> Void

    @State private var selectedMeal: MealCategory = MealCategory.fromCurrentTime()
    @State private var selectedAlternative: FoodAlternative?
    @State private var showCustomInput = false
    @State private var customName = ""

    private var isUncertain: Bool {
        result.confidence < 0.8 && !(result.alternatives ?? []).isEmpty
    }

    // Active values (original or selected alternative)
    private var activeName: String {
        if !customName.isEmpty { return customName }
        return selectedAlternative?.name ?? result.name
    }
    private var activeCalories: Int {
        selectedAlternative?.calories ?? result.calories
    }
    private var activeProtein: Double {
        selectedAlternative?.protein ?? result.protein
    }
    private var activeCarbs: Double {
        selectedAlternative?.carbs ?? result.carbs
    }
    private var activeFat: Double {
        selectedAlternative?.fat ?? result.fat
    }
    private var activeEmoji: String? {
        if selectedAlternative != nil { return selectedAlternative?.emoji }
        return result.emoji
    }

    var body: some View {
        VStack(spacing: 20) {
            // Food emoji + name
            if let emoji = activeEmoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 44))
            }
            Text(activeName)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Calorie count
            Text("\(activeCalories)")
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
                let maxVal = max(activeProtein, max(activeCarbs, activeFat))
                MacroBar(label: "Protein", value: activeProtein, color: Constants.Colors.proteinColor, maxValue: max(maxVal, 1))
                MacroBar(label: "Kohlenhydrate", value: activeCarbs, color: Constants.Colors.carbsColor, maxValue: max(maxVal, 1))
                MacroBar(label: "Fett", value: activeFat, color: Constants.Colors.fatColor, maxValue: max(maxVal, 1))
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

            // Alternatives section (when uncertain)
            if isUncertain {
                alternativesSection
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
                    onSave(resolvedResult, selectedMeal)
                }
                SecondaryButton(title: "Verwerfen") {
                    onDiscard()
                }
            }
        }
        .glassCard()
    }

    /// Returns a NutritionResult with the user's chosen values (original, alternative, or custom name)
    private var resolvedResult: NutritionResult {
        NutritionResult(
            isFood: result.isFood,
            name: activeName,
            calories: activeCalories,
            protein: activeProtein,
            carbs: activeCarbs,
            fat: activeFat,
            confidence: selectedAlternative != nil || !customName.isEmpty ? 1.0 : result.confidence,
            portionDescription: result.portionDescription,
            suggestions: result.suggestions,
            emoji: activeEmoji,
            alternatives: nil
        )
    }

    // MARK: - Alternatives UI

    @ViewBuilder
    private var alternativesSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(Constants.Colors.warning)
                Text("Meintest du...?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            // Alternative chips
            FlowLayout(spacing: 8) {
                // Original as first option
                AlternativeChip(
                    name: result.name,
                    emoji: result.emoji,
                    isSelected: selectedAlternative == nil && customName.isEmpty
                ) {
                    selectedAlternative = nil
                    customName = ""
                }

                // Alternatives
                ForEach(result.alternatives ?? [], id: \.name) { alt in
                    AlternativeChip(
                        name: alt.name,
                        emoji: alt.emoji,
                        isSelected: selectedAlternative?.name == alt.name
                    ) {
                        selectedAlternative = alt
                        customName = ""
                    }
                }
            }

            // Custom input toggle
            if showCustomInput {
                HStack(spacing: 8) {
                    TextField("Name eingeben...", text: $customName)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Constants.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onSubmit {
                            if !customName.isEmpty {
                                selectedAlternative = nil
                            }
                        }

                    Button {
                        showCustomInput = false
                        customName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Constants.Colors.textSecondary)
                    }
                }
            } else {
                Button {
                    showCustomInput = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Eigenen Namen eingeben")
                    }
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.gradientStart)
                }
            }
        }
        .padding(14)
        .background(Constants.Colors.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Alternative Chip

private struct AlternativeChip: View {
    let name: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption)
                }
                Text(name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : Constants.Colors.textSecondary)
            .background(isSelected ? AnyShapeStyle(Constants.Colors.accentGradient) : AnyShapeStyle(Constants.Colors.surface))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Constants.Colors.glassBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Flow Layout (wrapping chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX - spacing, height: y + rowHeight))
    }
}

// MARK: - MacroBar

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
