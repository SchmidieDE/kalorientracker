import SwiftUI

struct AddFoodSheet: View {
    let onCamera: () -> Void
    let onManual: () -> Void
    let onFavorites: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 24) {
                // Handle bar
                Capsule()
                    .fill(Constants.Colors.textSecondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                Text("Essen hinzufügen")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    AddFoodOption(
                        icon: "camera.fill",
                        title: "Foto aufnehmen",
                        subtitle: "KI analysiert dein Essen",
                        gradient: true
                    ) {
                        dismiss()
                        onCamera()
                    }

                    AddFoodOption(
                        icon: "text.magnifyingglass",
                        title: "Manuell eingeben",
                        subtitle: "Suche oder gib Nährwerte ein",
                        gradient: false
                    ) {
                        dismiss()
                        onManual()
                    }

                    AddFoodOption(
                        icon: "star.fill",
                        title: "Favoriten",
                        subtitle: "Häufig gegessene Mahlzeiten",
                        gradient: false
                    ) {
                        dismiss()
                        onFavorites()
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }
}

private struct AddFoodOption: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gradient ? AnyShapeStyle(Constants.Colors.accentGradient) : AnyShapeStyle(Constants.Colors.surface))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(gradient ? .white : Constants.Colors.gradientStart)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Constants.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }
            .padding(14)
            .background(Constants.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Constants.Colors.glassBorder, lineWidth: 0.5)
            )
        }
    }
}
