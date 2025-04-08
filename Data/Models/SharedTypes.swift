//import Foundation
//
//// Bewertungstypen für die gesamte App
//enum RatingValue: String, Codable, CaseIterable {
//    case excellent = "excellent"
//    case good = "good"
//    case fair = "fair"
//    case poor = "poor"
//    case veryPoor = "veryPoor"
//
//    var stringValue: String {
//        switch self {
//        case .excellent: return "excellent"
//        case .good: return "good"
//        case .fair: return "fair"
//        case .poor: return "poor"
//        case .veryPoor: return "veryPoor"
//        }
//    }
//
//    // Diese Eigenschaft hinzufügen
//        var numericValue: Double {
//            switch self {
//            case .excellent: return 1.0  // Beste Note
//            case .good: return 2.0
//            case .fair: return 3.0
//            case .poor: return 4.0  // Schlechteste Note
//            case .veryPoor: return 5.0  // Schlechteste Note
//            }
//        }
//}
