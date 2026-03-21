import SwiftUI

struct CalorieProgressRing: View {
    let consumed: Int
    let target: Int
    @State private var animatedProgress: Double = 0

    private var percentage: Double {
        target > 0 ? Double(consumed) / Double(target) : 0
    }

    private var colorScheme: ProgressColorScheme {
        CalorieCalculator.progressColor(percentage: percentage)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(colorScheme.secondary, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .frame(width: 200, height: 200)

            // Progress ring — cap at 1.2 to show overeating visually
            Circle()
                .trim(from: 0, to: min(animatedProgress, 1.2))
                .stroke(
                    AngularGradient(
                        colors: [colorScheme.primary.opacity(0.6), colorScheme.primary],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 4) {
                Text("\(consumed)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("/ \(target) kcal")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Constants.Colors.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedProgress = percentage
            }
        }
        .onChange(of: consumed) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = percentage
            }
        }
        .onChange(of: target) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = percentage
            }
        }
    }
}
