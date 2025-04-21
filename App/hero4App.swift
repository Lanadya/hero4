import SwiftUI
import GRDB

@main
struct Hero4App: App {
    // AppState als globaler Zustand
    @StateObject private var appState = AppState.shared
    
    init() {
        // Beim ersten Start die Migration durchführen
        if !UserDefaults.standard.bool(forKey: "hasCompletedDBMigration") {
            do {
                try GRDBManager.shared.migrateAllDataFromUserDefaults()
                UserDefaults.standard.set(true, forKey: "hasCompletedDBMigration")
                print("DEBUG App: Datenmigration erfolgreich abgeschlossen")
            } catch {
                print("ERROR App: Fehler bei der Datenmigration: \(error)")
            }
        }
        
        // GRDB-Konfiguration optimieren - Busy-Timeout für bessere Parallelverarbeitung
        do {
            let dbQueue = try DatabaseQueue()
            var config = Configuration()
            config.busyMode = .timeout(5.0)  // 5 Sekunden Timeout
            try? dbQueue.write { db in
                try? db.execute(sql: "PRAGMA busy_timeout = 5000")  // 5000 Millisekunden
            }
            print("DEBUG App: GRDB-Konfiguration optimiert")
        } catch {
            print("WARN App: Konnte GRDB-Konfiguration nicht optimieren: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)  // AppState global weitergeben
        }
    }
}