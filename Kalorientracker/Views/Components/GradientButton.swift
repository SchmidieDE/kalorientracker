import SwiftUI

struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.bold())
                }
                Text(title)
                    .font(.body.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Constants.Colors.accentGradient)
            .clipShape(Capsule())
            .shadow(color: Constants.Colors.gradientStart.opacity(0.4), radius: 15, y: 5)
        }
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Constants.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Constants.Colors.surface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Constants.Colors.glassBorder, lineWidth: 1)
                )
        }
    }
}
