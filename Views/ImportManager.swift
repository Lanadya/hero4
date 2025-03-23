//
//  ImportManager.swift
//  hero4
//
//  Created by Nina Klee on 17.03.25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum FileImportType {
    case csv
    case excel

    var allowedContentTypes: [UTType] {
        switch self {
        case .csv:
            return [UTType.commaSeparatedText]
        case .excel:
            return [UTType.spreadsheet]
        }
    }

    var description: String {
        switch self {
        case .csv:
            return "CSV"
        case .excel:
            return "Excel"
        }
    }
}

enum ImportError: Error, LocalizedError {
    case accessDenied
    case invalidFile
    case noData
    case parseError(String)
    case invalidHeader
    case missingFirstName
    case missingLastName
    case duplicateEntry(String)
    case classLimitReached
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Zugriff auf Datei verweigert."
        case .invalidFile:
            return "Ungültiges Dateiformat."
        case .noData:
            return "Keine Daten in der Datei gefunden."
        case .parseError(let details):
            return "Fehler beim Parsen der Datei: \(details)"
        case .invalidHeader:
            return "Ungültige oder fehlende Spaltenüberschriften."
        case .missingFirstName:
            return "Vorname fehlt."
        case .missingLastName:
            return "Nachname fehlt."
        case .duplicateEntry(let name):
            return "Schüler '\(name)' existiert bereits in dieser Klasse."
        case .classLimitReached:
            return "Klassenlimit von 40 Schülern erreicht."
        case .unknownError(let error):
            return "Unbekannter Fehler: \(error.localizedDescription)"
        }
    }
}

class ImportManager: ObservableObject {
    @Published var selectedFileType: FileImportType = .csv
    @Published var showFileImporter = false
    @Published var isProcessing = false
    @Published var error: ImportError?
    @Published var showError = false

    // Daten aus der importierten Datei
    @Published var columnHeaders: [String] = []
    @Published var previewRows: [[String]] = []
    @Published var allRows: [[String]] = []

    // Mapping-Konfiguration
    @Published var firstNameColumn: String?
    @Published var lastNameColumn: String?
    @Published var notesColumn: String?

    // Erfolgsstatistik
    @Published var importedCount = 0
    @Published var failedCount = 0

    let dataStore = DataStore.shared
    var selectedClassId: UUID

    init(classId: UUID) {
        self.selectedClassId = classId
    }

    func processSelectedFile(_ url: URL) {
        isProcessing = true

        // Sicheren Zugriff auf die Datei anfordern
        guard url.startAccessingSecurityScopedResource() else {
            displayError(.accessDenied)
            isProcessing = false
            return
        }

        // Stelle sicher, dass wir den Zugriff wieder freigeben, wenn wir fertig sind
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            let fileData = try Data(contentsOf: url)

            switch selectedFileType {
            case .csv:
                try processCSVData(fileData)
            case .excel:
                try processExcelData(fileData)
            }

        } catch let importError as ImportError {
            displayError(importError)
        } catch {
            displayError(.unknownError(error))
        }

