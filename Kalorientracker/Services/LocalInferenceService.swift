import UIKit

/// On-device food analysis placeholder.
/// Full llama.cpp integration with Qwen3.5 Vision GGUF will be added
/// once the SPM package is properly configured for iOS.
final class LocalInferenceService: @unchecked Sendable {

    enum InferenceError: LocalizedError {
        case notYetAvailable

        var errorDescription: String? {
            "On-Device Analyse wird\nnoch integriert.\n\nBitte nutze vorerst den\nCloud-Modus."
        }
    }

    func analyze(image: UIImage, modelPath: URL, mmprojPath: URL) async throws -> NutritionResult {
        // TODO: Integrate llama.cpp for local GGUF inference
        // The model files are ready in models/ directory
        // Needs: llama.cpp SPM with clip/llava vision support for iOS
        throw InferenceError.notYetAvailable
    }
}
