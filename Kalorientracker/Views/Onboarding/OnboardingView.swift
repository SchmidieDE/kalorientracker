import SwiftUI
import SwiftData
import AuthenticationServices

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Query private var profiles: [UserProfile]
    @State private var currentPage = 0
    @State private var age: Double = 30
    @State private var weight: Double = 75
    @State private var height: Double = 175
    @State private var isMale = true
    @State private var activityLevel = 2
    @State private var goal: NutritionGoal = .maintain

    private let totalPages = 5
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i <= currentPage ? Constants.Colors.gradientStart : Constants.Colors.surface)
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 20)

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    goalPage.tag(1)
                    personalDataPage.tag(2)
                    activityPage.tag(3)
                    loginPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom button
                VStack(spacing: 12) {
                    if currentPage == 4 && !authManager.isLoggedIn && !authManager.isLoading {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            authManager.handleAppleSignIn(result: result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    GradientButton(currentPage == 4 ? (authManager.isLoggedIn ? "Los geht's!" : "Überspringen") : "Weiter", icon: currentPage == 4 ? (authManager.isLoggedIn ? "checkmark" : "arrow.right") : "arrow.right") {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        if currentPage < 4 {
                            withAnimation { currentPage += 1 }
                        } else {
                            completeOnboarding()
                        }
                    }

                    if currentPage > 0 {
                        Button("Zurück") {
                            withAnimation { currentPage -= 1 }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Constants.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Constants.Colors.gradientStart.opacity(0.15))
                    .frame(width: 160, height: 160)

                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Constants.Colors.accentGradient)
            }

            VStack(spacing: 12) {
                Text("Willkommen bei")
                    .font(.title2)
                    .foregroundStyle(Constants.Colors.textSecondary)
                Text("Kalorientracker")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }

            VStack(spacing: 16) {
                FeatureRow(icon: "camera.fill", text: "Fotografiere dein Essen")
                FeatureRow(icon: "brain.head.profile", text: "KI analysiert Kalorien & Nährwerte")
                FeatureRow(icon: "chart.bar.fill", text: "Verfolge deinen Fortschritt")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var goalPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Was ist dein Ziel?")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Dein Kalorienziel wird darauf basieren")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(NutritionGoal.allCases, id: \.self) { g in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        goal = g
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: g.icon)
                                .font(.title2)
                                .frame(width: 32)
                            Text(g.label)
                                .font(.headline)
                            Spacer()
                            if goal == g {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Constants.Colors.gradientStart)
                            }
                        }
                        .foregroundStyle(goal == g ? .white : Constants.Colors.textSecondary)
                        .padding(18)
                        .background(goal == g ? AnyShapeStyle(Constants.Colors.accentGradient.opacity(0.2)) : AnyShapeStyle(Constants.Colors.surface))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(goal == g ? Constants.Colors.gradientStart.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var personalDataPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Persönliche Daten")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Für eine genaue Kalorienberechnung")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            VStack(spacing: 20) {
                // Gender
                HStack(spacing: 12) {
                    GenderButton(label: "Männlich", icon: "figure.stand", isSelected: isMale) {
                        isMale = true
                    }
                    GenderButton(label: "Weiblich", icon: "figure.stand.dress", isSelected: !isMale) {
                        isMale = false
                    }
                }

                ProfileSlider(title: "Alter", value: $age, range: 14...90, unit: "Jahre", format: "%.0f")
                ProfileSlider(title: "Gewicht", value: $weight, range: 40...200, unit: "kg", format: "%.1f")
                ProfileSlider(title: "Größe", value: $height, range: 140...220, unit: "cm", format: "%.0f")
            }
            .padding(20)
            .glassCard()
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var activityPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Wie aktiv bist du?")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Beeinflusst deinen täglichen Kalorienbedarf")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            VStack(spacing: 10) {
                ForEach(0..<5) { level in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        activityLevel = level
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: UserProfile.activityIcons[level])
                                .font(.title3)
                                .frame(width: 28)
                            Text(UserProfile.activityLabels[level])
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if activityLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Constants.Colors.gradientStart)
                            }
                        }
                        .foregroundStyle(activityLevel == level ? .white : Constants.Colors.textSecondary)
                        .padding(14)
                        .background(activityLevel == level ? AnyShapeStyle(Constants.Colors.accentGradient.opacity(0.2)) : AnyShapeStyle(Constants.Colors.surface))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(activityLevel == level ? Constants.Colors.gradientStart.opacity(0.5) : Color.clear, lineWidth: 1.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)

            // Preview of calculated TDEE
            let previewBMR = isMale
                ? 10 * weight + 6.25 * height - 5 * age + 5
                : 10 * weight + 6.25 * height - 5 * age - 161
            let previewTDEE = Int(previewBMR * UserProfile.activityMultipliers[activityLevel] * goal.calorieFactor)

            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Constants.Colors.gradientStart)
                Text("Dein Kalorienziel: **\(previewTDEE) kcal/Tag**")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Constants.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var loginPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Constants.Colors.gradientStart.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Constants.Colors.accentGradient)
            }

            VStack(spacing: 8) {
                Text("Anmelden")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Optional — für Cloud-KI\nund Datensicherung")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if authManager.isLoggedIn {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Constants.Colors.success)
                    Text("Angemeldet als")
                        .font(.subheadline)
                        .foregroundStyle(Constants.Colors.textSecondary)
                    Text(authManager.user?.displayName ?? authManager.user?.email ?? "")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(20)
                .glassCard()
                .padding(.horizontal, 24)
            } else if authManager.isLoading {
                ProgressView()
                    .tint(Constants.Colors.gradientStart)
                    .scaleEffect(1.5)
            } else {
                VStack(spacing: 12) {
                    FeatureRow(icon: "cloud.fill", text: "Cloud-KI für bessere Erkennung")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Daten geräteübergreifend sync")
                    FeatureRow(icon: "lock.shield", text: "Sichere Apple-Anmeldung")
                }
                .padding(.horizontal, 32)
            }

            if let error = authManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        let p = profile ?? UserProfile()
        p.age = Int(age)
        p.weightKg = weight
        p.heightCm = height
        p.isMale = isMale
        p.activityLevel = activityLevel
        p.goal = goal
        p.useComputedTarget = true
        p.hasCompletedOnboarding = true

        if profile == nil {
            modelContext.insert(p)
        }

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
    }
}

// MARK: - Sub-components

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Constants.Colors.gradientStart)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
        }
    }
}

private struct GenderButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(isSelected ? .white : Constants.Colors.textSecondary)
            .background(isSelected ? AnyShapeStyle(Constants.Colors.accentGradient.opacity(0.2)) : AnyShapeStyle(Constants.Colors.surface))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Constants.Colors.gradientStart.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
    }
}
