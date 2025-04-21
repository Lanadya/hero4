import Foundation
import SwiftUI
import Combine

// A simple class to share state across the app
class AppState: ObservableObject {
    static let shared = AppState()
    
    // Haupt-Statevariablen
    @Published var lastCreatedClassId: UUID?
    @Published var shouldNavigateToStudentsList = false
    @Published var shouldSelectClassInStudentsList = false
    @Published var selectedClassId: UUID?
    
    // Neue Eigenschaft zum Tracking des App-Loading-Status
    @Published var isAppBusy: Bool = false
    
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

    // Liste der letzten Aktualisierungen, um zyklische Updates zu erkennen
    private var recentUpdates: [(source: String, time: Date)] = []
    private let maxRecentUpdates = 10
    
    // Aktualisiert die ausgewählte Klasse mit verbesserter Nachverfolgung
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
        let recentUpdatesFromSameSource = recentUpdates.filter { 
            $0.source == originName && now.timeIntervalSince($0.time) < 1.0 
        }
        
        if recentUpdatesFromSameSource.count >= 3 {
            print("WARNING AppState: Too many updates (\(recentUpdatesFromSameSource.count)) from the same source \(originName) within 1 second. Possible update loop detected.")
            return
        }
        
        // Update zur Liste hinzufügen
        recentUpdates.append((source: originName, time: now))
        if recentUpdates.count > maxRecentUpdates {
            recentUpdates.removeFirst() // Älteste entfernen
        }
        
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
}
