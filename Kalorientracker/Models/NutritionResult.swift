import Foundation

struct FoodAlternative: Codable {
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let emoji: String?
}

struct NutritionResult: Codable {
    let isFood: Bool?
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let confidence: Double
    let portionDescription: String
    let suggestions: String?
    let emoji: String?
    let alternatives: [FoodAlternative]?
}
