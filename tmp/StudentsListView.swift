import Foundation
import SwiftUI
import UniformTypeIdentifiers

import Features.Common.Components

// Main StudentsListView with modifications to support the new action bar
struct StudentsListView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var viewModel: StudentsViewModel
    @State private var showAddStudentModal = false
    @State private var showEditStudentModal = false
    @State private var selectedStudent: Student?
    @State private var navigateToSeatingPlan = false
    @State private var showImportSheet = false
    @State private var showClassChangeForSelectedStudents = false
    @State private var showClassChangeAfterEdit: UUID? = nil

    // For multi-select and deletion
    @State private var editMode: EditMode = .inactive
    @State private var selectedStudents = Set<UUID>()
    @State private var activeAlert: AlertType? = nil
    @State private var showMultiSelectOperations = false
    @State private var showClassChangeModal = false

    // For file import
    @State private var showFileImporter = false
    @State private var importFileType: FileImportType = .csv
    @State private var showColumnMappingView = false
    @State private var refreshStudentList = false
    @StateObject private var importManager: ImportManager
    @State private var showImportHelp = false

    // For TabView integration
    @Binding var selectedTab: Int

    // Constructor with option to pass an initial class ID and TabView integration
    init(initialClassId: UUID? = nil, selectedTab: Binding<Int> = .constant(1)) {
        _viewModel = StateObject(wrappedValue: StudentsViewModel(initialClassId: initialClassId))
        _selectedTab = selectedTab
        _importManager = StateObject(wrappedValue: ImportManager(classId: initialClassId ?? UUID()))
    }

    // Add this function here, after your property declarations but before the body
    func selectStudentForDetail(_ student: Student) {
        print("DEBUG: Student selected for detail: \(student.fullName) (ID: \(student.id))")

        // Force refresh student data before showing the modal
        if let refreshedStudent = viewModel.dataStore.getStudent(id: student.id) {
            selectedStudent = refreshedStudent
            print("DEBUG: Student data refreshed for detail view")
        } else {
            selectedStudent = student
            print("DEBUG: Using original student data for detail view")
        }

        // Add a small delay to ensure the UI has time to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showEditStudentModal = true
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.classes.isEmpty {
                    // No classes available
                    StudentsNoClassesView(selectedTab: $selectedTab)
                } else {
                    // Split-View for iPad
                    HStack(spacing: 0) {
                        // Left side: Class list and global search
                        StudentsSidebarView(
                                viewModel: viewModel,
                                selectedStudent: $selectedStudent,
                                showEditStudentModal: $showEditStudentModal
                            )
                            .frame(width: 250)
                            .background(Color(.systemGroupedBackground))

                        // Right side: Student list or selected details
                        if viewModel.selectedClass != nil {
                            StudentsContentView(
                                viewModel: viewModel,
                                selectedStudents: $selectedStudents,
                                editMode: $editMode,
                                selectedStudent: $selectedStudent,
                                showEditStudentModal: $showEditStudentModal,
                                showAddStudentModal: $showAddStudentModal,
                                showImportSheet: $showImportSheet,
                                showImportHelp: $showImportHelp,
                                showClassChangeForSelectedStudents: $showClassChangeForSelectedStudents,
                                activeAlert: $activeAlert,
                                showMultiSelectOperations: $showMultiSelectOperations
                            )
                        } else {
                            StudentsSelectionPromptView()
                        }
                    }
                }
            }
            .sheet(isPresented: $showClassChangeForSelectedStudents) {
                MultiStudentClassChangeSheet(
                    viewModel: viewModel,
                    selectedStudents: $selectedStudents,
                    editMode: $editMode,
                    isPresented: $showClassChangeForSelectedStudents
                )
            }
            .navigationBarTitle("Schülerverwaltung", displayMode: .inline)
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
                    print("DEBUG: Opening EditStudentModal for \(student.fullName)")
                    EditStudentView(
                        student: student,
                        viewModel: viewModel,
                        isPresented: $showEditStudentModal
                    )
                    .onAppear {
                        print("DEBUG: EditStudentView appeared for \(student.fullName)")
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                } else {
                    // Fallback view if no student is selected
                    VStack {
                        Text("Fehler: Kein Schüler ausgewählt")
                            .foregroundColor(.red)
                            .padding()

                        Button("Schließen") {
                            showEditStudentModal = false
                        }
                        .padding()
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showClassChangeModal) {
                if let student = selectedStudent {
                    ClassChangeView(
                        student: student,
                        viewModel: viewModel,
                        isPresented: $showClassChangeModal
                    )
                    .presentationDetents([.large])
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
                            importFileType = .csv
                            importManager.selectedFileType = .csv
                            showFileImporter = true
                        },
                        .cancel(Text("Abbrechen"))
                    ]
                )
            }
            .sheet(isPresented: $showMultiSelectOperations) {
                StudentMultiSelectOperationsView(
                    viewModel: viewModel,
                    selectedStudents: $selectedStudents,
                    editMode: $editMode,
                    isPresented: $showMultiSelectOperations,
                    showClassChangeView: $showClassChangeForSelectedStudents
                )
            }

            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: importFileType.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedFile = try result.get().first else { return }
                    importManager.processSelectedFile(selectedFile)
                    showColumnMappingView = true
                } catch {
                    viewModel.showError(message: "Fehler beim Auswählen der Datei: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $showImportHelp) {
                StudentsImportHelpSheet(isPresented: $showImportHelp)
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(viewModel.errorMessage ?? "Unbekannter Fehler"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .delete:
                    return Alert(
                        title: Text("Schüler löschen"),
                        message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") löschen?"),
                        primaryButton: .destructive(Text("Löschen")) {
                            viewModel.deleteMultipleStudentsWithStatus(studentIds: Array(selectedStudents))
                        },
                        secondaryButton: .cancel()
                    )
                case .archive:
                    return Alert(
                        title: Text("Schüler archivieren"),
                        message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") archivieren?"),
                        primaryButton: .default(Text("Archivieren")) {
                            viewModel.archiveMultipleStudentsWithStatus(studentIds: Array(selectedStudents))
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadStudentsForSelectedClass()

            if let classIdString = UserDefaults.standard.string(forKey: "selectedClassForStudentsList"),
               let classId = UUID(uuidString: classIdString) {
                viewModel.selectClass(id: classId)
                UserDefaults.standard.removeObject(forKey: "selectedClassForStudentsList")
            }

            // Setup notification for ClassChangeView
            NotificationCenter.default.addObserver(
                forName: Notification.Name("OpenClassChangeView"),
                object: nil,
                queue: .main
            ) { notification in
                if let studentIdString = notification.userInfo?["studentId"] as? String,
                   let studentId = UUID(uuidString: studentIdString),
                   let student = viewModel.dataStore.getStudent(id: studentId) {
                    selectedStudent = student
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showClassChangeModal = true
                    }
                }
            }
        }
        .onDisappear {
            viewModel.clearGlobalSearch()
            editMode = .inactive
            selectedStudents.removeAll()

            NotificationCenter.default.removeObserver(
                self,
                name: Notification.Name("OpenClassChangeView"),
                object: nil
            )
        }
    }

}


