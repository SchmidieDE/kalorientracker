import SwiftUI

struct FoodDetailSheet: View {
    let entry: FoodEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Image
                    if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                    }

                    // Name and calories
                    VStack(spacing: 8) {
                        Text(entry.name)
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        Text("\(entry.calories) kcal")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(Constants.Colors.accentGradient)
                    }

                    // Macros
                    HStack(spacing: 20) {
                        MacroDetail(label: "Protein", value: entry.protein, color: Constants.Colors.proteinColor)
                        MacroDetail(label: "Kohlenhydrate", value: entry.carbs, color: Constants.Colors.carbsColor)
                        MacroDetail(label: "Fett", value: entry.fat, color: Constants.Colors.fatColor)
                    }
                    .padding(.horizontal)

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(icon: "clock", label: "Uhrzeit", value: entry.timestamp.shortTime)
                        DetailRow(icon: "scalemass", label: "Portion", value: entry.portionDescription)
                        DetailRow(icon: entry.source == .cloud ? "cloud" : "iphone", label: "Quelle", value: entry.source == .cloud ? "Cloud (Gemini)" : "On-Device")

                        if let suggestion = entry.suggestion, !suggestion.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(Constants.Colors.warning)
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(14)
                            .background(Constants.Colors.warning.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(20)
                    .glassCard()
                    .padding(.horizontal)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .presentationDragIndicator(.visible)
    }
}

struct MacroDetail: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value.cleanString)g")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Constants.Colors.textSecondary)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(Constants.Colors.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
