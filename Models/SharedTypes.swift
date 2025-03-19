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
}
