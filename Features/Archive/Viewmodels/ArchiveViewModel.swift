

import Foundation
import Combine

class ArchiveViewModel: ObservableObject {
    // Veröffentlichte Variablen für die View

    // DataStore-Referenz
    let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Initialisierung
    }

    // MARK: - Funktionalität hinzufügen
}
