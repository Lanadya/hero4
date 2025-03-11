import SwiftUI

struct StudentsListView: View {
    @StateObject private var viewModel = StudentsViewModel()
    @State private var showAddStudentModal = false
    @State private var showEditStudentModal = false
    @State private var selectedStudent: Student?
    @State private var navigateToSeatingPlan = false
    @State private var showImportSheet = false

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
                leading: Button(action: {
                    showImportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .disabled(viewModel.selectedClassId == nil),

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
            .actionSheet(isPresented: $showImportSheet) {
                ActionSheet(
                    title: Text("Schülerliste importieren"),
                    message: Text("Wählen Sie das Format aus"),
                    buttons: [
                        .default(Text("CSV-Datei importieren")) {
                            // CSV-Import (wird später implementiert)
                            showImportPlaceholder()
                        },
                        .default(Text("Excel-Datei importieren")) {
                            // Excel-Import (wird später implementiert)
                            showImportPlaceholder()
                        },
                        .cancel()
                    ]
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Bei Erscheinen der View die Daten aktualisieren
            viewModel.loadStudentsForSelectedClass()
        }
    }

    // Zeigt einen Platzhalter für den Import an
    private func showImportPlaceholder() {
        viewModel.showError(message: "Import-Funktion wird in einer zukünftigen Version verfügbar sein.")
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

            NavigationLink(destination: ClassesView()) {
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
            // Header mit Klassenname und Suchfeld
            VStack(spacing: 0) {
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

                // Suchfeld
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Schüler in dieser Klasse suchen", text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.updateSearchText($0) }
                    ))

                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.clearSearch()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color.white)
            .shadow(radius: 1)

            if viewModel.isLoading {
                Spacer()
                ProgressView("Laden...")
                Spacer()
            } else if viewModel.students.isEmpty {
                emptyStudentListView
            } else {
                // Schülerliste
                List {
                    ForEach(viewModel.students) { student in
                        Button(action: {
                            selectedStudent = student
                            showEditStudentModal = true
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(student.fullName)
                                        .font(.headline)

                                    if let notes = student.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let student = viewModel.students[index]
                            viewModel.deleteStudent(id: student.id)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
    }

    private var emptyStudentListView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            if viewModel.searchText.isEmpty {
                Text("Keine Schüler in dieser Klasse")
                    .font(.headline)

                Text("Tippen Sie auf das + Symbol, um Schüler hinzuzufügen.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: {
                    showAddStudentModal = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Schüler hinzufügen")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                Text("Keine Suchergebnisse")
                    .font(.headline)

                Text("Es wurden keine Schüler gefunden, die \"\(viewModel.searchText)\" enthalten.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: {
                    viewModel.clearSearch()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Suche zurücksetzen")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }

            Spacer()
        }
    }
}
