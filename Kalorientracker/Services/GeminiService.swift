import UIKit
import Foundation

final class GeminiService: Sendable {
    enum GeminiError: LocalizedError {
        case networkError(Error)
        case apiError(Int, String)
        case decodingError(Error)
        case notFood
        case imageTooLarge

        var errorDescription: String? {
            switch self {
            case .networkError: return "Keine Internetverbindung"
            case .apiError(let code, let msg): return "API-Fehler (\(code)): \(msg)"
            case .decodingError: return "Antwort konnte nicht verarbeitet werden"
            case .notFood: return "Kein Essen erkannt"
            case .imageTooLarge: return "Bild ist zu groß"
            }
        }
    }

    func analyze(image: UIImage, authToken: String? = nil) async throws -> NutritionResult {
        guard let imageData = image.jpegCompressed(quality: 0.7, maxDimension: 1024) else {
            throw GeminiError.imageTooLarge
        }

        let base64Image = imageData.base64EncodedString()
        let url = URL(string: "\(Constants.apiBaseURL)/api/analyze")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30

        let body: [String: String] = ["image": base64Image]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.apiError(0, "Ungültige Antwort")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(httpResponse.statusCode, errorBody)
        }

        let result: NutritionResult
        do {
            result = try JSONDecoder().decode(NutritionResult.self, from: data)
        } catch {
            throw GeminiError.decodingError(error)
        }

        if result.confidence < 0.1 {
            throw GeminiError.notFood
        }

        return result
    }
}
