import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @StateObject private var downloadManager = ModelDownloadManager()

    private var profile: UserProfile {
        if let existing = profiles.first { return existing }
        let new = UserProfile()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Profil")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // AI Mode
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Modus")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            ForEach(AIMode.allCases, id: \.self) { mode in
                                Button {
                                    withAnimation {
                                        profile.aiMode = mode
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: mode.icon)
                                            .font(.title3)
                                        Text(mode.label)
                                            .font(.caption.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .foregroundStyle(profile.aiMode == mode ? .white : Constants.Colors.textSecondary)
                                    .background(
                                        profile.aiMode == mode
                                            ? AnyShapeStyle(Constants.Colors.accentGradient)
                                            : AnyShapeStyle(Constants.Colors.surface)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(profile.aiMode == mode ? Color.clear : Constants.Colors.glassBorder, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                    .glassCard()
                    .padding(.horizontal)

                    // Model Download
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("On-Device Modell")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            if downloadManager.isModelAvailable {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Bereit")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Constants.Colors.success)
                            }
                        }

                        Text("Qwen3-VL-2B (~1.1 GB)")
                            .font(.subheadline)
                            .foregroundStyle(Constants.Colors.textSecondary)

                        if downloadManager.isDownloading {
                            VStack(spacing: 8) {
                                ProgressView(value: downloadManager.progress)
                                    .tint(Constants.Colors.gradientStart)
                                Text(downloadManager.formattedProgress)
                                    .font(.caption)
                                    .foregroundStyle(Constants.Colors.textSecondary)
                                SecondaryButton(title: "Abbrechen") {
                                    downloadManager.cancelDownload()
                                }
                            }
                        } else if !downloadManager.isModelAvailable {
                            GradientButton("Modell herunterladen", icon: "arrow.down.circle") {
                                downloadManager.startDownload()
                            }
                        } else {
                            SecondaryButton(title: "Modell löschen") {
                                downloadManager.deleteModel()
                            }
                        }

                        if let error = downloadManager.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Constants.Colors.danger)
                        }
                    }
                    .padding(20)
                    .glassCard()
                    .padding(.horizontal)

                    // Personal data
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Persönliche Daten")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Toggle("Kalorienziel berechnen", isOn: Bindable(profile).useComputedTarget)
                            .tint(Constants.Colors.gradientStart)
                            .foregroundStyle(.white)

                        // Gender
                        HStack {
                            Text("Geschlecht")
                                .foregroundStyle(.white)
                            Spacer()
                            Picker("", selection: Bindable(profile).isMale) {
                                Text("Männlich").tag(true)
                                Text("Weiblich").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }

                        ProfileSlider(title: "Alter", value: Binding(
                            get: { Double(profile.age) },
                            set: { profile.age = Int($0) }
                        ), range: 14...90, unit: "Jahre", format: "%.0f")

                        ProfileSlider(title: "Gewicht", value: Bindable(profile).weightKg, range: 40...200, unit: "kg", format: "%.1f")

                        ProfileSlider(title: "Größe", value: Bindable(profile).heightCm, range: 140...220, unit: "cm", format: "%.0f")

                        // Activity level
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Aktivitätslevel")
                                .font(.subheadline)
                                .foregroundStyle(Constants.Colors.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(0..<5) { level in
                                        Button {
                                            withAnimation { profile.activityLevel = level }
                                        } label: {
                                            VStack(spacing: 6) {
                                                Image(systemName: UserProfile.activityIcons[level])
                                                    .font(.title3)
                                                Text(UserProfile.activityLabels[level])
                                                    .font(.caption2)
                                            }
                                            .frame(width: 70, height: 70)
                                            .foregroundStyle(profile.activityLevel == level ? .white : Constants.Colors.textSecondary)
                                            .background(
                                                profile.activityLevel == level
                                                    ? AnyShapeStyle(Constants.Colors.accentGradient)
                                                    : AnyShapeStyle(Constants.Colors.surface)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                            }
                        }

                        ProfileSlider(title: "Training/Woche", value: Bindable(profile).weeklyTrainingHours, range: 0...20, unit: "Std", format: "%.1f")

                        if !profile.useComputedTarget {
                            ProfileSlider(title: "Kalorienziel", value: Binding(
                                get: { Double(profile.targetCalories) },
                                set: { profile.targetCalories = Int($0) }
                            ), range: 1000...5000, unit: "kcal", format: "%.0f")
                        }

                        // Calculated values
                        if profile.useComputedTarget {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Grundumsatz (BMR)")
                                        .font(.caption)
                                        .foregroundStyle(Constants.Colors.textSecondary)
                                    Spacer()
                                    Text("\(Int(profile.bmr)) kcal")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                HStack {
                                    Text("Gesamtbedarf (TDEE)")
                                        .font(.caption)
                                        .foregroundStyle(Constants.Colors.textSecondary)
                                    Spacer()
                                    Text("\(Int(profile.tdee)) kcal")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Constants.Colors.gradientStart)
                                }
                            }
                            .padding(12)
                            .background(Constants.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(20)
                    .glassCard()
                    .padding(.horizontal)

                    // Danger zone
                    Button(role: .destructive) {
                        // Delete all entries
                        do {
                            try modelContext.delete(model: FoodEntry.self)
                        } catch {}
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Alle Daten löschen")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Constants.Colors.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Constants.Colors.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct ProfileSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
                Spacer()
                Text("\(String(format: format, value)) \(unit)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Slider(value: $value, in: range)
                .tint(Constants.Colors.gradientStart)
        }
    }
}
