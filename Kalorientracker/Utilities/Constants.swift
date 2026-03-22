import SwiftUI

enum Constants {
    static let apiBaseURL = "https://kalorientracker.webgantic.com"
    static let supabaseURL = "https://supabase-kalorientracker.webgantic.com"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzcwNzM2Njk4LCJleHAiOjIwODYwOTY2OTh9.iDTVeUvL3pd0vLXWIgUFi1g5M5wDyxEF6fljvYuZC18"

    // GGUF model for on-device inference (Qwen3.5 4B Vision — best for iPhone)
    static let localModelName = "Qwen3.5-4B.Q4_K_M.gguf"
    static let localMmprojName = "Qwen3.5-4B-mmproj.gguf"
    static let localModelURL = "https://huggingface.co/bjivanovich/Qwen3.5-4B-Vision-GGUF/resolve/main/Qwen3.5-4B.Q4_K_M.gguf"
    static let localMmprojURL = "https://huggingface.co/bjivanovich/Qwen3.5-4B-Vision-GGUF/resolve/main/Qwen3.5-4B.BF16-mmproj.gguf"
    static let localModelSize: Int64 = 2_800_000_000 // ~2.8GB

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
