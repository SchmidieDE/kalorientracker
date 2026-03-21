import Foundation

struct CalorieCalculator {
    /// Calculate daily calorie status
    static func status(consumed: Int, target: Int) -> CalorieStatus {
        let difference = consumed - target
        let percentage = target > 0 ? Double(consumed) / Double(target) : 0

        if percentage < 0.8 {
            return .underEating(deficit: abs(difference))
        } else if percentage <= 1.1 {
            return .onTrack(difference: difference)
        } else {
            return .overEating(surplus: difference)
        }
    }

    /// Get progress color based on percentage
    static func progressColor(percentage: Double) -> ProgressColorScheme {
        if percentage < 0.5 {
            return .init(primary: .init(hex: 0x00D4AA), secondary: .init(hex: 0x00D4AA).opacity(0.3))
        } else if percentage < 0.8 {
            return .init(primary: .init(hex: 0x00D4AA), secondary: .init(hex: 0x00B4D8).opacity(0.3))
        } else if percentage <= 1.0 {
            return .init(primary: .init(hex: 0x00B4D8), secondary: .init(hex: 0xFFB347).opacity(0.3))
        } else if percentage <= 1.2 {
            return .init(primary: .init(hex: 0xFFB347), secondary: .init(hex: 0xFF6B6B).opacity(0.3))
        } else {
            return .init(primary: .init(hex: 0xFF6B6B), secondary: .init(hex: 0xFF6B6B).opacity(0.3))
        }
    }
}

import SwiftUI

enum CalorieStatus {
    case underEating(deficit: Int)
    case onTrack(difference: Int)
    case overEating(surplus: Int)

    var message: String {
        switch self {
        case .underEating(let deficit): return "\(deficit) kcal unter Ziel"
        case .onTrack(let diff):
            if diff <= 0 { return "Im Zielbereich" }
            return "Leicht über Ziel"
        case .overEating(let surplus): return "\(surplus) kcal über Ziel"
        }
    }

    var color: Color {
        switch self {
        case .underEating: return Constants.Colors.success
        case .onTrack: return Constants.Colors.gradientEnd
        case .overEating: return Constants.Colors.danger
        }
    }

    var icon: String {
        switch self {
        case .underEating: return "arrow.down.circle.fill"
        case .onTrack: return "checkmark.circle.fill"
        case .overEating: return "arrow.up.circle.fill"
        }
    }
}

struct ProgressColorScheme {
    let primary: Color
    let secondary: Color
}
