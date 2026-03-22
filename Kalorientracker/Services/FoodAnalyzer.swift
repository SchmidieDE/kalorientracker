import UIKit
import Network

@MainActor
final class FoodAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastResult: NutritionResult?
    @Published var lastError: String?
    @Published var analysisSource: AnalysisSource = .cloud

    private let geminiService = GeminiService()
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
                if authToken == nil {
                    lastError = "Bitte melde dich an, um Cloud-AI zu nutzen"
                    return nil
                }
                analysisSource = .cloud
                result = try await geminiService.analyze(image: image, authToken: authToken)

            case .localOnly:
                analysisSource = .onDevice
                if hasInternet {
                    // Fallback to cloud while on-device is not ready
                    analysisSource = .cloud
                    result = try await geminiService.analyze(image: image, authToken: authToken)
                } else {
                    lastError = "On-Device Modell wird noch integriert. Bitte verbinde dich mit dem Internet."
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
