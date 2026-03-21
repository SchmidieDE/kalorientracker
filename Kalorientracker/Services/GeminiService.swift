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

    private let apiKey: String
    private let model: String

    init(apiKey: String = Constants.geminiAPIKey, model: String = Constants.geminiModel) {
        self.apiKey = apiKey
        self.model = model
    }

    func analyze(image: UIImage) async throws -> NutritionResult {
        guard let imageData = image.jpegCompressed(quality: 0.7, maxDimension: 1024) else {
            throw GeminiError.imageTooLarge
        }

        let base64Image = imageData.base64EncodedString()
        let url = URL(string: "\(Constants.geminiBaseURL)/\(model):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let prompt = """
        Du bist ein erfahrener Ernährungsberater und Lebensmittelexperte.
        Analysiere das Foto und identifiziere das Essen/Getränk.

        Aufgabe:
        1. Identifiziere ALLE sichtbaren Lebensmittel auf dem Foto
        2. Schätze die Portionsgröße basierend auf visuellen Hinweisen
        3. Berechne die Nährwerte für die GESAMTE sichtbare Portion

        Wichtige Regeln:
        - Wenn mehrere Lebensmittel sichtbar sind, fasse sie zu EINEM Eintrag zusammen
        - Gib den Namen auf Deutsch an
        - Sei bei der Kalorienzahl eher konservativ-realistisch
        - Die Confidence (0.0-1.0) soll widerspiegeln, wie sicher du dir bei der Identifikation bist
        - Wenn das Bild kein Essen zeigt, setze confidence auf 0.0 und calories auf 0
        - Gib einen kurzen, hilfreichen Ernährungstipp zum Essen

        Antworte NUR im geforderten JSON-Format.
        """

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "name": ["type": "STRING", "description": "Name des Essens auf Deutsch"],
                        "calories": ["type": "INTEGER", "description": "Geschätzte Kalorien (kcal)"],
                        "protein": ["type": "NUMBER", "description": "Protein in Gramm"],
                        "carbs": ["type": "NUMBER", "description": "Kohlenhydrate in Gramm"],
                        "fat": ["type": "NUMBER", "description": "Fett in Gramm"],
                        "confidence": ["type": "NUMBER", "description": "Konfidenz 0.0-1.0"],
                        "portionDescription": ["type": "STRING", "description": "Beschreibung der Portionsgröße"],
                        "suggestions": ["type": "STRING", "description": "Ernährungstipp zu diesem Essen"]
                    ],
                    "required": ["name", "calories", "protein", "carbs", "fat", "confidence", "portionDescription"]
                ]
            ]
        ]

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

        // Parse Gemini response structure
        let result: NutritionResult
        do {
            let geminiResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let candidates = geminiResponse?["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String,
                  let jsonData = text.data(using: .utf8) else {
                throw GeminiError.decodingError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing response text"]))
            }
            result = try JSONDecoder().decode(NutritionResult.self, from: jsonData)
        } catch let error as GeminiError {
            throw error
        } catch {
            throw GeminiError.decodingError(error)
        }

        if result.confidence < 0.1 {
            throw GeminiError.notFood
        }

        return result
    }
}
