import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .glassCard()
    }
}

struct ShimmerLoadingView: View {
    @State private var shimmerOffset: CGFloat = -200
    let text: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Constants.Colors.surface)
                    .frame(height: 120)

                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.1), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 120)
                    .offset(x: shimmerOffset)
                    .mask(RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 8) {
                ProgressView()
                    .tint(Constants.Colors.gradientStart)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
    }
}
