import SwiftData
import Foundation

enum AnalysisSource: String, Codable {
    case cloud = "cloud"
    case onDevice = "onDevice"
}

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var name: String = ""
    var calories: Int = 0
    var protein: Double = 0.0
    var carbs: Double = 0.0
    var fat: Double = 0.0
    var confidence: Double = 0.0
    var portionDescription: String = ""
    var suggestion: String?
    var analysisSource: String = AnalysisSource.cloud.rawValue
    var mealCategoryRaw: String = MealCategory.fromCurrentTime().rawValue
    var isFavorite: Bool = false

    @Attribute(.externalStorage)
    var imageData: Data?

    init(name: String, calories: Int, protein: Double, carbs: Double, fat: Double, confidence: Double, imageData: Data?, portionDescription: String = "", suggestion: String? = nil, analysisSource: AnalysisSource = .cloud, mealCategory: MealCategory? = nil) {
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.confidence = confidence
        self.imageData = imageData
        self.portionDescription = portionDescription
        self.suggestion = suggestion
        self.analysisSource = analysisSource.rawValue
        self.mealCategoryRaw = (mealCategory ?? MealCategory.fromCurrentTime()).rawValue
    }

    var source: AnalysisSource {
        AnalysisSource(rawValue: analysisSource) ?? .cloud
    }

    var mealCategory: MealCategory {
        get { MealCategory(rawValue: mealCategoryRaw) ?? .snack }
        set { mealCategoryRaw = newValue.rawValue }
    }
}
