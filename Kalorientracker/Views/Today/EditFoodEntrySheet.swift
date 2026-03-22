import SwiftUI

struct EditFoodEntrySheet: View {
    @Bindable var entry: FoodEntry
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, calories, protein, carbs, fat, portion
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Image preview
                        if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // Meal category
                        HStack(spacing: 8) {
                            ForEach(MealCategory.allCases) { cat in
                                Button {
                                    entry.mealCategory = cat
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: cat.icon)
                                            .font(.caption)
                                        Text(cat.label)
                                            .font(.caption2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(entry.mealCategory == cat ? .white : Constants.Colors.textSecondary)
                                    .background(entry.mealCategory == cat ? AnyShapeStyle(Constants.Colors.accentGradient) : AnyShapeStyle(Constants.Colors.surface))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }

                        // Name
                        EditField(title: "Name", text: $entry.name)
                            .focused($focusedField, equals: .name)

                        // Calories
                        EditNumberField(title: "Kalorien (kcal)", value: Binding(
                            get: { entry.calories },
                            set: { entry.calories = $0 }
                        ))
                        .focused($focusedField, equals: .calories)

                        // Macros
                        HStack(spacing: 12) {
                            EditDecimalField(title: "Protein (g)", value: $entry.protein)
                                .focused($focusedField, equals: .protein)
                            EditDecimalField(title: "Kohlenh. (g)", value: $entry.carbs)
                                .focused($focusedField, equals: .carbs)
                            EditDecimalField(title: "Fett (g)", value: $entry.fat)
                                .focused($focusedField, equals: .fat)
                        }

                        // Portion
                        EditField(title: "Portion", text: $entry.portionDescription)
                            .focused($focusedField, equals: .portion)

                        // Favorite toggle
                        Toggle(isOn: $entry.isFavorite) {
                            HStack(spacing: 8) {
                                Image(systemName: entry.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(Constants.Colors.warning)
                                Text("Favorit")
                                    .foregroundStyle(.white)
                            }
                        }
                        .tint(Constants.Colors.gradientStart)
                        .padding(14)
                        .background(Constants.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        let haptic = UINotificationFeedbackGenerator()
                        haptic.notificationOccurred(.success)
                        ToastManager.shared.show("Gespeichert")
                        dismiss()
                    }
                    .foregroundStyle(Constants.Colors.gradientStart)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Fertig") { focusedField = nil }
                }
            }
        }
    }
}

private struct EditField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Constants.Colors.textSecondary)
            TextField(title, text: $text)
                .padding(12)
                .background(Constants.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }
}

private struct EditNumberField: View {
    let title: String
    @Binding var value: Int
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Constants.Colors.textSecondary)
            TextField(title, text: $text)
                .keyboardType(.numberPad)
                .padding(12)
                .background(Constants.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .onAppear { text = "\(value)" }
                .onChange(of: text) { _, newValue in
                    value = Int(newValue) ?? value
                }
        }
    }
}

private struct EditDecimalField: View {
    let title: String
    @Binding var value: Double
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Constants.Colors.textSecondary)
            TextField(title, text: $text)
                .keyboardType(.decimalPad)
                .padding(12)
                .background(Constants.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .onAppear { text = value.cleanString }
                .onChange(of: text) { _, newValue in
                    value = Double(newValue.replacingOccurrences(of: ",", with: ".")) ?? value
                }
        }
    }
}
