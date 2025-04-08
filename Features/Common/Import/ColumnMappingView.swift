//
//  ColumnMappingView.swift
//  hero4
//
//  Created by Nina Klee on 17.03.25.
//

import Foundation
import SwiftUI

struct ColumnMappingView: View {
    @ObservedObject var importManager: ImportManager
    @Binding var isPresented: Bool
    @Binding var refreshStudents: Bool

    @State private var showResultAlert = false
    @State private var importInProgress = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack {
                // Fehlermeldung anzeigen (falls vorhanden)
                if let error = errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Fehler beim Import")
                                .font(.headline)
                                .foregroundColor(.red)
                        }

                        Text(error)
                            .foregroundColor(.red)

                        // Hilfreiche Tipps je nach Fehlertyp hinzufügen
                        if error.contains("Limit") || error.contains("40 Schüler") {
                            Text("Tipp: Sie können maximal 40 Schüler pro Klasse haben. Teilen Sie größere Listen auf mehrere Klassen auf.")
                                .font(.caption)
                                .padding(.top, 4)
                        } else if error.contains("existiert bereits") {
                            Text("Tipp: Überprüfen Sie Ihre Daten auf doppelte Namen oder nutzen Sie Zweitnamen zur Unterscheidung.")
                                .font(.caption)
                                .padding(.top, 4)
                        } else if error.contains("Spaltenüberschriften") {
                            Text("Tipp: Stellen Sie sicher, dass Ihre CSV-Datei in der ersten Zeile Spaltenüberschriften enthält.")
                                .font(.caption)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                Form {
                    Section(header: Text("Spalten zuordnen")) {
                        Text("Bitte ordnen Sie die Spalten aus Ihrer Datei den entsprechenden Schülerfeldern zu.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)

                        Picker("Vorname", selection: $importManager.firstNameColumn) {
                            Text("Nicht importieren").tag(nil as String?)
                            ForEach(importManager.columnHeaders, id: \.self) { header in
                                Text(header).tag(header as String?)
                            }
                        }

                        Picker("Nachname", selection: $importManager.lastNameColumn) {
                            Text("Nicht importieren").tag(nil as String?)
                            ForEach(importManager.columnHeaders, id: \.self) { header in
                                Text(header).tag(header as String?)
                            }
                        }

                        Picker("Notizen (optional)", selection: $importManager.notesColumn) {
                            Text("Nicht importieren").tag(nil as String?)
                            ForEach(importManager.columnHeaders, id: \.self) { header in
                                Text(header).tag(header as String?)
                            }
                        }
                    }

                    Section(header: Text("Vorschau")) {
                        if importManager.previewRows.isEmpty {
                            Text("Keine Vorschau verfügbar")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ScrollView(.horizontal) {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Headers
                                    HStack {
                                        ForEach(importManager.columnHeaders, id: \.self) { header in
                                            Text(header)
                                                .font(.headline)
                                                .frame(width: 100, alignment: .leading)
                                                .foregroundColor(isColumnMapped(header) ? .blue : .primary)
                                        }
                                    }
                                    .padding(.bottom, 4)

                                    // Beispieldaten
                                    ForEach(0..<min(5, importManager.previewRows.count), id: \.self) { rowIndex in
                                        let row = importManager.previewRows[rowIndex]
                                        HStack {
                                            ForEach(0..<min(row.count, importManager.columnHeaders.count), id: \.self) { colIndex in
                                                Text(row[colIndex])
                                                    .frame(width: 100, alignment: .leading)
                                                    .foregroundColor(isColumnMapped(importManager.columnHeaders[colIndex]) ? .blue : .primary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Section {
                        Button(action: {
                            let _ = importStudents()
                        }) {
                            if importInProgress {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text("Importiere...")
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Importieren")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .disabled(importInProgress || !isReadyToImport())
                    }
                }
            }
            .navigationBarTitle("Spalten zuordnen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Abbrechen") {
                isPresented = false
            })
            .alert(isPresented: $showResultAlert) {
                if importManager.failedCount > 0 {
                    return Alert(
                        title: Text("Import teilweise abgeschlossen"),
                        message: Text("\(importManager.importedCount) Schüler erfolgreich importiert. \(importManager.failedCount) Fehler aufgetreten.\n\nHäufige Probleme: Doppelte Namen oder fehlende Daten."),
                        primaryButton: .default(Text("OK")) {
                            isPresented = false
                            refreshStudents = true
                        },
                        secondaryButton: .destructive(Text("Details anzeigen")) {
                            // Hier könnte man noch eine detailliertere Ansicht der Fehler anzeigen
                            // Für den Anfang reicht die einfache Meldung
                            isPresented = false
                            refreshStudents = true
                        }
                    )
                } else {
                    return Alert(
                        title: Text("Import erfolgreich"),
                        message: Text("\(importManager.importedCount) Schüler wurden erfolgreich importiert."),
                        dismissButton: .default(Text("OK")) {
                            isPresented = false
                            refreshStudents = true
                        }
                    )
                }
            }
            Button(action: {
                // Einfache CSV-Vorlage erstellen und teilen
                let csvTemplate = "Vorname,Nachname,Notizen\nMax,Mustermann,Guter Schüler\nAnna,Schmidt,Braucht Unterstützung\n"

                if let fileURL = createTempCSVFile(content: csvTemplate) {
                    let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(activityVC, animated: true)
                    }
                }
            }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Beispiel-Vorlage herunterladen")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func isColumnMapped(_ header: String) -> Bool {
        return importManager.firstNameColumn == header ||
               importManager.lastNameColumn == header ||
               importManager.notesColumn == header
    }

    private func isReadyToImport() -> Bool {
        return importManager.firstNameColumn != nil || importManager.lastNameColumn != nil
    }

    @discardableResult
    private func importStudents() -> Bool {
        importInProgress = true
        errorMessage = nil

        // Prüfe Klassenlimit
        let currentStudentCount = DataStore.shared.getStudentsForClass(classId: importManager.selectedClassId).count
        let remainingSlots = 40 - currentStudentCount

        if remainingSlots <= 0 {
            errorMessage = "Diese Klasse hat bereits 40 Schüler. Es können keine weiteren Schüler hinzugefügt werden."
            importInProgress = false
            return false
        }

        if importManager.allRows.count > remainingSlots {
            errorMessage = "Es können nur \(remainingSlots) von \(importManager.allRows.count) Schülern importiert werden, da das Limit bei 40 Schülern pro Klasse liegt."
        }

        // Starten des Imports in einer Task ohne Abhängigkeiten vom Main Actor
        Task {
            // Verwende Task.detached um die Isolation zu verbessern
            let _ = await Task.detached {
                await importManager.importStudents()
            }.value
            
            // UI-Update auf dem Main Actor
            await MainActor.run {
                importInProgress = false
                
                if importManager.showError && importManager.error != nil {
                    errorMessage = importManager.error?.localizedDescription
                } else {
                    showResultAlert = true
                }
            }
        }
        
        return true
    }

    func createTempCSVFile(content: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("schueler_vorlage.csv")

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Fehler beim Erstellen der Vorlagendatei: \(error)")
            return nil
        }
    }
}
