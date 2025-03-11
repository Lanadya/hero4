import Foundation
import Combine

class TimetableViewModel: ObservableObject {
    @Published var classes: [Class] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var warningMessage: String?
    @Published var showWarning: Bool = false

    private let dataStore = DataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Beobachte Änderungen im DataStore
        dataStore.$classes
            .receive(on: RunLoop.main)
            .sink { [weak self] classes in
                let activeClasses = classes.filter { !$0.isArchived }
                self?.classes = activeClasses
                print("DEBUG ViewModel: classes wurden aktualisiert, Anzahl: \(activeClasses.count)")
            }
            .store(in: &cancellables)
    }

    func loadClasses() {
        print("DEBUG ViewModel: loadClasses() aufgerufen")
        dataStore.loadClasses()
    }

    func getClassAt(row: Int, column: Int) -> Class? {
        let result = dataStore.getClassAt(row: row, column: column)
        if result != nil {
            print("DEBUG ViewModel: Klasse an (\(row), \(column)) gefunden: \(result!.name)")
        }
        return result
    }

    func saveClass(_ class: Class) {
        do {
            print("DEBUG ViewModel: Versuche Klasse zu speichern: \(`class`.name) an (\(`class`.row), \(`class`.column))")

            try `class`.validate()

            // Überprüfe, ob der Klassenname eindeutig ist
            if !isClassNameValid(`class`.name, exceptClassId: `class`.id) {
                showError(message: "Klassenname '\(`class`.name)' existiert bereits. Bitte wählen Sie einen eindeutigen Namen.")
                return
            }

            // Überprüfe, ob die Position verfügbar ist
            if !validateClassPositionIsAvailable(row: `class`.row, column: `class`.column, exceptClassId: `class`.id) {
                showError(message: "Position (\(`class`.row), \(`class`.column)) ist bereits belegt.")
                return
            }

            // Überprüfe auf ähnliche Klassennamen und zeige eine Warnung, wenn welche gefunden werden
            let similarNames = findSimilarClassNames(`class`.name, exceptClassId: `class`.id)
            if !similarNames.isEmpty {
                let warningNamesList = similarNames.joined(separator: ", ")
                showWarning(message: "Ähnliche Klassennamen gefunden: \(warningNamesList). Möchten Sie fortfahren?")
                // Trotzdem speichern, es ist nur eine Warnung
            }

            var updatedClass = `class`
            updatedClass.modifiedAt = Date()

            // Neues oder bestehendes Objekt?
            let isNewClass = updatedClass.id == UUID()

            if isNewClass {
                // Neue Klasse
                dataStore.addClass(updatedClass)
                print("DEBUG ViewModel: Neue Klasse hinzugefügt: \(updatedClass.name)")
            } else {
                // Bestehende Klasse aktualisieren
                dataStore.updateClass(updatedClass)
                print("DEBUG ViewModel: Klasse aktualisiert: \(updatedClass.name)")
            }

            // Manuell die Klassen neu laden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadClasses()
            }

        } catch Class.ValidationError.invalidName {
            showError(message: "Klassenname muss zwischen 1 und 8 Zeichen lang sein.")
        } catch Class.ValidationError.invalidNote {
            showError(message: "Notiz darf maximal 10 Zeichen lang sein.")
        } catch {
            showError(message: "Fehler beim Speichern der Klasse: \(error.localizedDescription)")
        }
    }

    func deleteClass(id: UUID) {
        print("DEBUG ViewModel: Klasse löschen mit ID: \(id)")
        dataStore.deleteClass(id: id)

        // Manuell die Klassen neu laden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadClasses()
        }
    }

    func archiveClass(_ class: Class) {
        print("DEBUG ViewModel: Klasse archivieren: \(`class`.name)")
        dataStore.archiveClass(`class`)

        // Manuell die Klassen neu laden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadClasses()
        }
    }

    func validateClassPositionIsAvailable(row: Int, column: Int, exceptClassId: UUID? = nil) -> Bool {
        return dataStore.validateClassPositionIsAvailable(row: row, column: column, exceptClassId: exceptClassId)
    }

    // MARK: - Validierung für Klassennamen

    /// Prüft, ob ein Klassenname gültig ist (eindeutig)
    func isClassNameValid(_ name: String, exceptClassId: UUID? = nil) -> Bool {
        return dataStore.isClassNameUnique(name, exceptClassId: exceptClassId)
    }

    /// Sucht nach ähnlichen Klassennamen (für Warnungen)
    func findSimilarClassNames(_ name: String, exceptClassId: UUID? = nil) -> [String] {
        return dataStore.findSimilarClassNames(name, exceptClassId: exceptClassId)
    }

    // MARK: - Fehler- und Warnungs-Handling

    private func showError(message: String) {
        print("DEBUG ViewModel: FEHLER: \(message)")
        errorMessage = message
        showError = true
    }

    private func showWarning(message: String) {
        print("DEBUG ViewModel: WARNUNG: \(message)")
        warningMessage = message
        showWarning = true
    }

    // MARK: - Debug-Funktionen

    func resetAllData() {
        print("DEBUG ViewModel: Alle Daten zurücksetzen")
        dataStore.resetAllData()

        // Manuell die Klassen neu laden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadClasses()
        }
    }

    func addSampleData() {
        print("DEBUG ViewModel: Beispieldaten hinzufügen")
        dataStore.addSampleData()

        // Manuell die Klassen neu laden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadClasses()
        }
    }
}
