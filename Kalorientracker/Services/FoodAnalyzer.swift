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
                // TODO: Implement on-device inference
                analysisSource = .onDevice
                lastError = "On-Device Modell wird noch eingerichtet..."
                return nil

            case .automatic:
                if hasInternet {
                    analysisSource = .cloud
                    result = try await geminiService.analyze(image: image)
                } else {
                    // TODO: Fall back to on-device
                    analysisSource = .onDevice
                    lastError = "Kein Internet. On-Device Modell wird noch eingerichtet..."
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
