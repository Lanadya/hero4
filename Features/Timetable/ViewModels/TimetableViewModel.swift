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
    private var isInitialSetup = true

    init() {
           dataStore.$classes
               .receive(on: RunLoop.main)
               .removeDuplicates() // 🔥 Verhindert unnötige Updates
               .sink { [weak self] classes in
                   let activeClasses = classes.filter { !$0.isArchived }
                   if self?.classes != activeClasses { // Nur bei Änderungen updaten
                       self?.classes = activeClasses
                   }
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

    func saveClass(_ classObj: Class) {
        do {
            print("DEBUG ViewModel: Versuche Klasse zu speichern: \(classObj.name) an (\(classObj.row), \(classObj.column))")

            try classObj.validate()

            // Überprüfe, ob der Klassenname eindeutig ist
            if !isClassNameValid(classObj.name, exceptClassId: classObj.id) {
                showError(message: "Klassenname '\(classObj.name)' existiert bereits. Bitte wählen Sie einen eindeutigen Namen.")
                return
            }

            // Überprüfe, ob die Position verfügbar ist
            if !validateClassPositionIsAvailable(row: classObj.row, column: classObj.column, exceptClassId: classObj.id) {
                showError(message: "Position (\(classObj.row), \(classObj.column)) ist bereits belegt.")
                return
            }

            // Überprüfe auf ähnliche Klassennamen und zeige eine Warnung, wenn welche gefunden werden
            let similarNames = findSimilarClassNames(classObj.name, exceptClassId: classObj.id)
            if !similarNames.isEmpty {
                let warningNamesList = similarNames.joined(separator: ", ")
                showWarning(message: "Ähnliche Klassennamen gefunden: \(warningNamesList). Möchten Sie fortfahren?")
                // Trotzdem speichern, es ist nur eine Warnung
            }

            var updatedClass = classObj
            updatedClass.modifiedAt = Date()

            // Prüfen, ob eine Klasse mit dieser ID bereits existiert
            let existingClassIndex = dataStore.classes.firstIndex(where: { $0.id == updatedClass.id })
            let isNewClass = existingClassIndex == nil

            print("DEBUG ViewModel: \(isNewClass ? "Neue Klasse anlegen" : "Bestehende Klasse aktualisieren")")

            if isNewClass {
                // Neue Klasse
                dataStore.addClass(updatedClass)
                print("DEBUG ViewModel: Neue Klasse hinzugefügt: \(updatedClass.name) mit ID \(updatedClass.id)")
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
