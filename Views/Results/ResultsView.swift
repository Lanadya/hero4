import SwiftUI

struct ResultsView: View {
    @StateObject private var viewModel = ResultsViewModel()
    @State private var searchText = ""
    @State private var showClassPicker = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView

                if viewModel.selectedClass == nil {
                    classSelectionPrompt
                } else if viewModel.isLoading {
                    ProgressView("Lade Bewertungen...")
                } else if viewModel.students.isEmpty {
                    emptyStudentsView
                } else {
                    ratingsTableView
                }
            }
            .navigationBarTitle("Bewertungen", displayMode: .inline)
            .navigationBarItems(trailing: exportButton)
            .sheet(isPresented: $showClassPicker) {
                ClassPickerView(viewModel: viewModel)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Komponenten

    private var headerView: some View {
        HStack {
            // Klassenauswahl
            Button(action: {
                showClassPicker = true
            }) {
                HStack {
                    if let className = viewModel.selectedClass?.name {
                        Text(className)
                            .fontWeight(.medium)
                        if let note = viewModel.selectedClass?.note, !note.isEmpty {
                            Text("(\(note))").font(.caption).foregroundColor(.gray)
                        }
                    } else {
                        Text("Klasse wählen")
                    }
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            Spacer()

            // Suchfeld
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Schüler suchen", text: $searchText)
                    .onChange(of: searchText) { _ in
                        viewModel.filterStudents(searchText)
                    }
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .frame(width: 220)
        }
        .padding()
        .background(Color.white)
        .shadow(radius: 1)
    }

    // Klassenauswahl-Aufforderung
    private var classSelectionPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Bitte wählen Sie eine Klasse")
                .font(.headline)
            Button(action: { showClassPicker = true }) {
                Text("Klasse auswählen")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            Spacer()
        }
    }

    // Keine Schüler gefunden
    private var emptyStudentsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Keine Schüler in dieser Klasse")
                .font(.headline)
            Text("Bitte fügen Sie zuerst Schüler hinzu.")
                .foregroundColor(.gray)
            Spacer()
        }
    }

    // Haupttabelle mit Bewertungen
    private var ratingsTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            let ratingDates = viewModel.uniqueDates

            VStack(alignment: .leading, spacing: 0) {
                // Header-Zeile
                HStack(spacing: 0) {
                    // Namens-Spalte
                    Text("Name")
                        .frame(width: 180, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 5)
                        .background(Color(.systemGray5))
                        .border(Color(.systemGray3), width: 0.5)

                    // Datums-Spalten
                    ForEach(ratingDates, id: \.self) { date in
                        Text(formatDate(date))
                            .frame(width: 80)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 5)
                            .background(Color(.systemGray5))
                            .border(Color(.systemGray3), width: 0.5)
                    }

                    // Durchschnitt-Spalte
                    Text("Ø")
                        .frame(width: 60)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 5)
                        .background(Color(.systemGray5))
                        .border(Color(.systemGray3), width: 0.5)
                }

                // Schüler-Zeilen
                ForEach(viewModel.filteredStudents) { student in
                    HStack(spacing: 0) {
                        // Name
                        Text(student.fullName)
                            .frame(width: 180, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 5)
                            .background(
                                isEvenRow(student) ? Color.white : Color(.systemGray6)
                            )
                            .border(Color(.systemGray3), width: 0.5)

                        // Bewertungen für jedes Datum
                        ForEach(ratingDates, id: \.self) { date in
                            RatingCell(
                                rating: viewModel.getRatingFor(studentId: student.id, date: date),
                                isNewStudent: isNewStudent(student, date),
                                onRatingChanged: { newValue in
                                    viewModel.updateRating(
                                        studentId: student.id,
                                        date: date,
                                        value: newValue
                                    )
                                },
                                onAbsenceToggled: {
                                    viewModel.toggleAbsence(
                                        studentId: student.id,
                                        date: date
                                    )
                                },
                                onDelete: {
                                    viewModel.deleteRating(
                                        studentId: student.id,
                                        date: date
                                    )
                                },
                                onArchive: {
                                    viewModel.archiveRating(
                                        studentId: student.id,
                                        date: date
                                    )
                                }
                            )
                            .frame(width: 80)
                            .background(
                                isEvenRow(student) ? Color.white : Color(.systemGray6)
                            )
                            .border(Color(.systemGray3), width: 0.5)
                        }

                        // Durchschnitt
                        AverageRatingCell(
                            average: viewModel.getAverageRatingFor(studentId: student.id)
                        )
                        .frame(width: 60)
                        .background(
                            isEvenRow(student) ? Color.white : Color(.systemGray6)
                        )
                        .border(Color(.systemGray3), width: 0.5)
                    }
                }
            }
            .padding()
        }
    }

    // Export-Button
    private var exportButton: some View {
        Button(action: {
            viewModel.exportRatings()
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Exportieren")
            }
        }
        .disabled(viewModel.selectedClass == nil || viewModel.students.isEmpty)
    }

    // MARK: - Hilfsfunktionen

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM."
        return formatter.string(from: date)
    }

    private func isEvenRow(_ student: Student) -> Bool {
        if let index = viewModel.filteredStudents.firstIndex(where: { $0.id == student.id }) {
            return index % 2 == 0
        }
        return false
    }

    private func isNewStudent(_ student: Student, _ date: Date) -> Bool {
        // Prüft, ob der Schüler an diesem Tag neu hinzugekommen ist
        let calendar = Calendar.current
        let studentDay = calendar.startOfDay(for: student.entryDate)
        let ratingDay = calendar.startOfDay(for: date)

        return studentDay == ratingDay
    }
}

