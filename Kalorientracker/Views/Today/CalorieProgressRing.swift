import SwiftUI

struct CalorieProgressRing: View {
    let consumed: Int
    let target: Int
    @State private var animatedProgress: Double = 0
    @State private var displayedCalories: Int = 0

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

            // Progress ring
            Circle()
                .trim(from: 0, to: min(animatedProgress, 1.5))
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
                Text("\(displayedCalories)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("/ \(target) kcal")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Constants.Colors.textSecondary)
            }
        }
        .onAppear { animate() }
        .onChange(of: consumed) { _, _ in animate() }
        .onChange(of: target) { _, _ in animate() }
    }

    private func animate() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
            animatedProgress = percentage
        }
        // Counting animation
        let steps = 30
        let stepDuration = 0.8 / Double(steps)
        for i in 0...steps {
            let delay = stepDuration * Double(i)
            let progress = Double(i) / Double(steps)
            let easedProgress = 1 - pow(1 - progress, 3) // ease-out cubic
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                displayedCalories = Int(Double(consumed) * easedProgress)
            }
        }
    }
}
