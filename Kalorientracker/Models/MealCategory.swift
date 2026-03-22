import Foundation

enum MealCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Frühstück"
        case .lunch: return "Mittagessen"
        case .dinner: return "Abendessen"
        case .snack: return "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "leaf"
        }
    }

    /// Auto-assign meal category based on current hour
    static func fromCurrentTime() -> MealCategory {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 { return .breakfast }
        if hour < 14 { return .lunch }
        if hour < 17 { return .snack }
        return .dinner
    }
}
