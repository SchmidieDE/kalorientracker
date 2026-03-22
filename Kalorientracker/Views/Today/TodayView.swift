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
    @State private var capturedImage: UIImage?
    @State private var showResult = false
    @State private var selectedEntry: FoodEntry?
    @State private var editingEntry: FoodEntry?
    @State private var showAddSheet = false
    @State private var showManualEntry = false
    @State private var showFavorites = false
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

    /// Group today's entries by meal category
    private func entries(for category: MealCategory) -> [FoodEntry] {
        todayEntries.filter { $0.mealCategory == category }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func categoryCalories(_ category: MealCategory) -> Int {
        entries(for: category).reduce(0) { $0 + $1.calories }
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

                    // Entries grouped by meal
                    if todayEntries.isEmpty {
                        emptyState
                    } else {
                        mealSections
                    }
                }
                .padding(.bottom, 100)
            }

            // Floating Add Button
            VStack {
                Spacer()
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showAddSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Constants.Colors.accentGradient)
                            .frame(width: 68, height: 68)
                            .shadow(color: Constants.Colors.gradientStart.opacity(pulseAnimation ? 0.6 : 0.2), radius: pulseAnimation ? 20 : 10, y: 5)

                        Image(systemName: "plus")
                            .font(.title2.bold())
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

            // Toast overlay
            ToastOverlay(toast: ToastManager.shared.currentToast)
        }
        .sheet(isPresented: $showAddSheet) {
            AddFoodSheet(
                onCamera: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCamera = true
                    }
                },
                onManual: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showManualEntry = true
                    }
                },
                onFavorites: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showFavorites = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                onCapture: { image in
                    capturedImage = image
                    showCamera = false
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
        .onChange(of: showCamera) { _, isShowing in
            if !isShowing && capturedImage != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showResult = true
                }
            }
        }
        .sheet(isPresented: $showResult, onDismiss: {
            capturedImage = nil
        }) {
            if let image = capturedImage {
                PhotoReviewView(image: image, analyzer: analyzer) { result, mealCategory in
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
                        analysisSource: analyzer.analysisSource,
                        mealCategory: mealCategory
                    )
                    modelContext.insert(entry)
                    showResult = false
                    ToastManager.shared.show("Eintrag gespeichert")
                }
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualFoodEntrySheet { entry in
                modelContext.insert(entry)
                ToastManager.shared.show("Eintrag gespeichert")
            }
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesSheet { entry in
                modelContext.insert(entry)
                ToastManager.shared.show("Eintrag gespeichert")
            }
        }
        .sheet(item: $selectedEntry) { entry in
            FoodDetailSheet(entry: entry, onEdit: {
                selectedEntry = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    editingEntry = entry
                }
            })
        }
        .sheet(item: $editingEntry) { entry in
            EditFoodEntrySheet(entry: entry)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 50))
                .foregroundStyle(Constants.Colors.textSecondary)

            VStack(spacing: 8) {
                Text("Noch keine Einträge heute")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Starte jetzt dein Tracking!")
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("Foto")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Constants.Colors.accentGradient)
                    .clipShape(Capsule())
                }

                Button {
                    showManualEntry = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.cursor")
                        Text("Manuell")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Constants.Colors.gradientStart)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Constants.Colors.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Constants.Colors.gradientStart.opacity(0.3), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Meal Sections

    private var mealSections: some View {
        VStack(spacing: 16) {
            ForEach(MealCategory.allCases) { category in
                let categoryEntries = entries(for: category)
                if !categoryEntries.isEmpty {
                    VStack(spacing: 8) {
                        // Section header
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(Constants.Colors.gradientStart)
                                Text(category.label)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text("\(categoryCalories(category)) kcal")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Constants.Colors.textSecondary)
                        }
                        .padding(.horizontal)

                        ForEach(categoryEntries) { entry in
                            FoodEntryRow(entry: entry)
                                .padding(.horizontal)
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        let haptic = UINotificationFeedbackGenerator()
                                        haptic.notificationOccurred(.warning)
                                        withAnimation {
                                            modelContext.delete(entry)
                                        }
                                        ToastManager.shared.show("Gelöscht", icon: "trash", style: .info)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }

                                    Button {
                                        editingEntry = entry
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(Constants.Colors.gradientEnd)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        duplicateEntry(entry)
                                    } label: {
                                        Label("Nochmal", systemImage: "plus.circle")
                                    }
                                    .tint(Constants.Colors.success)
                                }
                                .contextMenu {
                                    Button {
                                        editingEntry = entry
                                    } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }

                                    Button {
                                        duplicateEntry(entry)
                                    } label: {
                                        Label("Nochmal essen", systemImage: "plus.circle")
                                    }

                                    Button {
                                        entry.isFavorite.toggle()
                                        ToastManager.shared.show(
                                            entry.isFavorite ? "Zu Favoriten hinzugefügt" : "Aus Favoriten entfernt",
                                            icon: entry.isFavorite ? "star.fill" : "star",
                                            style: .success
                                        )
                                    } label: {
                                        Label(entry.isFavorite ? "Kein Favorit" : "Favorit", systemImage: entry.isFavorite ? "star.slash" : "star")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        let haptic = UINotificationFeedbackGenerator()
                                        haptic.notificationOccurred(.warning)
                                        withAnimation {
                                            modelContext.delete(entry)
                                        }
                                        ToastManager.shared.show("Gelöscht", icon: "trash", style: .info)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func duplicateEntry(_ entry: FoodEntry) {
        let newEntry = FoodEntry(
            name: entry.name,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            confidence: entry.confidence,
            imageData: entry.imageData,
            portionDescription: entry.portionDescription,
            suggestion: entry.suggestion,
            analysisSource: entry.source,
            mealCategory: MealCategory.fromCurrentTime()
        )
        modelContext.insert(newEntry)
        ToastManager.shared.show("Eintrag dupliziert")
    }
}
