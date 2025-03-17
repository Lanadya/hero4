import SwiftUI
import UniformTypeIdentifiers

struct StudentsListView: View {
    // Initialen Parameter für die Klassenauswahl hinzufügen
    @StateObject private var viewModel: StudentsViewModel
    @State private var showAddStudentModal = false
    @State private var showEditStudentModal = false
    @State private var selectedStudent: Student?
    @State private var navigateToSeatingPlan = false
    @State private var showImportSheet = false

    // Für Multi-Select und Löschen
    @State private var editMode: EditMode = .inactive
    @State private var selectedStudents = Set<UUID>()
    @State private var confirmDeleteMultipleStudents = false

    // Für den Datei-Import
    @State private var showFileImporter = false
    @State private var importFileType: FileImportType = .csv
    @State private var showColumnMappingView = false
    @State private var refreshStudentList = false
    @StateObject private var importManager: ImportManager

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
            .navigationBarTitle("Schülerverwaltung", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: {
                    if viewModel.selectedClassId != nil {
                        navigateToSeatingPlan = true
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.grid.2x2")
                        Text("Zum Sitzplan")
                    }
                }
                .disabled(viewModel.selectedClassId == nil)
            )
            .toolbar {
                // Edit-Button für die Schülerliste
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.selectedClass != nil && !viewModel.students.isEmpty {
                        EditButton()
                            .padding(.trailing, 8)
                    }
                }

                // Bottom-Toolbar für Löschen-Aktion
                ToolbarItem(placement: .bottomBar) {
                    if editMode == .active && !selectedStudents.isEmpty {
                        HStack {
                            Button(action: {
                                // Bestätigungsdialog anzeigen
                                confirmDeleteMultipleStudents = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("\(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") löschen")
                                }
                            }
                            .foregroundColor(.red)

                            Spacer()

                            Button(action: {
                                // Bearbeitungsmodus verlassen
                                editMode = .inactive
                                selectedStudents.removeAll()
                            }) {
                                Text("Fertig")
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(
                NavigationLink(
                    destination: Text("Sitzplan (kommt bald)"),
                    isActive: $navigateToSeatingPlan
                ) { EmptyView() }
            )
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
                }
            }
            .sheet(isPresented: $showEditStudentModal) {
                if let student = selectedStudent {
                    EditStudentView(
                        student: student,
                        viewModel: viewModel,
                        isPresented: $showEditStudentModal
                    )
                }
            }
            .sheet(isPresented: $showColumnMappingView) {
                ColumnMappingView(
                    importManager: importManager,
                    isPresented: $showColumnMappingView,
                    refreshStudents: $refreshStudentList
                )
            }
            .actionSheet(isPresented: $showImportSheet) {
                ActionSheet(
                    title: Text("Schülerliste importieren"),
                    message: Text("Wählen Sie das Format der zu importierenden Datei"),
                    buttons: [
                        .default(Text("CSV-Datei (.csv)")) {
                            importFileType = .csv
                            importManager.selectedFileType = .csv
                            showFileImporter = true
                        },
                        .default(Text("Excel-Datei (.xlsx)")) {
                            importFileType = .excel
                            importManager.selectedFileType = .excel
                            showFileImporter = true
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
                do {
                    guard let selectedFile = try result.get().first else { return }

                    // Starte den Import-Prozess
                    importManager.processSelectedFile(selectedFile)

                    // Zeige die Mapping-Ansicht
                    showColumnMappingView = true

                } catch {
                    viewModel.showError(message: "Fehler beim Auswählen der Datei: \(error.localizedDescription)")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Bei Erscheinen der View die Daten aktualisieren
            viewModel.loadStudentsForSelectedClass()

            // Aktualisiere die ausgewählte Klassen-ID im ImportManager
            if let classId = viewModel.selectedClassId {
                importManager.selectedClassId = classId
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
            // Header mit Klassenname
            HStack {
                Text("Klasse: \(classItem.name)")
                    .font(.headline)

                if let note = classItem.note, !note.isEmpty {
                    Text("(\(note))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Anzeige der Schüleranzahl mit Limit
                Text("\(viewModel.students.count)/40 Schüler")
                    .font(.caption)
                    .foregroundColor(viewModel.students.count >= 40 ? .red : .gray)
                    .padding(.trailing, 8)

                // Import-Button neben dem Plus-Button
                Button(action: {
                    showImportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3)
                }
                .padding(.trailing, 8)
                .disabled(viewModel.students.count >= 40)

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
                List {
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
                    .background(Color(.systemGray6))
                    .listRowInsets(EdgeInsets())

                    // Schülerzeilen mit Multi-Select
                    ForEach(viewModel.students) { student in
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
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let student = viewModel.students[index]
                            viewModel.deleteStudent(id: student.id)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.editMode, $editMode)
            }
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
}
