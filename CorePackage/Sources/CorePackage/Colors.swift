import SwiftUI

extension Color {
    // Grayscale Colors
    public static let dividerGray = Color(red: 0.9, green: 0.9, blue: 0.9)
    public static let backgroundGray = Color(red: 0.95, green: 0.95, blue: 0.95)
    
    // Theme Colors
    public static let gradeLight = Color(red: 0.8, green: 0.9, blue: 1.0)  // Light blue for grades
    public static let heroLight = Color(red: 1.0, green: 0.9, blue: 0.8)   // Light orange for hero elements
    
    // Additional theme colors can be added here
    public static let primary = Color(red: 0.2, green: 0.4, blue: 0.8)     // Primary brand color
    public static let secondary = Color(red: 0.8, green: 0.4, blue: 0.2)   // Secondary brand color
    public static let heroSecondary = Color(red: 0.8, green: 0.4, blue: 0.2)   // Secondary brand color for hero elements
    public static let heroSecondaryLight = Color(red: 1.0, green: 0.8, blue: 0.7)   // Light version of hero secondary
    public static let accent = Color(red: 0.4, green: 0.8, blue: 0.2)      // Accent color
    public static let accentGreen = Color(red: 0.3, green: 0.7, blue: 0.3)     // Green accent
    public static let accentGreenLight = Color(red: 0.8, green: 0.95, blue: 0.8)  // Light green accent
    
    // Grade-spezifische Farben (fehlen laut Fehlermeldungen)
    public static let gradePrimary = Color(red: 0.3, green: 0.6, blue: 0.9)     // Hauptfarbe für Noten
    public static let gradePrimaryLight = Color(red: 0.7, green: 0.85, blue: 1.0) // Hellere Version für Noten
    
    // Top-Left und Top-Right Farben für InfoDialogView
    public static let topLeft = Color(red: 0.2, green: 0.5, blue: 0.8)     // Obere linke Ecke
    public static let topRight = Color(red: 0.3, green: 0.6, blue: 0.9)    // Obere rechte Ecke
} 