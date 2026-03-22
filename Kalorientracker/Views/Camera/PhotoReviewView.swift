import SwiftUI
import SwiftData

struct PhotoReviewView: View {
    let image: UIImage
    @ObservedObject var analyzer: FoodAnalyzer
    let onSave: (NutritionResult) -> Void
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [UserProfile]
    @State private var result: NutritionResult?
    @State private var hasStarted = false

    private var profile: UserProfile? { profiles.first }
    @EnvironmentObject var authManager: AuthManager
    private var aiMode: AIMode { profile?.aiMode ?? .cloudOnly }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            // Background image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.5))
                .blur(radius: result != nil ? 8 : 0)

            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()

                    // Source indicator
                    HStack(spacing: 6) {
                        Image(systemName: analyzer.analysisSource == .cloud ? "cloud.fill" : "iphone")
                            .font(.caption)
                        Text(analyzer.analysisSource == .cloud ? "Cloud" : "On-Device")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .padding()

                Spacer()

                // Loading or Result
                if analyzer.isAnalyzing {
                    ShimmerLoadingView(text: "Analysiere dein Essen...")
                        .padding()
                        .transition(.opacity)
                } else if let error = analyzer.lastError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Constants.Colors.warning)
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        GradientButton("Nochmal versuchen", icon: "arrow.clockwise") {
                            startAnalysis()
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                    .glassCard()
                    .padding()
                } else if let result {
                    AnalysisResultCard(result: result, onSave: {
                        let impact = UINotificationFeedbackGenerator()
                        impact.notificationOccurred(.success)
                        onSave(result)
                    }, onDiscard: {
                        dismiss()
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
                }
            }
        }
        .interactiveDismissDisabled(analyzer.isAnalyzing)
        .onAppear {
            if !hasStarted {
                hasStarted = true
                startAnalysis()
            }
        }
    }

    private func startAnalysis() {
        Task {
            let res = await analyzer.analyze(image: image, aiMode: aiMode, authToken: authManager.accessToken)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                result = res
            }
        }
    }
}
