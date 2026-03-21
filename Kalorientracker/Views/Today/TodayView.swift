import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp, order: .reverse)
    private var allEntries: [FoodEntry]

    private var todayEntries: [FoodEntry] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return allEntries.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    @Query private var profiles: [UserProfile]
    @StateObject private var analyzer = FoodAnalyzer()
    @State private var showCamera = false
    @State private var showResult = false
    @State private var capturedImage: UIImage?
    @State private var pulseAnimation = false

    private var profile: UserProfile? { profiles.first }
    private var targetCalories: Int { profile?.recommendedCalories ?? 2000 }
    private var totalCalories: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { todayEntries.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { todayEntries.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { todayEntries.reduce(0) { $0 + $1.fat } }

    private var status: CalorieStatus {
        CalorieCalculator.status(consumed: totalCalories, target: targetCalories)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Guten Morgen" }
        if hour < 18 { return "Guten Tag" }
        return "Guten Abend"
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(Date().formatted(.dateTime.day().month(.wide).year()))
                                .font(.subheadline)
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Progress Ring
                    CalorieProgressRing(consumed: totalCalories, target: targetCalories)
                        .padding(.vertical, 8)

                    // Status Badge
                    HStack(spacing: 8) {
                        Image(systemName: status.icon)
                        Text(status.message)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(status.color.opacity(0.15))
                    .clipShape(Capsule())

                    // Macro Pills
                    HStack(spacing: 8) {
                        MacroPill(label: "P", value: totalProtein, color: Constants.Colors.proteinColor)
                        MacroPill(label: "K", value: totalCarbs, color: Constants.Colors.carbsColor)
                        MacroPill(label: "F", value: totalFat, color: Constants.Colors.fatColor)
                    }

                    // Entries
                    if todayEntries.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Constants.Colors.textSecondary)
                            Text("Fotografiere dein erstes Essen!")
                                .font(.headline)
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Heute")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(todayEntries.count) Einträge")
                                    .font(.caption)
                                    .foregroundStyle(Constants.Colors.textSecondary)
                            }
                            .padding(.horizontal)

                            ForEach(todayEntries) { entry in
                                FoodEntryRow(entry: entry)
                                    .padding(.horizontal)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                modelContext.delete(entry)
                                            }
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }

            // Floating Camera Button
            VStack {
                Spacer()
                Button {
                    showCamera = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Constants.Colors.accentGradient)
                            .frame(width: 68, height: 68)
                            .shadow(color: Constants.Colors.gradientStart.opacity(pulseAnimation ? 0.6 : 0.2), radius: pulseAnimation ? 20 : 10, y: 5)

                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 16)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                capturedImage = image
                showCamera = false
                showResult = true
            }
        }
        .sheet(isPresented: $showResult) {
            if let image = capturedImage {
                PhotoReviewView(image: image, analyzer: analyzer) { result in
                    let entry = FoodEntry(
                        name: result.name,
                        calories: result.calories,
                        protein: result.protein,
                        carbs: result.carbs,
                        fat: result.fat,
                        confidence: result.confidence,
                        imageData: image.jpegCompressed(quality: 0.5, maxDimension: 512),
                        portionDescription: result.portionDescription,
                        suggestion: result.suggestions,
                        analysisSource: analyzer.analysisSource
                    )
                    modelContext.insert(entry)
                    showResult = false
                }
            }
        }
    }
}