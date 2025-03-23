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
                // Fehlermeldung oben anzeigen, außerhalb des ScrollViews
                if let error = errorMessage {
                    VStack(spacing: 4) {
                        Text("Fehler")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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

                if errorMessage != nil {
                    Section {
                        Text(errorMessage!)
                            .foregroundColor(.red)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section {
                    Button(action: {
                        importStudents()
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
            .navigationBarTitle("Spalten zuordnen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Abbrechen") {
                isPresented = false
            })
            .alert(isPresented: $showResultAlert) {
                Alert(
                    title: Text("Import abgeschlossen"),
                    message: Text("\(importManager.importedCount) Schüler erfolgreich importiert. \(importManager.failedCount) Fehler."),
                    dismissButton: .default(Text("OK")) {
                        isPresented = false
                        refreshStudents = true
                    }
                )
            }
            .alert(isPresented: $importManager.showError) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(importManager.error?.localizedDescription ?? "Unbekannter Fehler"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    }
    private func isColumnMapped(_ header: String) -> Bool {
        return importManager.firstNameColumn == header ||
               importManager.lastNameColumn == header ||
               importManager.notesColumn == header
    }

    private func isReadyToImport() -> Bool {
        return importManager.firstNameColumn != nil || importManager.lastNameColumn != nil
    }

    private func importStudents() {
        importInProgress = true
        errorMessage = nil

        // Prüfe zuerst die Anzahl der Schüler
        let currentStudentCount = DataStore.shared.getStudentsForClass(classId: importManager.selectedClassId).count
        let remainingSlots = 40 - currentStudentCount

        if remainingSlots <= 0 {
            errorMessage = "Diese Klasse hat bereits 40 Schüler. Mehr können nicht hinzugefügt werden."
            importInProgress = false
            return
        }

        // Wenn mehr Zeilen vorhanden sind als Plätze, zeige eine Warnung
        if importManager.allRows.count > remainingSlots {
            errorMessage = "Es können nur \(remainingSlots) von \(importManager.allRows.count) Schülern importiert werden, da die Klasse auf 40 Schüler begrenzt ist."
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = importManager.importStudents()

            DispatchQueue.main.async {
                importInProgress = false

                if importManager.showError && importManager.error != nil {
                    errorMessage = importManager.error?.localizedDescription
                } else {
                    showResultAlert = true
                }
            }
        }
    }
}
