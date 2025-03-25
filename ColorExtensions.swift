import SwiftUI

// Farbschema-Definition
extension Color {
    // Subdued Professional Farbpalette - Hauptfarben
    static let gradePrimary = Color(hex: "#1A365D")     // Gedämpftes Marineblau
    static let heroSecondary = Color(hex: "#2C7A7B")    // Sanftes Türkis
    static let accentSand = Color(hex: "#C05621")       // Warmes Sand

    // Abgeschwächte/Hellere Varianten für Hintergründe etc.
    static let gradePrimaryLight = Color(hex: "#1A365D").opacity(0.1)
    static let heroSecondaryLight = Color(hex: "#2C7A7B").opacity(0.1)
    static let accentSandLight = Color(hex: "#C05621").opacity(0.1)

    // Zusätzliche UI-Farben
    static let gridBackground = Color(hex: "#F9FAFB")   // Sehr helles Grau für Tabellenhintergrund
    static let gridHeaderBg = Color(hex: "#E5E7EB")     // Etwas dunkleres Grau für Kopfzeilen
    static let gridLineColor = Color(hex: "#D1D5DB")    // Für Tabellenlinien
    static let gridFilledCell = Color(hex: "#E6F0F3")   // Helles Blaugrau für gefüllte Zellen

    // Hex-Farben-Konvertierung
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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
