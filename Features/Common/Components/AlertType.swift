// AlertType.swift
import Foundation
import SwiftUI

enum AlertType: Identifiable {
    case info
    case error(String)
    case delete
    case archive
    case classChange

    // Common id implementation
    var id: Int {
        switch self {
        case .info: return 0
        case .error: return 1
        case .delete: return 2
        case .archive: return 3
        case .classChange: return 4
        }
    }
}
