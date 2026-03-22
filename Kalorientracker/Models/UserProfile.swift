import SwiftData
import Foundation

enum NutritionGoal: String, Codable, CaseIterable {
    case lose = "lose"
    case maintain = "maintain"
    case gain = "gain"

    var label: String {
        switch self {
        case .lose: return "Abnehmen"
        case .maintain: return "Halten"
        case .gain: return "Zunehmen"
        }
    }

    var icon: String {
        switch self {
        case .lose: return "arrow.down.circle"
        case .maintain: return "equal.circle"
        case .gain: return "arrow.up.circle"
        }
    }

    /// Calorie adjustment factor relative to TDEE
    var calorieFactor: Double {
        switch self {
        case .lose: return 0.8       // -20% deficit
        case .maintain: return 1.0
        case .gain: return 1.15      // +15% surplus
        }
    }
}

enum AIMode: String, Codable, CaseIterable {
    case cloudOnly = "cloudOnly"
    case localOnly = "localOnly"

    var label: String {
        switch self {
        case .cloudOnly: return "Cloud"
        case .localOnly: return "On-Device"
        }
    }

    var icon: String {
        switch self {
        case .cloudOnly: return "cloud"
        case .localOnly: return "iphone"
        }
    }
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var age: Int = 30
    var weightKg: Double = 75.0
    var heightCm: Double = 175.0
    var isMale: Bool = true
    var activityLevel: Int = 2
    var weeklyTrainingHours: Double = 3.0
    var targetCalories: Int = 2000
    var useComputedTarget: Bool = true
    var aiModeRaw: String = AIMode.cloudOnly.rawValue
    var localModelDownloaded: Bool = false
    var hasCompletedOnboarding: Bool = false
    var goalRaw: String = "maintain"

    init() {}

    var goal: NutritionGoal {
        get { NutritionGoal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }

    var aiMode: AIMode {
        get { AIMode(rawValue: aiModeRaw) ?? .cloudOnly }
        set { aiModeRaw = newValue.rawValue }
    }

    /// BMR using Mifflin-St Jeor equation
    var bmr: Double {
        if isMale {
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        } else {
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }
    }

    /// Activity multipliers
    static let activityMultipliers: [Double] = [1.2, 1.375, 1.55, 1.725, 1.9]
    static let activityLabels: [String] = ["Sitzend", "Leicht aktiv", "Moderat", "Aktiv", "Sehr aktiv"]
    static let activityIcons: [String] = ["figure.seated.seatbelt", "figure.walk", "figure.run", "figure.highintensity.intervaltraining", "figure.strengthtraining.traditional"]

    /// TDEE (Total Daily Energy Expenditure)
    var tdee: Double {
        let multiplier = Self.activityMultipliers[min(activityLevel, 4)]
        return bmr * multiplier
    }

    /// Recommended daily calories (adjusted for goal)
    var recommendedCalories: Int {
        useComputedTarget ? Int(tdee * goal.calorieFactor) : targetCalories
    }
}