// MARK: - Subviews
struct StudentsNoClassesView: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

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
}

struct StudentsSidebarView: View {
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var selectedStudent: Student?
    @Binding var showEditStudentModal: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Globale Suche
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

                // Suchergebnisse
                if !viewModel.searchResults.isEmpty {
                    StudentsSearchResultsView(
                        viewModel: viewModel,
                        selectedStudent: $selectedStudent,
                        showEditStudentModal: $showEditStudentModal
                    )
                }

                Divider()
                    .padding(.vertical, 8)
            }

            // Klassenliste
            StudentsClassesListView(viewModel: viewModel)
        }
    }
}

struct StudentsSearchResultsView: View {
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var selectedStudent: Student?
    @Binding var showEditStudentModal: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Kopfzeile mit Anzahl der Ergebnisse
            HStack {
                Text("\(viewModel.searchResults.count) Ergebnisse")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if viewModel.searchResults.count > 2 {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("scrollen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Scrollbare Ergebnisliste
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.searchResults) { result in
                        Button(action: {
                            viewModel.selectClass(id: result.student.classId)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                selectStudentForDetail(result.student)
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
            .frame(height: min(CGFloat(viewModel.searchResults.count * 70), 150))
        }
    }
}

struct StudentsClassesListView: View {
    @ObservedObject var viewModel: StudentsViewModel

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Klassen")
                    .font(.headline)

                Spacer()

                if viewModel.classes.count > 5 {
                    Text("scrollen")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            CompactClassListView(
                classes: viewModel.classes,
                selectedClassId: viewModel.selectedClassId,
                onClassSelected: { classId in
                    viewModel.selectClass(id: classId)
                }
            )
            .frame(maxHeight: .infinity)
        }
    }
}

struct StudentsSelectionPromptView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Bitte wählen Sie eine Klasse aus der linken Seitenleiste")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct StudentsContentView: View {
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var selectedStudents: Set<UUID>
    @Binding var editMode: EditMode
    @Binding var selectedStudent: Student?
    @Binding var showEditStudentModal: Bool
    @Binding var showAddStudentModal: Bool
    @Binding var showImportSheet: Bool
    @Binding var showImportHelp: Bool
    @Binding var showClassChangeForSelectedStudents: Bool
    @Binding var activeAlert: AlertType?
    @Binding var showMultiSelectOperations: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let classItem = viewModel.selectedClass {
                // Header with class info and controls
                StudentsClassHeaderView(
                    classItem: classItem,
                    viewModel: viewModel,
                    editMode: $editMode,
                    selectedStudents: $selectedStudents,
                    showAddStudentModal: $showAddStudentModal,
                    showImportSheet: $showImportSheet,
                    showImportHelp: $showImportHelp
                )

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Laden...")
                    Spacer()
                } else if viewModel.students.isEmpty {
                    StudentsEmptyView(
                        showAddStudentModal: $showAddStudentModal,
                        showImportSheet: $showImportSheet
                    )
                } else {
                    // This is the key change - define a simple callback to handle class change
                    StudentsListContent(
                        viewModel: viewModel,
                        selectedStudents: $selectedStudents,
                        editMode: $editMode,
                        selectedStudent: $selectedStudent,
                        showEditStudentModal: $showEditStudentModal,
                        showClassChangeForSelectedStudents: $showClassChangeForSelectedStudents,
                        activeAlert: $activeAlert,
                        showMultiSelectOperations: $showMultiSelectOperations
                    )
                }
            } else {
                Text("Keine Klasse ausgewählt")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

struct StudentsClassHeaderView: View {
    let classItem: Class
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var editMode: EditMode
    @Binding var selectedStudents: Set<UUID>
    @Binding var showAddStudentModal: Bool
    @Binding var showImportSheet: Bool
    @Binding var showImportHelp: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // LINKE SEITE: Klasseninformationsblock
            VStack(alignment: .leading, spacing: 4) {
                // Klassenname
                Text("Klasse: \(classItem.name)")
                    .font(.headline)
                    .lineLimit(1)

                // Notiz (falls vorhanden)
                if let note = classItem.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                // Schüleranzahl
                Text("\(viewModel.students.count) Schüler")
                    .font(.caption)
                    .foregroundColor(viewModel.students.count >= 40 ? .red : .gray)
            }
            .frame(width: 180, alignment: .leading)

            Spacer()

            // RECHTE SEITE: Aktionsbuttons
            HStack(spacing: 10) {
                // Auswählen-Button
                if !viewModel.students.isEmpty {
                    Button(action: {
                        editMode = editMode.isEditing ? .inactive : .active
                        print("DEBUG: EditMode geändert zu \(editMode)")
                        if editMode == .inactive {
                            selectedStudents.removeAll()
                        }
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: editMode.isEditing ? "checkmark.circle" : "person.2.fill")
                                .font(.system(size: 16))
                            Text(editMode.isEditing ? "Auswahl beenden" : "Auswählen")
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 80, height: 50)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                    }
                }

                // Hinzufügen-Button
                Button(action: {
                    showAddStudentModal = true
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                        Text("Hinzufügen")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(width: 80, height: 50)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(8)
                }
                .disabled(viewModel.students.count >= 40)

                // Import-Button mit Info-Symbol
                HStack(alignment: .top, spacing: 2) {
                    Button(action: {
                        let currentStudentCount = viewModel.getStudentCountForClass(classId: viewModel.selectedClassId ?? UUID())
                        if currentStudentCount >= 40 {
                            viewModel.showError(message: "Diese Klasse hat bereits 40 Schüler. Es können keine weiteren Schüler hinzugefügt werden.")
                            return
                        }

                        showImportSheet = true
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16))
                            Text("Importieren")
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 80, height: 50)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.students.count >= 40)

                    Button(action: {
                        showImportHelp = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(radius: 1)
    }
}

struct StudentsEmptyView: View {
    @Binding var showAddStudentModal: Bool
    @Binding var showImportSheet: Bool

    var body: some View {
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

struct StudentsListHeader: View {
    let editMode: EditMode
    @Binding var selectedStudents: Set<UUID>
    let students: [Student]

    var body: some View {
        HStack {
            if editMode == .active {
                // In edit mode, show selection controls
                Button(action: {
                    if selectedStudents.count == students.count {
                        selectedStudents.removeAll()
                    } else {
                        selectedStudents = Set(students.map { $0.id })
                    }
                }) {
                    Text(selectedStudents.count == students.count ? "Deselect All" : "Select All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }

                Spacer()

                Text("\(selectedStudents.count) selected")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                // In normal mode, show column headers
                Text("Name")
                    .font(.headline)
                    .padding(.leading, 8)

                Spacer()
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct StudentsListContent: View {
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var selectedStudents: Set<UUID>
    @Binding var editMode: EditMode
    @Binding var selectedStudent: Student?
    @Binding var showEditStudentModal: Bool
    @Binding var showClassChangeForSelectedStudents: Bool
    @Binding var activeAlert: AlertType?
    @Binding var showMultiSelectOperations: Bool

    // State for tracking operation progress
    @State private var isProcessingOperation = false

    var body: some View {
        VStack(spacing: 0) {
            // Table header
            StudentsListHeader(editMode: editMode, selectedStudents: $selectedStudents, students: viewModel.students)

            // Student list
            List {
                ForEach(viewModel.students) { student in
                    StudentsRow(
                        student: student,
                        isSelected: selectedStudents.contains(student.id),
                        editMode: editMode,
                        onSelect: {
                            if editMode == .inactive {
                                selectedStudent = student
                                showEditStudentModal = true
                            } else {
                                if selectedStudents.contains(student.id) {
                                    selectedStudents.remove(student.id)
                                } else {
                                    selectedStudents.insert(student.id)
                                }
                                print("DEBUG: selectedStudents aktualisiert: \(selectedStudents.count) Schüler ausgewählt")
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .disabled(isProcessingOperation)
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
            .opacity(isProcessingOperation ? 0.7 : 1.0)

            // Multi-select action bar with DIRECT alert handling
            if editMode == .active {
                MultiSelectActionBar(
                    selectedStudents: $selectedStudents,
                    showClassChangeForSelectedStudents: $showClassChangeForSelectedStudents,
                    editMode: $editMode,
                    onDeleteTapped: {
                        print("DEBUG: Delete tapped in parent view")
                        activeAlert = .delete
                    },
                    onArchiveTapped: {
                        print("DEBUG: Archive tapped in parent view")
                        activeAlert = .archive
                    },
                    viewModel: viewModel
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StudentOperationCompleted"))) { _ in
            print("DEBUG StudentsListContent: Received StudentOperationCompleted")
            isProcessingOperation = false

            if !viewModel.showError {
                selectedStudents.removeAll()
                editMode = .inactive
            }
        }
    }
}

// IMPORTANT: These view structs are now at the file level, not nested inside other structs

struct StudentsImportHelpSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer().frame(height: 12)

            HStack {
                Text("CSV-Import Hilfe")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding(.bottom, 12)

            Text("So erstellen Sie eine CSV-Datei für den Import:")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.bottom, 4)

            Group {
                Text("1. Öffnen Sie Excel oder ein Tabellenkalkulationsprogramm")
                Text("2. Erstellen Sie diese Spalten: Vorname, Nachname, Notizen (optional)")
                Text("3. Speichern Sie die Datei als .csv-Datei")
            }
            .font(.callout)
            .foregroundColor(.primary)

            Divider()
                .padding(.vertical, 8)

            Text("Hinweise:")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.bottom, 2)

            Group {
                Text("• Die erste Zeile muss Spaltenüberschriften enthalten")
                Text("• Es können maximal 40 Schüler pro Klasse importiert werden")
                Text("• Schüler mit identischen Namen werden übersprungen")
            }
            .font(.callout)
            .foregroundColor(.secondary)

            Spacer().frame(height: 20)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}

struct MultiStudentClassChangeSheet: View {
    @ObservedObject var viewModel: StudentsViewModel
    @Binding var selectedStudents: Set<UUID>
    @Binding var editMode: EditMode
    @Binding var isPresented: Bool
    @State private var errorMessage: String? = nil
    @State private var selectedClassId: UUID? = nil
    @State private var showConfirmation = false

    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
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
                onClassSelected: { newClassId in
                    // Prüfe potenzielle Fehler vor der eigentlichen Verschiebung
                    if let error = viewModel.validateMoveStudents(studentIds: Array(selectedStudents), toClassId: newClassId) {
                        errorMessage = error
                        return
                    }

                    // Speichere die ausgewählte Klassen-ID und zeige die Bestätigung an
                    selectedClassId = newClassId
                    showConfirmation = true
                },
                onCancel: {
                    selectedStudents.removeAll()
                    editMode = .inactive
                    isPresented = false
                }
            )
        }
        .alert(isPresented: $showConfirmation) {
            Alert(
                title: Text("Schüler verschieben"),
                message: Text("Möchten Sie wirklich \(selectedStudents.count) \(selectedStudents.count == 1 ? "Schüler" : "Schüler") in eine andere Klasse verschieben? Bisherige Bewertungen der Schüler werden dabei archiviert."),
                primaryButton: .default(Text("Verschieben")) {
                    if let targetClassId = selectedClassId {
                        // Wenn keine Fehler, verschiebe alle ausgewählten Schüler
                        for studentId in selectedStudents {
                            viewModel.moveStudentToClassWithStatus(studentId: studentId, newClassId: targetClassId)
                        }

                        // Aktualisiere UI und setze Zustände zurück
                        selectedStudents.removeAll()
                        editMode = .inactive
                        isPresented = false
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClassSelectionError"))) { notification in
            if let message = notification.userInfo?["message"] as? String {
                errorMessage = message
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClassSelectionClearError"))) { _ in
            errorMessage = nil
        }
    }
}
