//
//  ImportManager.swift
//  hero4
//
//  Created by Nina Klee on 17.03.25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

// ================ LOCAL TYPE DEFINITIONS ================
// IMPORTANT: These are strictly local to this file
// DO NOT IMPORT these from other files

// IM = ImportManager prefix to avoid name collisions
enum IM_FileImportType {
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

enum IM_ImportError: Error, LocalizedError {
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

@MainActor
class ImportManager: ObservableObject {
    @Published var selectedFileType: IM_FileImportType = .csv
    @Published var showFileImporter = false
    @Published var isProcessing = false
    @Published var error: IM_ImportError?
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

    private let dataStore = DataStore.shared
    internal let selectedClassId: UUID
    private var cancellables = Set<AnyCancellable>()

    init(classId: UUID) {
        self.selectedClassId = classId
    }

    func processSelectedFile(_ url: URL) {
        isProcessing = true

        Task {
            do {
                // Sicheren Zugriff auf die Datei anfordern
                guard url.startAccessingSecurityScopedResource() else {
                    throw IM_ImportError.accessDenied
                }

                defer {
                    url.stopAccessingSecurityScopedResource()
                }

                let fileData = try Data(contentsOf: url)

                switch selectedFileType {
                case .csv:
                    try await processCSVData(fileData)
                case .excel:
                    try await processExcelData(fileData)
                }

            } catch let importError as IM_ImportError {
                displayError(importError)
            } catch {
                displayError(.unknownError(error))
            }

            isProcessing = false
        }
    }

    private func processCSVData(_ data: Data) async throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw IM_ImportError.invalidFile
        }

        // Einfache CSV-Verarbeitung (für komplexere Fälle sollte eine Bibliothek wie SwiftCSV verwendet werden)
        var rows = content.components(separatedBy: "\n")

        guard !rows.isEmpty else {
            throw IM_ImportError.noData
        }

        // Entferne leere Zeilen
        rows = rows.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let headerRow = rows.first else {
            throw IM_ImportError.noData
        }

        // Spaltenüberschriften extrahieren
        columnHeaders = parseCSVRow(headerRow)

        guard !columnHeaders.isEmpty else {
            throw IM_ImportError.invalidHeader
        }

        // Datenzeilen extrahieren
        let dataRows = Array(rows.dropFirst())
        allRows = dataRows.map { parseCSVRow($0) }

        // Vorschau erstellen (erste 5 Zeilen)
        previewRows = Array(allRows.prefix(5))

        // Automatisch Spalten zuordnen, wenn möglich
        autoMapColumns()
    }

    private func processExcelData(_ data: Data) async throws {
        // In einer echten App würden wir hier eine Excel-Bibliothek verwenden
        // Da dies eine Demo ist, werfen wir eine Fehlermeldung
        throw IM_ImportError.parseError("Excel-Import wird in einer späteren Version implementiert.")
    }

    // In ImportManager.swift - Finden Sie diese Funktion und ersetzen Sie sie
    private func parseCSVRow(_ row: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false

        // Trennzeichen automatisch erkennen (Komma oder Semikolon)
        let delimiter: Character = row.contains(";") ? ";" : ","

        for char in row {
            if char == "\"" {
                inQuotes = !inQuotes
            } else if char == delimiter && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Letztes Feld hinzufügen
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        // Entferne Anführungszeichen um die Feldwerte, wenn vorhanden
        return fields.map { field in
            var processed = field
            if processed.hasPrefix("\"") && processed.hasSuffix("\"") && processed.count >= 2 {
                processed.removeFirst()
                processed.removeLast()
            }
            return processed
        }
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

    @discardableResult
    @MainActor
    func importStudents() async -> (successes: Int, failures: Int) {
        guard let firstNameCol = firstNameColumn, let lastNameCol = lastNameColumn else {
            displayError(.invalidHeader)
            return (0, 0)
        }

        // Kurze Verzögerung, um zu garantieren, dass es sich um eine echte Async-Operation handelt
        try? await Task.sleep(for: .milliseconds(10))

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

        for (rowIndex, row) in rowsToProcess.enumerated() {
            do {
                // Index der Spalten finden
                guard let firstNameIndex = columnHeaders.firstIndex(of: firstNameCol),
                      let lastNameIndex = columnHeaders.firstIndex(of: lastNameCol) else {
                    throw IM_ImportError.invalidHeader
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
                    throw IM_ImportError.missingFirstName
                }

                // Prüfen auf doppelte Namen
                if !dataStore.isStudentNameUnique(firstName: firstName, lastName: lastName, classId: selectedClassId) {
                    throw IM_ImportError.duplicateEntry("\(firstName) \(lastName)")
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

            } catch IM_ImportError.duplicateEntry(let name) {
                print("Duplikat gefunden in Zeile \(rowIndex + 2): \(name)")
                failureCount += 1
                continue
            } catch {
                print("Fehler in Zeile \(rowIndex + 2): \(error.localizedDescription)")
                failureCount += 1
                continue
            }
        }

        importedCount = successCount
        failedCount = failureCount

        return (successCount, failureCount)
    }

    private func displayError(_ error: IM_ImportError) {
        self.error = error
        self.showError = true
    }

    deinit {
        cancellables.removeAll()
    }
}
