import SwiftUI
import SwiftData

struct PhotoReviewView: View {
    let image: UIImage
    @ObservedObject var analyzer: FoodAnalyzer
    let onSave: (NutritionResult, MealCategory) -> Void
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

            VStack(spacing: 0) {
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
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Loading or Result
                if analyzer.isAnalyzing {
                    ShimmerLoadingView(text: aiMode == .localOnly ? "On-Device Analyse..." : "Analysiere dein Essen...")
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
                            .fixedSize(horizontal: false, vertical: true)
                        GradientButton("Nochmal versuchen", icon: "arrow.clockwise") {
                            startAnalysis()
                        }
                        SecondaryButton(title: "Abbrechen") {
                            dismiss()
                        }
                    }
                    .padding(20)
                    .glassCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else if let result {
                    // Result card — bottom aligned, scrollable if tall
                    ScrollView(.vertical, showsIndicators: false) {
                        AnalysisResultCard(result: result, onSave: { resolvedResult, mealCategory in
                            let impact = UINotificationFeedbackGenerator()
                            impact.notificationOccurred(.success)
                            onSave(resolvedResult, mealCategory)
                        }, onDiscard: {
                            dismiss()
                        })
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.65)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
