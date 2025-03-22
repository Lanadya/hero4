import Foundation

// Bewertungstypen für die gesamte App
enum RatingValue: Int, Codable {
    case doublePlus = 1
    case plus = 2
    case minus = 3
    case doubleMinus = 4

    var stringValue: String {
        switch self {
        case .doublePlus: return "++"
        case .plus: return "+"
        case .minus: return "-"
        case .doubleMinus: return "--"
        }
    }

    // Diese Eigenschaft hinzufügen
        var numericValue: Double {
            switch self {
            case .doublePlus: return 1.0  // Beste Note
            case .plus: return 2.0
            case .minus: return 3.0
            case .doubleMinus: return 4.0  // Schlechteste Note
            }
        }
}