        isProcessing = false
    }

    private func processCSVData(_ data: Data) throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidFile
        }

        // Einfache CSV-Verarbeitung (für komplexere Fälle sollte eine Bibliothek wie SwiftCSV verwendet werden)
        var rows = content.components(separatedBy: "\n")

        guard !rows.isEmpty else {
            throw ImportError.noData
        }

        // Entferne leere Zeilen
        rows = rows.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let headerRow = rows.first else {
            throw ImportError.noData
        }

        // Spaltenüberschriften extrahieren
        columnHeaders = parseCSVRow(headerRow)

        guard !columnHeaders.isEmpty else {
            throw ImportError.invalidHeader
        }

        // Datenzeilen extrahieren
        let dataRows = Array(rows.dropFirst())
        allRows = dataRows.map { parseCSVRow($0) }

        // Vorschau erstellen (erste 5 Zeilen)
        previewRows = Array(allRows.prefix(5))

        // Automatisch Spalten zuordnen, wenn möglich
        autoMapColumns()
    }

    private func processExcelData(_ data: Data) throws {
        // In einer echten App würden wir hier eine Excel-Bibliothek verwenden
        // Da dies eine Demo ist, werfen wir eine Fehlermeldung
        throw ImportError.parseError("Excel-Import wird in einer späteren Version implementiert.")
    }

    private func parseCSVRow(_ row: String) -> [String] {
        // Einfache CSV-Parsing-Logik (für robustere Verarbeitung eine Bibliothek verwenden)
        // Beachtet Anführungszeichen und Kommas innerhalb von Anführungszeichen
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes = !inQuotes
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Letztes Feld nicht vergessen
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
    }

    private func autoMapColumns() {
        // Versuche, Spalten automatisch anhand der Überschriften zuzuordnen
        for header in columnHeaders {
            let lowerHeader = header.lowercased()

            if firstNameColumn == nil && (lowerHeader.contains("vorname") || lowerHeader.contains("first") || lowerHeader == "vname") {
                firstNameColumn = header
            }

            if lastNameColumn == nil && (lowerHeader.contains("nachname") || lowerHeader.contains("last") || lowerHeader == "name" || lowerHeader == "nname") {
                lastNameColumn = header
            }

            if notesColumn == nil && (lowerHeader.contains("notiz") || lowerHeader.contains("note") || lowerHeader.contains("bemerkung") || lowerHeader.contains("hinweis")) {
                notesColumn = header
            }
        }
    }

    func importStudents() -> (successes: Int, failures: Int) {
        guard let firstNameCol = firstNameColumn, let lastNameCol = lastNameColumn else {
            displayError(.invalidHeader)
            return (0, 0)
        }

        var successCount = 0
        var failureCount = 0

        let currentStudentCount = dataStore.getStudentsForClass(classId: selectedClassId).count
        let remainingSlots = 40 - currentStudentCount

        if remainingSlots <= 0 {
            displayError(.classLimitReached)
            return (0, allRows.count)
        }

        // Nur so viele Schüler importieren, wie Platz ist
        let rowsToProcess = Array(allRows.prefix(remainingSlots))

        for row in rowsToProcess {
            do {
                // Index der Spalten finden
                guard let firstNameIndex = columnHeaders.firstIndex(of: firstNameCol),
                      let lastNameIndex = columnHeaders.firstIndex(of: lastNameCol) else {
                    throw ImportError.invalidHeader
                }

                // Daten extrahieren
                let firstName = firstNameIndex < row.count ? row[firstNameIndex] : ""
                let lastName = lastNameIndex < row.count ? row[lastNameIndex] : ""

                var notes: String? = nil
                if let notesCol = notesColumn,
                   let notesIndex = columnHeaders.firstIndex(of: notesCol),
                   notesIndex < row.count {
                    notes = row[notesIndex].isEmpty ? nil : row[notesIndex]
                }

                // Validieren
                if firstName.isEmpty && lastName.isEmpty {
                    throw ImportError.missingFirstName
                }

                // Prüfen auf doppelte Namen
                if !dataStore.isStudentNameUnique(firstName: firstName, lastName: lastName, classId: selectedClassId) {
                    throw ImportError.duplicateEntry("\(firstName) \(lastName)")
                }

                // Neuen Schüler erstellen
                let student = Student(
                    firstName: firstName,
                    lastName: lastName,
                    classId: selectedClassId,
                    notes: notes
                )

                try student.validate()

                // In Datenbank speichern
                dataStore.addStudent(student)
                successCount += 1

            } catch ImportError.duplicateEntry(let name) {
                print("Duplikat gefunden: \(name)")
                failureCount += 1
                continue
            } catch {
                failureCount += 1
                continue
            }
        }

        importedCount = successCount
        failedCount = failureCount

        return (successCount, failureCount)
    }

    private func displayError(_ error: ImportError) {
        self.error = error
        self.showError = true
    }
}
