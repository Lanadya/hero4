import SwiftUI

struct ArchiveView: View {
    @State private var selectedSection = 0
    @State private var showBackupSuccessAlert = false
    @State private var showRestoreSuccessAlert = false
    @State private var showRestoreFailedAlert = false
    @State private var showRestoreConfirmation = false
    @State private var selectedBackupURL: URL? = nil
    @State private var availableBackups: [URL] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment control für Abschnitte
                Picker("Bereich", selection: $selectedSection) {
                    Text("Archivierte Inhalte").tag(0)
                    Text("Datensicherung").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Inhalt basierend auf ausgewähltem Abschnitt
                if selectedSection == 0 {
                    ArchivedContentView()
                } else {
                    BackupRestoreView(
                        backups: $availableBackups,
                        onCreateBackup: createBackup,
                        onSelectBackup: { url in
                            selectedBackupURL = url
                            showRestoreConfirmation = true
                        },
                        onDeleteBackup: deleteBackup
                    )
                }
            }
            .navigationBarTitle("Archiv & Sicherung", displayMode: .inline)
            .onAppear {
                loadBackups()
            }
            .alert(isPresented: $showBackupSuccessAlert) {
                Alert(
                    title: Text("Backup erstellt"),
                    message: Text("Das Backup wurde erfolgreich erstellt."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showRestoreConfirmation) {
                Alert(
                    title: Text("Backup wiederherstellen"),
                    message: Text("Möchten Sie wirklich das ausgewählte Backup wiederherstellen? Alle aktuellen Daten werden durch die gesicherten Daten ersetzt."),
                    primaryButton: .destructive(Text("Wiederherstellen")) {
                        if let url = selectedBackupURL {
                            restoreBackup(from: url)
                        }
                    },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            }
            .alert(isPresented: $showRestoreSuccessAlert) {
                Alert(
                    title: Text("Wiederherstellung erfolgreich"),
                    message: Text("Das Backup wurde erfolgreich wiederhergestellt."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showRestoreFailedAlert) {
                Alert(
                    title: Text("Fehler bei der Wiederherstellung"),
                    message: Text("Das Backup konnte nicht wiederhergestellt werden. Bitte versuchen Sie es erneut."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func loadBackups() {
        availableBackups = DataStore.shared.getAvailableBackups()
    }

    private func createBackup() {
        if DataStore.shared.createBackup() != nil {
            loadBackups() // Liste aktualisieren
            showBackupSuccessAlert = true
        }
    }

    private func restoreBackup(from url: URL) {
        let success = DataStore.shared.restoreFromBackup(url: url)
        if success {
            showRestoreSuccessAlert = true
            // Daten neu laden
            DataStore.shared.loadAllData()
        } else {
            showRestoreFailedAlert = true
        }
    }

    private func deleteBackup(_ url: URL) {
        if DataStore.shared.deleteBackup(url: url) {
            loadBackups() // Liste aktualisieren
        }
    }
}

// Ansicht für archivierte Inhalte
struct ArchivedContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            // Tabs für verschiedene archivierte Inhaltstypen
            Picker("Archivtyp", selection: $selectedTab) {
                Text("Klassen").tag(0)
                Text("Schüler").tag(1)
                Text("Bewertungen").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Inhalt basierend auf ausgewähltem Tab
            TabView(selection: $selectedTab) {
                ArchivedClassesView().tag(0)
                ArchivedStudentsView().tag(1)
                ArchivedRatingsView().tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

// Platzhalter-Ansichten für archivierte Inhalte
struct ArchivedClassesView: View {
    @State private var archivedClasses: [Class] = []

    var body: some View {
        List {
            if archivedClasses.isEmpty {
                Text("Keine archivierten Klassen")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(archivedClasses) { classObj in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(classObj.name)
                                .font(.headline)
                            if let note = classObj.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Button(action: {
                            restoreClass(classObj)
                        }) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteArchivedClasses)
            }
        }
        .onAppear {
            loadArchivedClasses()
        }
    }

    private func loadArchivedClasses() {
        // Lade archivierte Klassen
        archivedClasses = DataStore.shared.classes.filter { $0.isArchived }
    }

    private func restoreClass(_ classObj: Class) {
        var updatedClass = classObj
        updatedClass.isArchived = false
        DataStore.shared.updateClass(updatedClass)
        loadArchivedClasses()
    }

    private func deleteArchivedClasses(at offsets: IndexSet) {
        for index in offsets {
            let classObj = archivedClasses[index]
            DataStore.shared.deleteClass(id: classObj.id)
        }
        loadArchivedClasses()
    }
}

struct ArchivedStudentsView: View {
    @State private var archivedStudents: [Student] = []

    var body: some View {
        List {
            if archivedStudents.isEmpty {
                Text("Keine archivierten Schüler")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(archivedStudents) { student in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(student.fullName)
                                .font(.headline)

                            if let className = getClassName(for: student) {
                                Text("Klasse: \(className)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Button(action: {
                            restoreStudent(student)
                        }) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteArchivedStudents)
            }
        }
        .onAppear {
            loadArchivedStudents()
        }
    }

    private func loadArchivedStudents() {
        // Lade archivierte Schüler
        archivedStudents = DataStore.shared.students.filter { $0.isArchived }
    }

    private func getClassName(for student: Student) -> String? {
        if let classObj = DataStore.shared.getClass(id: student.classId) {
            return classObj.name
        }
        return nil
    }

    private func restoreStudent(_ student: Student) {
        var updatedStudent = student
        updatedStudent.isArchived = false
        let success = DataStore.shared.updateStudent(updatedStudent)
        if success {
            loadArchivedStudents()
        }
    }

    private func deleteArchivedStudents(at offsets: IndexSet) {
        for index in offsets {
            let student = archivedStudents[index]
            let success = DataStore.shared.deleteStudent(id: student.id)
            if !success {
                print("Failed to delete student: \(student.fullName)")
            }
        }
        loadArchivedStudents()
    }
}

struct ArchivedRatingsView: View {
    @State private var archivedRatings: [Rating] = []

    var body: some View {
        List {
            if archivedRatings.isEmpty {
                Text("Keine archivierten Bewertungen")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(archivedRatings) { rating in
                    HStack {
                        VStack(alignment: .leading) {
                            if let student = getStudent(for: rating) {
                                Text(student.fullName)
                                    .font(.headline)
                            } else {
                                Text("Unbekannter Schüler")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }

                            Text("Datum: \(formatDate(rating.date))")
                                .font(.caption)
                                .foregroundColor(.gray)

                            if let ratingValue = rating.value {
                                Text("Bewertung: \(ratingValue.stringValue)")
                                    .font(.subheadline)
                            }
                        }

                        Spacer()

                        Button(action: {
                            restoreRating(rating)
                        }) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteArchivedRatings)
            }
        }
        .onAppear {
            loadArchivedRatings()
        }
    }

    private func loadArchivedRatings() {
        // Lade archivierte Bewertungen
        archivedRatings = DataStore.shared.ratings.filter { $0.isArchived }
    }

    private func getStudent(for rating: Rating) -> Student? {
        return DataStore.shared.getStudent(id: rating.studentId)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func restoreRating(_ rating: Rating) {
        var updatedRating = rating
        updatedRating.isArchived = false
        DataStore.shared.updateRating(updatedRating)
        loadArchivedRatings()
    }

    private func deleteArchivedRatings(at offsets: IndexSet) {
        for index in offsets {
            let rating = archivedRatings[index]
            DataStore.shared.deleteRating(id: rating.id)
        }
        loadArchivedRatings()
    }
}

// Ansicht für Backup und Restore
struct BackupRestoreView: View {
    @Binding var backups: [URL]
    let onCreateBackup: () -> Void
    let onSelectBackup: (URL) -> Void
    let onDeleteBackup: (URL) -> Void

    var body: some View {
        VStack {
            // Backup-Button
            Button(action: onCreateBackup) {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text("Backup erstellen")
                            .font(.headline)
                        Text("Speichert alle Daten für die spätere Wiederherstellung")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top)

            // Liste der verfügbaren Backups
            VStack(alignment: .leading) {
                Text("Verfügbare Backups")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if backups.isEmpty {
                    VStack {
                        Spacer()
                        Text("Keine Backups vorhanden")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(height: 200)
                } else {
                    List {
                        ForEach(backups, id: \.absoluteString) { backup in
                            BackupListItem(
                                backup: backup,
                                onSelect: onSelectBackup,
                                onDelete: onDeleteBackup
                            )
                        }
                    }
                }
            }
            .padding(.bottom)

            Spacer()
        }
    }
}

// Einzelne Backup-Listenelement
struct BackupListItem: View {
    let backup: URL
    let onSelect: (URL) -> Void
    let onDelete: (URL) -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            Button(action: {
                onSelect(backup)
            }) {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading) {
                        Text(getDisplayDate())
                            .font(.headline)
                        Text(getBackupSize())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }

            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Backup löschen"),
                message: Text("Sind Sie sicher, dass Sie dieses Backup löschen möchten?"),
                primaryButton: .destructive(Text("Löschen")) {
                    onDelete(backup)
                },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
    }

    private func getDisplayDate() -> String {
        // Extrahiere Datum aus Dateinamen "gradeHero_backup_2025-03-26_14-30-45.sqlite"
        let filename = backup.lastPathComponent
        if let range = filename.range(of: "gradeHero_backup_"),
           let endRange = filename.range(of: ".sqlite") {
            let dateString = String(filename[range.upperBound..<endRange.lowerBound])
            let formattedDate = dateString
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: ":")
            return formattedDate
        }
        return "Backup vom unbekannten Datum"
    }

    private func getBackupSize() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: backup.path)
            if let size = attributes[.size] as? NSNumber {
                let byteCountFormatter = ByteCountFormatter()
                byteCountFormatter.allowedUnits = [.useMB, .useKB]
                byteCountFormatter.countStyle = .file
                return byteCountFormatter.string(fromByteCount: size.int64Value)
            }
        } catch {
            print("Fehler beim Lesen der Dateigröße: \(error)")
        }
        return "Unbekannte Größe"
    }
}
