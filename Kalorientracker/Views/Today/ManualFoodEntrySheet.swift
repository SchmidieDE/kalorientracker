import SwiftUI

struct ManualFoodEntrySheet: View {
    let onSave: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, calories, protein, carbs, fat
    }

    private var isValid: Bool {
        !name.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        EntryField(title: "Name", placeholder: "z.B. Haferflocken mit Milch", text: $name)
                            .focused($focusedField, equals: .name)

                        // Calories (optional)
                        EntryField(title: "Kalorien (kcal)", placeholder: "optional", text: $calories, keyboardType: .numberPad)
                            .focused($focusedField, equals: .calories)

                        // Macros (all optional)
                        HStack(spacing: 12) {
                            EntryField(title: "Protein (g)", placeholder: "–", text: $protein, keyboardType: .decimalPad)
                                .focused($focusedField, equals: .protein)
                            EntryField(title: "Carbs (g)", placeholder: "–", text: $carbs, keyboardType: .decimalPad)
                                .focused($focusedField, equals: .carbs)
                            EntryField(title: "Fett (g)", placeholder: "–", text: $fat, keyboardType: .decimalPad)
                                .focused($focusedField, equals: .fat)
                        }

                        // Save button
                        GradientButton("Speichern", icon: "checkmark") {
                            saveEntry()
                        }
                        .opacity(isValid ? 1 : 0.5)
                        .disabled(!isValid)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Manueller Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Constants.Colors.textSecondary)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Fertig") { focusedField = nil }
                }
            }
            .onAppear { focusedField = .name }
        }
    }

    private func saveEntry() {
        guard isValid else { return }
        let entry = FoodEntry(
            name: name,
            calories: Int(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbs: Double(carbs) ?? 0,
            fat: Double(fat) ?? 0,
            confidence: 1.0,
            imageData: nil,
            portionDescription: "1 Portion",
            analysisSource: .cloud,
            mealCategory: MealCategory.fromCurrentTime()
        )
        onSave(entry)
        dismiss()
    }
}

private struct EntryField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Constants.Colors.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(12)
                .background(Constants.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }
}
