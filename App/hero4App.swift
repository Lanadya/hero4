import SwiftUI
import GRDB

@main
struct Hero4App: App {
    // AppState als globaler Zustand
    @StateObject private var appState = AppState.shared
    
    init() {
        // Hinweis: Das automatische Backup wurde entfernt, da es für den Endbenutzer nicht sinnvoll ist
        // Backups werden stattdessen über die BackupManager-Klasse manuell erstellt
        
        // Beim ersten Start die Migration durchführen
        if !UserDefaults.standard.bool(forKey: "hasCompletedDBMigration") {
            do {
                try GRDBManager.shared.migrateAllDataFromUserDefaults()
                // Nur bei erfolgreicher Migration den Flag setzen
                UserDefaults.standard.set(true, forKey: "hasCompletedDBMigration")
                print("DEBUG App: Datenmigration erfolgreich abgeschlossen")
            } catch {
                print("ERROR App: Fehler bei der Datenmigration: \(error)")
                // Bei Fehler versuchen wir es später wieder
                // Kein Flag setzen, damit es beim nächsten Start erneut versucht wird
            }
        }
        
        // GRDB-Konfiguration optimieren - Busy-Timeout für bessere Parallelverarbeitung
        do {
            // Die bestehende AppDatabase.shared-Instanz verwenden statt eine neue Verbindung zu erstellen
            try AppDatabase.shared.write { db in
                try db.execute(sql: "PRAGMA busy_timeout = 5000")  // 5000 Millisekunden
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