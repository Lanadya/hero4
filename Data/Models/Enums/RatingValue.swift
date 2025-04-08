import Foundation

// Enum für die Bewertungsskala
public enum RatingValue: String, Codable, CaseIterable {
    // 4-stufige Bewertungsskala (aktuelle, konfirmierte Variante)
    case excellent = "++" // Sehr gut
    case good = "+" // Gut
    case fair = "-" // Mittel
    case poor = "--" // Schwach
    
    // Für die Darstellung der Bewertungen in der UI
    public var displayName: String {
        switch self {
        case .excellent: return "++"
        case .good: return "+"
        case .fair: return "-"
        case .poor: return "--"
        }
    }
    
    // String-Wert für Anzeige (Alias zu displayName für Kompatibilität)
    public var stringValue: String {
        return displayName
    }
    
    // Für die Farbdarstellung
    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "teal"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    // Numerischen Wert für Sortierung oder Berechnungen
    public var numericValue: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        }
    }
}

// Helfer für die 6-stufige Bewertungsskala (alternative Variante)
public enum RatingValueExtended: String, Codable, CaseIterable {
    case outstanding = "+++" // Hervorragend
    case excellent = "++" // Sehr gut
    case good = "+" // Gut
    case fair = "o" // Befriedigend
    case poor = "-" // Schwach
    case veryPoor = "--" // Sehr schwach
    
    // Konvertierung zur Standard-Bewertungsskala
    public var toStandardRating: RatingValue {
        switch self {
        case .outstanding, .excellent: return .excellent
        case .good: return .good
        case .fair: return .fair
        case .poor, .veryPoor: return .poor
        }
    }
    
    // Für die Darstellung der Bewertungen in der UI
    public var displayName: String {
        switch self {
        case .outstanding: return "+++"
        case .excellent: return "++"
        case .good: return "+"
        case .fair: return "o"
        case .poor: return "-"
        case .veryPoor: return "--"
        }
    }
    
    // Für die Farbdarstellung
    public var color: String {
        switch self {
        case .outstanding: return "indigo"
        case .excellent: return "green"
        case .good: return "teal"
        case .fair: return "blue"
        case .poor: return "orange"
        case .veryPoor: return "red"
        }
    }
    
    // Numerischen Wert für Sortierung oder Berechnungen
    public var numericValue: Int {
        switch self {
        case .outstanding: return 6
        case .excellent: return 5
        case .good: return 4
        case .fair: return 3
        case .poor: return 2
        case .veryPoor: return 1
        }
    }
}