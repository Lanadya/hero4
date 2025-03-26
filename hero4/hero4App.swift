import SwiftUI
import GRDB

@main
struct Hero4App: App {
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
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
