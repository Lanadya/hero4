import Foundation
import SwiftUI
import Combine

// A simple class to share state across the app
class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Navigation State
    @Published var shouldNavigateToStudentsList = false
    @Published var shouldSelectClassInStudentsList = false
    @Published var selectedClassId: UUID?
    
    // MARK: - Debug Mode
    @Published var debugTapCount = 0
    @Published var showDebugView = false
    
    // MARK: - Loading Indicator
    @Published var isAppBusy = false
    
    // MARK: - Data State
    @Published var lastCreatedClassId: UUID?
    
    // Cancellables für das Speichern von Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Verhindert doppelte Initialisierung
    private var hasInitialized = false
    
    // Konstruktor mit Initialisierungslogik
    private init() {
        // Nach kurzer Verzögerung als initialisiert markieren
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasInitialized = true
        }
    }

    // Call this after successfully creating a class
    func didCreateClass(_ classId: UUID) {
        self.lastCreatedClassId = classId
        self.shouldSelectClassInStudentsList = true
    }

    // Call this after selecting the class in the students list
    func didSelectClassInStudentsList() {
        self.shouldSelectClassInStudentsList = false
    }

    // Optimierte Speicherung der letzten Aktualisierungen pro Quelle
    private var lastUpdateBySource: [String: Date] = [:]
    
    // Aktualisiert die ausgewählte Klasse mit optimierter Nachverfolgung
    func setSelectedClass(_ id: UUID?, origin: AnyObject? = nil) {
        // Prüfe, ob die ID überhaupt anders ist
        guard selectedClassId != id else {
            print("DEBUG AppState: Ignoring duplicate class selection: \(id?.uuidString ?? "none")")
            return 
        }
        
        // Ursprungsname für Debugging
        let originName = origin != nil ? "\(type(of: origin!))" : "direct call"
        
        // Prüfe auf zu häufige Updates von der gleichen Quelle
        let now = Date()
        
        // Optimierte Erkennung von zu häufigen Updates
        if let lastUpdate = lastUpdateBySource[originName], now.timeIntervalSince(lastUpdate) < 1.0 {
            // Zähle die Updates innerhalb der letzten Sekunde
            var updateCount = 1 // Das aktuelle Update mitzählen
            
            // Durchlaufe alle Quellen und ermittle, wie oft diese Quelle kürzlich aktualisiert wurde
            for (source, time) in lastUpdateBySource {
                if source == originName && now.timeIntervalSince(time) < 1.0 {
                    updateCount += 1
                }
            }
            
            if updateCount >= 3 {
                print("WARNING AppState: Too many updates (\(updateCount)) from the same source \(originName) within 1 second. Possible update loop detected.")
                return
            }
        }
        
        // Update zur Tracking-Map hinzufügen
        lastUpdateBySource[originName] = now
        
        // Alte Updates entfernen (optional - für bessere Speichernutzung)
        let oldThreshold = now.addingTimeInterval(-10.0) // Entferne Updates, die älter als 10 Sekunden sind
        lastUpdateBySource = lastUpdateBySource.filter { $0.value > oldThreshold }
        
        // Nun die eigentliche Aktualisierung durchführen
        print("DEBUG AppState: Class updated to \(id?.uuidString ?? "none") by \(originName)")
        selectedClassId = id
        
        // In UserDefaults speichern
        if let id = id {
            UserDefaults.standard.set(id.uuidString, forKey: "activeClassId")
        } else {
            UserDefaults.standard.removeObject(forKey: "activeClassId")
        }
    }

    // Aktiviere den Debug-Modus
    func activateDebugMode() {
        print("Debug-Modus aktiviert!")
        showDebugView = true
    }
}
