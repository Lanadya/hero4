//
//  AlertType.swift
//  hero4
//
//  Created by Nina Klee on 25.03.25.
//

import Foundation
import SwiftUI

// Enum für Fehlerbehandlung
enum AlertType: Identifiable {
    case info
    case error(String)

    var id: Int {
        switch self {
        case .info: return 0
        case .error: return 1
        }
    }
}
