import SwiftUI
import Charts

struct DailyCalorieChart: View {
    let data: [DailyData]
    let target: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kalorien pro Tag")
                .font(.headline)
                .foregroundStyle(.white)

            Chart {
                ForEach(data) { item in
                    BarMark(
                        x: .value("Tag", item.date, unit: .day),
                        y: .value("Kalorien", item.calories)
                    )
                    .foregroundStyle(
                        item.calories > target
                            ? Constants.Colors.danger.gradient
                            : Constants.Colors.gradientStart.gradient
                    )
                    .cornerRadius(6)
                }

                RuleMark(y: .value("Ziel", target))
                    .foregroundStyle(Constants.Colors.warning.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(position: .trailing, alignment: .trailing) {
                        Text("Ziel")
                            .font(.caption2)
                            .foregroundStyle(Constants.Colors.warning)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.dayOfWeek)
                                .font(.caption2)
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Constants.Colors.glassBorder)
                    AxisValueLabel {
                        if let cal = value.as(Int.self) {
                            Text("\(cal)")
                                .font(.caption2)
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(20)
        .glassCard()
    }
}
