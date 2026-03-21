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

    func analyze(image: UIImage, aiMode: AIMode) async -> NutritionResult? {
        isAnalyzing = true
        lastError = nil
        lastResult = nil

        defer { isAnalyzing = false }

        do {
            let result: NutritionResult

            switch aiMode {
            case .cloudOnly:
                analysisSource = .cloud
                result = try await geminiService.analyze(image: image)

            case .localOnly:
                analysisSource = .onDevice
                // On-device inference placeholder — Gemini as fallback
                if hasInternet {
                    analysisSource = .cloud
                    result = try await geminiService.analyze(image: image)
                } else {
                    lastError = "On-Device Modell wird noch integriert. Bitte verbinde dich mit dem Internet."
                    return nil
                }

            case .automatic:
                if hasInternet {
                    analysisSource = .cloud
                    result = try await geminiService.analyze(image: image)
                } else {
                    analysisSource = .onDevice
                    lastError = "Kein Internet verfügbar. On-Device Analyse wird noch integriert."
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