// Zelle für eine einzelne Bewertung
struct RatingCell: View {
    let rating: Rating?
    let isNewStudent: Bool
    let onRatingChanged: (RatingValue?) -> Void
    let onAbsenceToggled: () -> Void
    let onDelete: (() -> Void)?
    let onArchive: (() -> Void)?

    @State private var showingOptions = false

    var body: some View {
        Button(action: {
            showingOptions = true
        }) {
            ZStack {
                if isNewStudent {
                    // Markierung für neu hinzugekommene Schüler
                    Color.yellow.opacity(0.3)
                }

                if let rating = rating {
                    if rating.isAbsent {
                        // Abwesend
                        Text("fehlt")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    } else if let value = rating.value {
                        // Bewertung
                        Text(value.stringValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ratingColor(for: value))
                    } else {
                        // Keine Bewertung, aber anwesend
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                } else {
                    // Kein Eintrag für diesen Tag
                    EmptyView()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .actionSheet(isPresented: $showingOptions) {
            var buttons: [ActionSheet.Button] = [
                .default(Text("++")) { onRatingChanged(.doublePlus) },
                .default(Text("+")) { onRatingChanged(.plus) },
                .default(Text("-")) { onRatingChanged(.minus) },
                .default(Text("--")) { onRatingChanged(.doubleMinus) },
                .default(Text("Keine Bewertung")) { onRatingChanged(nil) },
                .destructive(Text(rating?.isAbsent == true ? "Als anwesend markieren" : "Als abwesend markieren")) {
                    onAbsenceToggled()
                }
            ]

            // Nur anzeigen, wenn bereits eine Bewertung existiert
            if rating != nil {
                if let onDelete = onDelete {
                    buttons.append(.destructive(Text("Löschen")) { onDelete() })
                }

                if let onArchive = onArchive {
                    buttons.append(.destructive(Text("Archivieren")) { onArchive() })
                }
            }

            buttons.append(.cancel())

            return ActionSheet(
                title: Text("Bewertung"),
                buttons: buttons
            )
        }
    }

    // Farbe für die Bewertung
    private func ratingColor(for value: RatingValue) -> Color {
        switch value {
        case .doublePlus: return .green
        case .plus: return Color.green.opacity(0.7)
        case .minus: return Color.red.opacity(0.7)
        case .doubleMinus: return .red
        }
    }
}

// Zelle für den Durchschnitt
struct AverageRatingCell: View {
    let average: Double?

    var body: some View {
        if let avg = average {
            let formattedAvg = String(format: "%.1f", avg)

            Text(formattedAvg)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(averageColor(for: avg))
        } else {
            Text("-")
                .foregroundColor(.gray)
        }
    }

    // Farbe für den Durchschnitt (Farbverlauf von rot zu grün)
    private func averageColor(for value: Double) -> Color {
        // Umrechnung: 1.0 (beste Note) bis 4.0 (schlechteste Note)
        // Auf einen Bereich von 0 bis 1 normalisieren
        let normalized = max(0, min(1, (4.0 - value) / 3.0))

        // Rot zu Grün Farbverlauf
        return Color(
            red: 1.0 - normalized,
            green: normalized,
            blue: 0.0
        )
    }
}

// Klassenauswahl-View nach Wochentagen gruppiert
struct ClassPickerView: View {
    @ObservedObject var viewModel: ResultsViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.classesByWeekday, id: \.weekday) { group in
                    ClassGroupSection(
                        group: group,
                        selectedClassId: viewModel.selectedClass?.id,
                        onClassSelected: selectClass
                    )
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Klasse auswählen", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Fertig") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    // Funktion zum Auswählen einer Klasse
    private func selectClass(_ classId: UUID) {
        viewModel.selectClass(classId)
        presentationMode.wrappedValue.dismiss()
    }
}

// Hilfsstruct für eine Wochentagsgruppe
struct ClassGroupSection: View {
    let group: (weekday: String, classes: [Class])
    let selectedClassId: UUID?
    let onClassSelected: (UUID) -> Void

    var body: some View {
        Section(header: Text(group.weekday)) {
            ForEach(group.classes) { classObj in
                ClassRowItem(
                    classObj: classObj,
                    isSelected: selectedClassId == classObj.id,
                    onTap: { onClassSelected(classObj.id) }
                )
            }
        }
    }
}

// Hilfsstruct für eine einzelne Klassenzeile
struct ClassRowItem: View {
    let classObj: Class
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(classObj.name)
                        .font(.headline)

                    if let note = classObj.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
