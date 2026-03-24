import SwiftUI

enum Constants {
    static let apiBaseURL = "https://kalorientracker.webgantic.com"
    static let supabaseURL = "https://supabase-kalorientracker.webgantic.com"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzcwNzM2Njk4LCJleHAiOjIwODYwOTY2OTh9.iDTVeUvL3pd0vLXWIgUFi1g5M5wDyxEF6fljvYuZC18"

    // GGUF models for on-device inference (Qwen3.5 Vision)
    // 4B variant — better quality, needs ≥6GB RAM (iPhone 15 Pro+)
    static let largeModelName = "Qwen3.5-4B.Q4_K_M.gguf"
    static let largeMmprojName = "Qwen3.5-4B-mmproj.gguf"
    static let largeModelURL = "\(apiBaseURL)/models/Qwen3.5-4B.Q4_K_M.gguf"
    static let largeMmprojURL = "\(apiBaseURL)/models/Qwen3.5-4B-mmproj.gguf"
    static let largeModelSize: Int64 = 2_800_000_000

    // 2B variant — faster, works on ≥4GB RAM (iPhone 12+)
    static let smallModelName = "Qwen3.5-2B.Q4_K_M.gguf"
    static let smallMmprojName = "Qwen3.5-2B-mmproj.gguf"
    static let smallModelURL = "\(apiBaseURL)/models/Qwen3.5-2B.Q4_K_M.gguf"
    static let smallMmprojURL = "\(apiBaseURL)/models/Qwen3.5-2B-mmproj.gguf"
    static let smallModelSize: Int64 = 1_300_000_000

    // Auto-select based on device RAM
    static var localModelName: String {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1024 * 1024 * 1024 ? largeModelName : smallModelName
    }
    static var localMmprojName: String {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1024 * 1024 * 1024 ? largeMmprojName : smallMmprojName
    }
    static var localModelURL: String {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1024 * 1024 * 1024 ? largeModelURL : smallModelURL
    }
    static var localMmprojURL: String {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1024 * 1024 * 1024 ? largeMmprojURL : smallMmprojURL
    }
    static var localModelSize: Int64 {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1024 * 1024 * 1024 ? largeModelSize : smallModelSize
    }

    enum Colors {
        static let background = Color(hex: 0x0A0E1A)
        static let surface = Color(hex: 0x141929)
        static let gradientStart = Color(hex: 0x00D4AA)
        static let gradientEnd = Color(hex: 0x00B4D8)
        static let success = Color(hex: 0x00D4AA)
        static let warning = Color(hex: 0xFFB347)
        static let danger = Color(hex: 0xFF6B6B)
        static let proteinColor = Color(hex: 0x6C9FFF)
        static let carbsColor = Color(hex: 0xFFB347)
        static let fatColor = Color(hex: 0xFF6B9D)
        static let textSecondary = Color(hex: 0x8B95A8)
        static let glassBorder = Color.white.opacity(0.15)

        static var accentGradient: LinearGradient {
            LinearGradient(colors: [gradientStart, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
