import SwiftUI

@MainActor
@Observable
final class ToastManager {
    static let shared = ToastManager()

    var currentToast: Toast?

    func show(_ message: String, icon: String = "checkmark.circle.fill", style: ToastStyle = .success) {
        withAnimation(.spring(response: 0.4)) {
            currentToast = Toast(message: message, icon: icon, style: style)
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.3)) {
                currentToast = nil
            }
        }
    }
}

struct Toast: Equatable {
    let message: String
    let icon: String
    let style: ToastStyle
}

enum ToastStyle {
    case success, error, info

    var color: Color {
        switch self {
        case .success: return Constants.Colors.success
        case .error: return Constants.Colors.danger
        case .info: return Constants.Colors.gradientEnd
        }
    }
}

struct ToastOverlay: View {
    let toast: Toast?

    var body: some View {
        VStack {
            if let toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.icon)
                        .foregroundStyle(toast.style.color)
                    Text(toast.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
            Spacer()
        }
    }
}
