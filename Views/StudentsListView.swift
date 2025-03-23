import SwiftUI
import UniformTypeIdentifiers

struct StudentsListView: View {

    @ObservedObject private var appState = AppState.shared
    // Initialen Parameter für die Klassenauswahl hinzufügen
    @StateObject private var viewModel: StudentsViewModel
    @State private var showAddStudentModal = false
    @State private var showEditStudentModal = false
    @State private var selectedStudent: Student?
    @State private var navigateToSeatingPlan = false
    @State private var showImportSheet = false
    @State private var showClassChangeForSelectedStudents = false

    // Für Multi-Select und Löschen
    @State private var editMode: EditMode = .inactive
    @State private var selectedStudents = Set<UUID>()
    @State private var confirmDeleteMultipleStudents = false
    @State private var showMoveClassForSelectedStudents = false

    // Für den Datei-Import
    @State private var showFileImporter = false
    @State private var importFileType: FileImportType = .csv
    @State private var showColumnMappingView = false
    @State private var refreshStudentList = false
    @StateObject private var importManager: ImportManager
    @State private var showImportHelp = false

    // Für die TabView-Integration
    @Binding var selectedTab: Int

    // Konstruktor mit der Option, eine initiale Klassen-ID zu übergeben und TabView-Integration
    init(initialClassId: UUID? = nil, selectedTab: Binding<Int> = .constant(1)) {
        _viewModel = StateObject(wrappedValue: StudentsViewModel(initialClassId: initialClassId))
        _selectedTab = selectedTab

        // Wir müssen den ImportManager mit einer initialen Klassen-ID erstellen,
        // aber wir aktualisieren diese später, wenn viewModel.selectedClassId verfügbar ist
        _importManager = StateObject(wrappedValue: ImportManager(classId: initialClassId ?? UUID()))
    }

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.classes.isEmpty {
                    // Keine Klassen vorhanden
                    noClassesView
                } else {
                    // Split-View für iPad
                    HStack {
                        // Linke Seite: Klassenliste und globale Suche
                        VStack {
                            // Globale Suche nach Schülern
                            VStack(spacing: 0) {
                                Text("Schülersuche")
                                    .font(.headline)
                                    .padding(.top)

                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)

                                    TextField("Schülernamen suchen", text: Binding(
                                        get: { viewModel.globalSearchText },
                                        set: { viewModel.updateGlobalSearchText($0) }
                                    ))
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)

                                    if !viewModel.globalSearchText.isEmpty {
                                        Button(action: {
                                            viewModel.clearGlobalSearch()
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                                if !viewModel.searchResults.isEmpty {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(viewModel.searchResults) { result in
                                                Button(action: {
                                                    viewModel.selectClass(id: result.student.classId)
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                        selectedStudent = result.student
                                                        showEditStudentModal = true
                                                    }
                                                }) {
                                                    VStack(alignment: .leading) {
                                                        Text(result.student.fullName)
                                                            .font(.headline)
                                                        Text("Klasse: \(result.className)")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                    .padding(8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color(.systemGray6))
                                                    .cornerRadius(8)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .frame(height: min(CGFloat(viewModel.searchResults.count * 70), 200))
                                }

                                Divider()
                            }

                            Text("Klassen")
                                .font(.headline)
                                .padding(.top, 8)

                            // Nach Wochentagen gruppierte Klassen
                            List {
                                ForEach(viewModel.classesByWeekday, id: \.weekday) { group in
                                    Section(header: Text(group.weekday)) {
                                        ForEach(group.classes) { classItem in
                                            Button(action: {
                                                viewModel.selectClass(id: classItem.id)
                                                // Aktualisiere die ausgewählte Klassen-ID im ImportManager
                                                importManager.selectedClassId = classItem.id
                                                // Verlasse den Bearbeitungsmodus beim Klassenwechsel
                                                editMode = .inactive
                                                selectedStudents.removeAll()
                                            }) {
                                                HStack {
                                                    Text(classItem.name)
                                                        .foregroundColor(.primary)

                                                    if let note = classItem.note, !note.isEmpty {
                                                        Text(note)
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }

                                                    Spacer()

                                                    if viewModel.selectedClassId == classItem.id {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(.blue)
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }
                            }
                            .listStyle(InsetGroupedListStyle())
                        }
                        .frame(width: 250)
                        .background(Color(.systemGroupedBackground))

                        // Rechte Seite: Schülerliste oder Platzhalter
                        if let selectedClass = viewModel.selectedClass {
                            // Schülerliste für die ausgewählte Klasse
                            studentListContent(for: selectedClass)
                        } else {
                            // Platzhalter, wenn keine Klasse ausgewählt ist
                            VStack {
                                Text("Bitte wählen Sie eine Klasse aus")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                    .padding()

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .sheet(isPresented: $showClassChangeForSelectedStudents) {
                VStack {
                    // Fehlermeldung oben anzeigen
                    if let errorMessage = viewModel.errorMessage, viewModel.showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.top)
                    }

                    ClassSelectionView(
                        classes: viewModel.classes.filter { $0.id != viewModel.selectedClassId },
                        onClassSelected: { selectedClassId in
                            // Überprüfe zuerst, ob Platz in der Zielklasse ist
                            let currentStudentCount = viewModel.getStudentCountForClass(classId: selectedClassId)
                            if currentStudentCount + selectedStudents.count > 40 {
                                showClassSelectionError("Die Zielklasse hat nur Platz für \(40 - currentStudentCount) weitere Schüler. Sie haben \(selectedStudents.count) Schüler ausgewählt.")
                                return
                            }

                            // Überprüfe auf doppelte Namen
                            var duplicateNames: [String] = []
                            for studentId in selectedStudents {
                                if let student = viewModel.dataStore.getStudent(id: studentId) {
                                    if !viewModel.isStudentNameUnique(firstName: student.firstName, lastName: student.lastName, classId: selectedClassId, exceptStudentId: student.id) {
                                        duplicateNames.append("\(student.firstName) \(student.lastName)")
                                    }
                                }
                            }

                            if !duplicateNames.isEmpty {
                                let namesStr = duplicateNames.joined(separator: ", ")
                                showClassSelectionError("Folgende Schüler existieren bereits in der Zielklasse: \(namesStr)")
                                return
                            }

                            // Verschiebe die Schüler
                            for studentId in selectedStudents {
                                viewModel.moveStudentToClass(studentId: studentId, newClassId: selectedClassId)
                            }

                            // Aktualisiere die Schülerliste und setze den State zurück
                            viewModel.loadStudentsForSelectedClass()
                            selectedStudents.removeAll()
                            editMode = .inactive
                            showClassChangeForSelectedStudents = false
                        },
                        onCancel: {
                            // Beim Abbrechen auch den Edit-Mode zurücksetzen
                            editMode = .inactive
                            selectedStudents.removeAll()
                            showClassChangeForSelectedStudents = false
                        }
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }

            .navigationBarTitle("Schülerverwaltung", displayMode: .inline)

            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(viewModel.errorMessage ?? "Unbekannter Fehler"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $confirmDeleteMultipleStudents) {
                Alert(
                    title: Text("Schüler löschen"),
                    message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") löschen? Dies kann nicht rückgängig gemacht werden."),
                    primaryButton: .destructive(Text("Löschen")) {
                        // Lösche alle ausgewählten Schüler
                        for studentId in selectedStudents {
                            viewModel.deleteStudent(id: studentId)
                        }
                        selectedStudents.removeAll()
                        editMode = .inactive
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showAddStudentModal) {
                if let classId = viewModel.selectedClassId, let className = viewModel.selectedClass?.name {
                    AddStudentView(
                        classId: classId,
                        className: className,
                        viewModel: viewModel,
                        isPresented: $showAddStudentModal
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showEditStudentModal) {
                if let student = selectedStudent {
                    EditStudentView(
                        student: student,
                        viewModel: viewModel,
                        isPresented: $showEditStudentModal
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showMoveClassForSelectedStudents) {
                if let student = selectedStudent {
                    ClassChangeView(
                        student: student,
                        viewModel: viewModel,
                        isPresented: $showMoveClassForSelectedStudents
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showColumnMappingView) {
                ColumnMappingView(
                    importManager: importManager,
                    isPresented: $showColumnMappingView,
                    refreshStudents: $refreshStudentList
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .actionSheet(isPresented: $showImportSheet) {
                ActionSheet(
                    title: Text("Schülerliste importieren"),
                    message: Text("Wählen Sie eine CSV-Datei zum Importieren"),
                    buttons: [
                        .default(Text("CSV-Datei (.csv)")) {
                            print("DEBUG: CSV-Option wurde ausgewählt")
                            importFileType = .csv
                            importManager.selectedFileType = .csv
                            showFileImporter = true  // Dies öffnet den Datei-Picker
                        },
                        .cancel(Text("Abbrechen"))
                    ]
                )
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: importFileType.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                print("DEBUG: Datei-Importer wurde geöffnet")
                do {
                    guard let selectedFile = try result.get().first else {
                        print("DEBUG: Keine Datei ausgewählt")
                        return
                    }

                    print("DEBUG: Datei ausgewählt: \(selectedFile.lastPathComponent)")
                    // Starte den Import-Prozess
                    importManager.processSelectedFile(selectedFile)

                    // Zeige die Mapping-Ansicht
                    showColumnMappingView = true

                } catch {
                    print("DEBUG: Fehler beim Auswählen der Datei: \(error.localizedDescription)")
                    viewModel.showError(message: "Fehler beim Auswählen der Datei: \(error.localizedDescription)")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())

        .onAppear {
            // Lade die Schüler für die aktuell ausgewählte Klasse
            viewModel.loadStudentsForSelectedClass()

            // Prüfe, ob eine Klasse aus UserDefaults geladen werden soll
            if let classIdString = UserDefaults.standard.string(forKey: "selectedClassForStudentsList"),
               let classId = UUID(uuidString: classIdString) {
                // Wähle die Klasse im ViewModel aus
                viewModel.selectClass(id: classId)
                // Entferne den Eintrag aus UserDefaults, damit er nicht erneut verwendet wird
                UserDefaults.standard.removeObject(forKey: "selectedClassForStudentsList")
            }
        }

        .onDisappear {
            // Beim Verlassen der View die Suche zurücksetzen
            viewModel.clearGlobalSearch()

            // Bearbeitungsmodus zurücksetzen
            editMode = .inactive
            selectedStudents.removeAll()
        }
        // Zusätzliche onChange-Funktion um auf Tab-Wechsel zu reagieren
        .onChange(of: selectedTab) { newTab in
            if newTab != 1 {  // 1 ist der Index des Schüler-Tabs
                // Suchfeld zurücksetzen, wenn zu einem anderen Tab gewechselt wird
                viewModel.clearGlobalSearch()

                // Bearbeitungsmodus zurücksetzen
                editMode = .inactive
                selectedStudents.removeAll()
            }
        }
        // Aktualisiere die Schülerliste, wenn der Import abgeschlossen ist
        .onChange(of: refreshStudentList) { refresh in
            if refresh {
                viewModel.loadStudentsForSelectedClass()
                refreshStudentList = false
            }
        }
        // Aktualisiere den ImportManager, wenn sich die ausgewählte Klasse ändert
        .onChange(of: viewModel.selectedClassId) { newClassId in
            if let classId = newClassId {
                importManager.selectedClassId = classId
            }
        }
        // Neuer onChange-Handler für selectedStudents
        .onChange(of: selectedStudents) { newSelection in
            // Wenn alle Schüler abgewählt wurden, setze den Edit-Mode zurück
            if newSelection.isEmpty && editMode == .active {
                editMode = .inactive
            }
        }
        .popover(isPresented: $showImportHelp) {
            VStack(alignment: .leading, spacing: 12) {
                Text("CSV-Import Hilfe")
                    .font(.headline)
                    .padding(.bottom, 4)

                Text("So erstellen Sie eine CSV-Datei für den Import:")
                    .font(.subheadline)
                    .padding(.bottom, 4)

                Text("1. Öffnen Sie Excel oder ein anderes Tabellenkalkulationsprogramm")
                Text("2. Erstellen Sie mindestens folgende Spalten:")
                Text("   • Vorname")
                Text("   • Nachname")
                Text("   • Notizen (optional)")
                Text("3. Wählen Sie 'Datei' → 'Speichern unter...'")
                Text("4. Als Format wählen Sie 'CSV (Trennzeichen-getrennt)'")

                Divider()
                    .padding(.vertical, 8)

                Text("Hinweise:")
                    .fontWeight(.bold)
                Text("• Die erste Zeile muss Spaltenüberschriften enthalten")
                Text("• Maximal 40 Schüler pro Klasse")
                Text("• Schüler mit identischen Namen können nicht importiert werden")

                Button("Verstanden") {
                    showImportHelp = false
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .frame(width: 350)
        }
    }

    // Hilfsfunktion für Fehlermeldungen in der ClassSelectionView
    private func showClassSelectionError(_ message: String) {
        NotificationCenter.default.post(
            name: Notification.Name("ClassSelectionError"),
            object: nil,
            userInfo: ["message": message]
        )
    }

    // MARK: - Subviews
    private var noClassesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Keine Klassen vorhanden")
                .font(.title2)
                .fontWeight(.medium)

            Text("Bitte erstellen Sie zuerst eine Klasse im Stundenplan, bevor Sie Schüler hinzufügen.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Button(action: {
                // Direkt zur Stundenplanseite (Tab 0) navigieren
                selectedTab = 0
            }) {
                HStack {
                    Image(systemName: "calendar")
                    Text("Zum Stundenplan")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding(.top, 60)
    }

    private func studentListContent(for classItem: Class) -> some View {
        VStack {
            // Header mit Klassenname und Kontrollen
            HStack {
                Text("Klasse: \(classItem.name)")
                    .font(.headline)

                if let note = classItem.note, !note.isEmpty {
                    Text("(\(note))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Multi-Select Kontrolle
                if !viewModel.students.isEmpty {
                    Button(action: {
                        editMode = editMode.isEditing ? .inactive : .active
                        if editMode == .inactive {
                            selectedStudents.removeAll()
                        }
                    }) {
                        Text(editMode.isEditing ? "Auswahl beenden" : "Mehrere Schüler auswählen")
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 4)
                }

                // Anzeige der Schüleranzahl mit Limit
                Text("\(viewModel.students.count)/40 Schüler")
                    .font(.caption)
                    .foregroundColor(viewModel.students.count >= 40 ? .red : .gray)
                    .padding(.trailing, 8)

                // Import-Button
                Button(action: {
                    print("DEBUG: Import-Button geklickt")
                    // Prüfen, ob das Klassenlimit bereits erreicht ist
                    let currentStudentCount = viewModel.getStudentCountForClass(classId: viewModel.selectedClassId ?? UUID())
                    if currentStudentCount >= 40 {
                        viewModel.showError(message: "Diese Klasse hat bereits 40 Schüler. Es können keine weiteren Schüler hinzugefügt werden.")
                        return
                    }

                    // Direkt die CSV-Import-Option wählen und Datei-Auswahl öffnen
                    importFileType = .csv
                    importManager.selectedFileType = .csv
                    showFileImporter = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3)
                }
                .padding(.trailing, 8)
                .disabled(viewModel.students.count >= 40)

                // Neuer Info-Button für Hilfe
                   Button(action: {
                       showImportHelp = true
                   }) {
                       Image(systemName: "info.circle")
                           .font(.caption)
                           .foregroundColor(.blue)
                   }
               }
               .padding(.trailing, 8)

                // Schüler hinzufügen Button
                Button(action: {
                    showAddStudentModal = true
                }) {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                }
                .padding(.trailing, 8)
                .disabled(viewModel.students.count >= 40)
            }
            .padding()
            .background(Color.white)
            .shadow(radius: 1)

            if viewModel.isLoading {
                Spacer()
                ProgressView("Laden...")
                Spacer()
            } else if viewModel.students.isEmpty {
                emptyStudentListView
            } else {
                // Verbesserte tabellarische Schülerliste
                VStack {
                    // Header-Zeile für die Tabelle
                    HStack {
                        if editMode == .active {
                            Button(action: {
                                if selectedStudents.count == viewModel.students.count {
                                    // Alle abwählen
                                    selectedStudents.removeAll()
                                } else {
                                    // Alle auswählen
                                    selectedStudents = Set(viewModel.students.map { $0.id })
                                }
                            }) {
                                Image(systemName: selectedStudents.count == viewModel.students.count ?
                                        "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedStudents.count > 0 ? .blue : .gray)
                                    .frame(width: 30, alignment: .center)
                            }
                        }

                        Text("Nachname")
                            .font(.headline)
                            .frame(width: 130, alignment: .leading)
                        Text("Vorname")
                            .font(.headline)
                            .frame(width: 130, alignment: .leading)
                        Text("Notizen")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // Schülerliste mit verbessertem Multi-Select
                    List {
                        ForEach(viewModel.students) { student in
                            studentRow(student: student)
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        }
                        .onDelete { indexSet in
                            if editMode == .inactive {
                                for index in indexSet {
                                    let student = viewModel.students[index]
                                    viewModel.deleteStudent(id: student.id)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .environment(\.editMode, $editMode)
                }

                // Multi-Select Aktionsleiste am unteren Bildschirmrand
                if editMode == .active {
                    VStack {
                        Divider()

                        HStack(spacing: 16) {
                            // Löschen-Button
                            Button(action: {
                                if !selectedStudents.isEmpty {
                                    confirmDeleteMultipleStudents = true
                                }
                            }) {
                                VStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 18))
                                    Text("Löschen")
                                        .font(.caption)
                                }
                                .frame(minWidth: 60)
                                .foregroundColor(selectedStudents.isEmpty ? .gray : .red)
                            }
                            .disabled(selectedStudents.isEmpty)

                            // Archivieren-Button
                            Button(action: {
                                archiveSelectedStudents()
                            }) {
                                VStack {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 18))
                                    Text("Archivieren")
                                        .font(.caption)
                                }
                                .frame(minWidth: 60)
                                .foregroundColor(selectedStudents.isEmpty ? .gray : .orange)
                            }
                            .disabled(selectedStudents.isEmpty)

                            // Klasse-wechseln-Button
                            Button(action: {
                                if !selectedStudents.isEmpty {
                                    // Fehlermeldungen zurücksetzen vor dem Öffnen des Modals
                                    viewModel.showError = false
                                    viewModel.errorMessage = nil

                                    // Benachrichtigung senden, dass der Fehler zurückgesetzt werden soll
                                    NotificationCenter.default.post(
                                        name: Notification.Name("ClassSelectionClearError"),
                                        object: nil
                                    )

                                    showClassChangeForSelectedStudents = true
                                }
                            }) {
                                VStack {
                                    Image(systemName: "arrow.right.circle")
                                        .font(.system(size: 18))
                                    Text("Klasse ändern")
                                        .font(.caption)
                                }
                                .frame(minWidth: 60)
                                .foregroundColor(selectedStudents.isEmpty ? .gray : .blue)
                            }
                            .disabled(selectedStudents.isEmpty)

                            Spacer()

                            // Ausgewählte Anzahl anzeigen
                            Text("\(selectedStudents.count) ausgewählt")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)

                            // Beenden-Button
                            Button(action: {
                                editMode = .inactive
                                selectedStudents.removeAll()
                            }) {
                                Text("Beenden")
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                    }
                }
            }
        }


    // Hilfsfunktion für die Anzeige einer Schülerzeile
    private func studentRow(student: Student) -> some View {
        HStack {
            if editMode == .active {
                Button(action: {
                    if selectedStudents.contains(student.id) {
                        selectedStudents.remove(student.id)
                    } else {
                        selectedStudents.insert(student.id)
                    }
                }) {
                    Image(systemName: selectedStudents.contains(student.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedStudents.contains(student.id) ? .blue : .gray)
                        .frame(width: 30, alignment: .center)
                }
            }

            Button(action: {
                if editMode == .inactive {
                    selectedStudent = student
                    showEditStudentModal = true
                } else {
                    if selectedStudents.contains(student.id) {
                        selectedStudents.remove(student.id)
                    } else {
                        selectedStudents.insert(student.id)
                    }
                }
            }) {
                HStack {
                    Text(student.lastName)
                        .frame(width: 130, alignment: .leading)
                    Text(student.firstName)
                        .frame(width: 130, alignment: .leading)
                    if let notes = student.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            .contentShape(Rectangle()) // Macht den gesamten Bereich anklickbar
            .background(selectedStudents.contains(student.id) ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
    }

    private var emptyStudentListView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            Text("Keine Schüler in dieser Klasse")
                .font(.headline)

            Text("Tippen Sie auf einen der Buttons, um Schüler hinzuzufügen.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Verbesserte Buttons
            HStack(spacing: 20) {
                Button(action: {
                    showAddStudentModal = true
                }) {
                    VStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 24))
                            .padding(.bottom, 4)
                        Text("Einzeln hinzufügen")
                            .font(.caption)
                    }
                    .frame(width: 150)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    showImportSheet = true
                }) {
                    VStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 24))
                            .padding(.bottom, 4)
                        Text("Aus Datei importieren")
                            .font(.caption)
                    }
                    .frame(width: 150)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // Funktion zum Archivieren ausgewählter Schüler
    private func archiveSelectedStudents() {
        guard !selectedStudents.isEmpty else { return }

        // In einer vollständigen Implementierung würde hier ein Alert für die Bestätigung angezeigt

        for studentId in selectedStudents {
            if let student = viewModel.dataStore.getStudent(id: studentId) {
                viewModel.archiveStudent(student)
            }
        }

        // Zurücksetzen nach Archivierung
        selectedStudents.removeAll()
        editMode = .inactive
    }
}
