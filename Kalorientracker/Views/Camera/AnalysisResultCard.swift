import SwiftUI

struct AnalysisResultCard: View {
    let result: NutritionResult
    let onSave: (NutritionResult, MealCategory) -> Void
    let onDiscard: () -> Void

    @State private var selectedAlternative: FoodAlternative?
    @State private var showCustomInput = false
    @State private var customName = ""

    private var isUncertain: Bool {
        result.confidence < 0.8 && !(result.alternatives ?? []).isEmpty
    }

    private var activeName: String {
        if !customName.isEmpty { return customName }
        return selectedAlternative?.name ?? result.name
    }
    private var activeCalories: Int { selectedAlternative?.calories ?? result.calories }
    private var activeProtein: Double { selectedAlternative?.protein ?? result.protein }
    private var activeCarbs: Double { selectedAlternative?.carbs ?? result.carbs }
    private var activeFat: Double { selectedAlternative?.fat ?? result.fat }
    private var activeEmoji: String? {
        if selectedAlternative != nil { return selectedAlternative?.emoji }
        return result.emoji
    }

    var body: some View {
        VStack(spacing: 14) {
            // Emoji
            if let emoji = activeEmoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 40))
            }

            // Name
            Text(activeName)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Calories
            VStack(spacing: 2) {
                Text("\(activeCalories)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Constants.Colors.accentGradient)
                Text("kcal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            // Confidence
            HStack(spacing: 3) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(Double(i) < (result.confidence * 5.0) ? Constants.Colors.gradientStart : Constants.Colors.surface)
                        .frame(width: 6, height: 6)
                }
                Text(result.confidence > 0.8 ? "Sehr sicher" : result.confidence > 0.5 ? "Sicher" : "Schätzung")
                    .font(.caption2)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            // Macros
            HStack(spacing: 8) {
                MacroPillCompact(label: "P", value: activeProtein, color: Constants.Colors.proteinColor)
                MacroPillCompact(label: "K", value: activeCarbs, color: Constants.Colors.carbsColor)
                MacroPillCompact(label: "F", value: activeFat, color: Constants.Colors.fatColor)
            }

            // Portion
            if !result.portionDescription.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.caption2)
                    Text(result.portionDescription)
                        .font(.caption)
                }
                .foregroundStyle(Constants.Colors.textSecondary)
            }

            // Alternatives
            if isUncertain {
                alternativesSection
            }

            // Suggestion
            if let suggestion = result.suggestions, !suggestion.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Constants.Colors.warning)
                        .font(.caption2)
                    Text(suggestion)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                }
                .padding(10)
                .background(Constants.Colors.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Buttons
            VStack(spacing: 8) {
                GradientButton("Speichern", icon: "checkmark") {
                    onSave(resolvedResult, MealCategory.fromCurrentTime())
                }
                SecondaryButton(title: "Verwerfen") {
                    onDiscard()
                }
            }
        }
        .padding(16)
        .glassCard()
    }

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

    // MARK: - Alternatives

    @ViewBuilder
    private var alternativesSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(Constants.Colors.warning)
                    .font(.caption)
                Text("Meintest du...?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }

            FlowLayout(spacing: 6) {
                AlternativeChip(
                    name: result.name, emoji: result.emoji,
                    isSelected: selectedAlternative == nil && customName.isEmpty
                ) { selectedAlternative = nil; customName = "" }

                ForEach(result.alternatives ?? [], id: \.name) { alt in
                    AlternativeChip(
                        name: alt.name, emoji: alt.emoji,
                        isSelected: selectedAlternative?.name == alt.name
                    ) { selectedAlternative = alt; customName = "" }
                }
            }

            if showCustomInput {
                HStack(spacing: 6) {
                    TextField("Name eingeben...", text: $customName)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Constants.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button { showCustomInput = false; customName = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Constants.Colors.textSecondary)
                    }
                }
            } else {
                Button { showCustomInput = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Eigenen Namen")
                    }
                    .font(.caption2)
                    .foregroundStyle(Constants.Colors.gradientStart)
                }
            }
        }
        .padding(10)
        .background(Constants.Colors.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Compact Macro Pill

private struct MacroPillCompact: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(color)
                .frame(width: 14, height: 14)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            Text("\(value.cleanString)g")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Constants.Colors.surface)
        .clipShape(Capsule())
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
            HStack(spacing: 3) {
                if let emoji, !emoji.isEmpty {
                    Text(emoji).font(.caption2)
                }
                Text(name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : Constants.Colors.textSecondary)
            .background(isSelected ? AnyShapeStyle(Constants.Colors.accentGradient) : AnyShapeStyle(Constants.Colors.surface))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in r.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxW = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            positions.append(CGPoint(x: x, y: y))
            rowH = max(rowH, s.height)
            x += s.width + spacing
            maxX = max(maxX, x)
        }
        return (positions, CGSize(width: maxX - spacing, height: y + rowH))
    }
}

// MARK: - MacroBar (used in Statistics)

struct MacroBar: View {
    let label: String
    let value: Double
    let color: Color
    let maxValue: Double
    private var ratio: Double { maxValue > 0 ? value / maxValue : 0 }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Constants.Colors.textSecondary)
                .frame(width: 90, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4).fill(color)
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
