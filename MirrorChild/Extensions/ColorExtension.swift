import SwiftUI

// 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 应用颜色 - 定义全局颜色常量供全应用使用
extension Color {
    static let accentGreen = Color(hex: "749474") // Green accent
    static let surfaceLightGreen = Color(hex: "A9C2A9") // Light green surface
    
    // Theme colors
    static let backgroundPrimary = surfaceLightGreen.opacity(0.2)
    static let backgroundSecondary = surfaceLightGreen.opacity(0.1)
    static let accentLight = accentGreen.opacity(0.5)
    static let accentDark = accentGreen.opacity(0.8)
} 