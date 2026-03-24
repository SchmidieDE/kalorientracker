import UIKit
import Network

@MainActor
final class FoodAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastResult: NutritionResult?
    @Published var lastError: String?
    @Published var analysisSource: AnalysisSource = .cloud

    private let geminiService = GeminiService()
    private let localService = LocalInferenceService()
    private let monitor = NWPathMonitor()
    private var hasInternet = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.hasInternet = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    deinit {
        monitor.cancel()
    }

    func analyze(image: UIImage, aiMode: AIMode, authToken: String? = nil) async -> NutritionResult? {
        isAnalyzing = true
        lastError = nil
        lastResult = nil

        defer { isAnalyzing = false }

        do {
            let result: NutritionResult

            switch aiMode {
            case .cloudOnly:
                analysisSource = .cloud
                result = try await geminiService.analyze(image: image, authToken: authToken)

            case .localOnly:
                let downloadManager = ModelDownloadManager.shared
                if downloadManager.bothFilesExist() {
                    // Use on-device model
                    analysisSource = .onDevice
                    result = try await localService.analyze(
                        image: image,
                        modelPath: downloadManager.resolvedModelPath,
                        mmprojPath: downloadManager.resolvedMmprojPath
                    )
                } else if hasInternet {
                    // Fallback to cloud if model not downloaded yet
                    analysisSource = .cloud
                    result = try await geminiService.analyze(image: image, authToken: authToken)
                } else {
                    lastError = "On-Device Modell nicht installiert.\n\nLade es unter Profil >\nOn-Device Modell herunter."
                    return nil
                }
            }

            lastResult = result
            return result

        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}
