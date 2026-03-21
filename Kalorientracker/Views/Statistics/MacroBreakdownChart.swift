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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Makronährstoffe")
                .font(.headline)
                .foregroundStyle(.white)

            if total > 0 {
                HStack(spacing: 24) {
                    Chart(macros, id: \.name) { macro in
                        SectorMark(
                            angle: .value(macro.name, macro.value),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(macro.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(macros, id: \.name) { macro in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(macro.color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(macro.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white)
                                    Text("\(macro.value.cleanString)g (\(Int(macro.value / total * 100))%)")
                                        .font(.caption2)
                                        .foregroundStyle(Constants.Colors.textSecondary)
                                }
                            }
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
