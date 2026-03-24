import SwiftUI
import Charts

struct MacroBreakdownChart: View {
    let data: [DailyData]

    private var totalProtein: Double { data.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { data.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { data.reduce(0) { $0 + $1.fat } }
    private var total: Double { totalProtein + totalCarbs + totalFat }

    private var macros: [(name: String, value: Double, color: Color)] {
        [
            ("Protein", totalProtein, Constants.Colors.proteinColor),
            ("Kohlenhydrate", totalCarbs, Constants.Colors.carbsColor),
            ("Fett", totalFat, Constants.Colors.fatColor)
        ]
    }

    private var totalCalories: Int { data.reduce(0) { $0 + $1.calories } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Makronährstoffe")
                .font(.headline)
                .foregroundStyle(.white)

            if total > 0 {
                VStack(spacing: 20) {
                    Chart(macros, id: \.name) { macro in
                        SectorMark(
                            angle: .value(macro.name, macro.value),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(macro.color)
                        .cornerRadius(4)
                        .annotation(position: .overlay) {
                            if macro.value / total > 0.1 {
                                Text("\(macro.value.cleanString)g")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .chartBackground { _ in
                        VStack(spacing: 2) {
                            Text("\(totalCalories)")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text("kcal")
                                .font(.caption2)
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                    }
                    .frame(height: 200)

                    HStack(spacing: 16) {
                        ForEach(macros, id: \.name) { macro in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(macro.color)
                                    .frame(width: 12, height: 12)
                                Text(macro.name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                                Text("\(macro.value.cleanString)g")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(macro.color)
                                Text("\(Int(macro.value / total * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(Constants.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            } else {
                Text("Noch keine Daten")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding(20)
        .glassCard()
    }
}
