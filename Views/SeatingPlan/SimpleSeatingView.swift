import SwiftUI

struct SimpleSeatingView: View {
    @StateObject private var viewModel = SimpleSeatingViewModel()
    @Binding var selectedTab: Int
    @State private var isFullscreen = false
    @State private var showClassPicker = false

    // Dynamische Spaltenzahl basierend auf Gerätetyp und Orientierung
    @State private var columnCount = 5

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    // Kompakter Header (nur wenn nicht im Vollbildmodus)
                    if !isFullscreen {
                        headerView
                    }

                    if viewModel.classes.isEmpty {
                        emptyView
                    } else {
                        if let selectedClass = viewModel.selectedClass {
                            if viewModel.students.isEmpty {
                                noStudentsView
                            } else {
                                studentGrid(size: geometry.size)
                            }
                        } else {
                            classSelector
                        }
                    }
                }

                // Fullscreen-Steuerung - immer sichtbar, aber diskret
                VStack {
                    Spacer()

                    HStack {
                        Button(action: {
                            withAnimation {
                                isFullscreen.toggle()
                            }
                        }) {
                            Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .padding(8)

                        Spacer()

                        // Schaltfläche zum Anpassen der Kachelgröße
                        if !isFullscreen {
                            HStack(spacing: 16) {
                                Button(action: {
                                    if columnCount > 3 {
                                        columnCount -= 1
                                    }
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.gray)
                                }

                                Text("\(columnCount) Spalten")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                Button(action: {
                                    if columnCount < 8 {
                                        columnCount += 1
                                    }
                                }) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.7))
                            .cornerRadius(20)
                            .padding(.trailing, 8)
                        }
                    }
                }

                // Minimaler Overlay im Vollbildmodus
                if isFullscreen {
                    VStack {
                        HStack {
                            // Klassenname
                            if let selectedClass = viewModel.selectedClass {
                                Button(action: {
                                    showClassPicker = true
                                }) {
                                    HStack {
                                        Text(selectedClass.name)
                                            .fontWeight(.medium)
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .padding(6)
                                    .background(Color.black.opacity(0.5))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }

                            Spacer()

                            // Fullscreen verlassen
                            Button(action: {
                                withAnimation {
                                    isFullscreen = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        Spacer()
                    }
                }
            }
            .onAppear {
                // Spaltenanzahl anpassen basierend auf Gerätegröße
                adjustColumnCount(for: geometry.size)

                viewModel.loadClasses()
                // Automatisch die erste Klasse laden, wenn keine ausgewählt
                if viewModel.selectedClass == nil && !viewModel.classes.isEmpty {
                    viewModel.selectClass(viewModel.classes[0].id)
                }
            }
            .onChange(of: geometry.size) { newSize in
                adjustColumnCount(for: newSize)
            }
            .sheet(isPresented: $showClassPicker) {
                ClassPickerSheet(viewModel: viewModel) {
                    showClassPicker = false
                }
            }
            .navigationBarHidden(true)
        }
    }

    // Kompakter Header mit Klassenauswahl
    private var headerView: some View {
        HStack {
            // Klassenauswahl-Button
            Button(action: {
                showClassPicker = true
            }) {
                HStack {
                    if let className = viewModel.selectedClass?.name {
                        Text(className)
                            .fontWeight(.medium)
                    } else {
                        Text("Klasse wählen")
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .foregroundColor(.primary)
            }

            // Schüleranzahl anzeigen
            if let selectedClass = viewModel.selectedClass {
                Text("\(viewModel.students.count) Schüler")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Layout-Optionen
            Menu {
                Button(action: {
                    // Grid-Layout (bereits Standardeinstellung)
                }) {
                    Label("Raster-Ansicht", systemImage: "square.grid.3x3")
                }

                // Weitere Layout-Optionen...
            } label: {
                Image(systemName: "square.grid.3x3")
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(radius: 1)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Keine Klassen vorhanden")
                .font(.headline)

            Text("Bitte erstellen Sie zuerst eine Klasse im Stundenplan.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                selectedTab = 0 // Zur Klassenliste wechseln
            }) {
                Text("Zum Stundenplan")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Spacer()
        }
    }

    private var classSelector: some View {
        VStack(spacing: 20) {
            Text("Bitte wählen Sie eine Klasse")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                    ForEach(viewModel.classes) { classObj in
                        Button(action: {
                            viewModel.selectClass(classObj.id)
                        }) {
                            VStack {
                                Text(classObj.name)
                                    .font(.headline)

                                if let note = classObj.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 1)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }

    private var noStudentsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Keine Schüler in dieser Klasse")
                .font(.headline)

            Text("Fügen Sie zuerst Schüler in der Schülerverwaltung hinzu.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                selectedTab = 1 // Zur Schülerliste wechseln
            }) {
                Text("Zur Schülerverwaltung")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Spacer()
        }
    }

    private func studentGrid(size: CGSize) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columnCount),
                spacing: 4
            ) {
                ForEach(viewModel.students) { student in
                    OptimizedStudentCard(student: student)
                }
            }
            .padding(4)
        }
    }

    // Dynamische Anpassung der Spaltenanzahl basierend auf Bildschirmgröße
    private func adjustColumnCount(for size: CGSize) {
        let width = size.width

        // Anpassung basierend auf Breite
        if width < 375 {  // iPhone SE/Klein
            columnCount = 3
        } else if width < 700 {  // iPhone/iPad Portrait
            columnCount = 4
        } else if width < 900 {  // iPad Portrait/kleinere iPads Landscape
            columnCount = 5
        } else {  // iPad Pro Landscape und größer
            columnCount = 6
        }
    }
}

struct OptimizedStudentCard: View {
    let student: Student
    @State private var showAbsentMarker = false

    var body: some View {
        VStack(spacing: 2) {
            // Vorname (etwas größer)
            Text(student.firstName)
                .font(.system(size: 15))
                .fontWeight(.medium)
                .lineLimit(1)

            // Nachname (fett)
            Text(student.lastName)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)

            // Bewertungs-Buttons mit reduziertem Spacing
            HStack(spacing: 4) {
                // ++
                Button(action: { addRating(.doublePlus, student: student) }) {
                    Text("++")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(Color.green.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())

                // +
                Button(action: { addRating(.plus, student: student) }) {
                    Text("+")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(Color.green.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())

                // -
                Button(action: { addRating(.minus, student: student) }) {
                    Text("-")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(Color.red.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())

                // --
                Button(action: { addRating(.doubleMinus, student: student) }) {
                    Text("--")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.top, 2)

            // Anwesend/Abwesend Toggle
            Button(action: {
                withAnimation {
                    showAbsentMarker.toggle()
                }
            }) {
                Text(showAbsentMarker ? "fehlt" : "anwesend")
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        showAbsentMarker ?
                            Color.red.opacity(0.3) :
                            Color.green.opacity(0.3)
                    )
                    .foregroundColor(showAbsentMarker ? .red : .green)
                    .cornerRadius(2)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(5)
        .background(showAbsentMarker ? Color.gray.opacity(0.2) : Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(radius: 0.5)
    }

    // Einfache Funktion zum "Hinzufügen" einer Bewertung (simuliert)
    private func addRating(_ rating: RatingValue, student: Student) {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
        print("Bewertung \(rating.stringValue) für \(student.fullName)")
    }
}

// Klassen-Auswahl-Sheet
struct ClassPickerSheet: View {
    @ObservedObject var viewModel: SimpleSeatingViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.classes) { classObj in
                    Button(action: {
                        viewModel.selectClass(classObj.id)
                        onDismiss()
                    }) {
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

                            if viewModel.selectedClass?.id == classObj.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Klasse auswählen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Fertig") {
                onDismiss()
            })
        }
    }
}

// Bewertungswerte
enum RatingValue {
    case doublePlus
    case plus
    case minus
    case doubleMinus

    var stringValue: String {
        switch self {
        case .doublePlus: return "++"
        case .plus: return "+"
        case .minus: return "-"
        case .doubleMinus: return "--"
        }
    }
}

// Einfaches ViewModel ohne komplexe Abhängigkeiten
class SimpleSeatingViewModel: ObservableObject {
    @Published var classes: [Class] = []
    @Published var students: [Student] = []
    @Published var selectedClass: Class?

    private let dataStore = DataStore.shared

    func loadClasses() {
        classes = dataStore.classes.filter { !$0.isArchived }
    }

    func selectClass(_ id: UUID) {
        selectedClass = dataStore.getClass(id: id)
        if let classId = selectedClass?.id {
            loadStudents(classId: classId)
        }
    }

    func loadStudents(classId: UUID) {
        students = dataStore.getStudentsForClass(classId: classId, includeArchived: false)
    }

    // Hilfsfunktion zum Hinzufügen von Test-Schülern (für Entwicklungszwecke)
    func addTestStudents() {
        guard let classId = selectedClass?.id else { return }

        let firstNames = ["Max", "Anna", "Paul", "Sophie", "Tom", "Lisa", "Felix", "Sarah", "Lukas", "Lena",
                        "Jonas", "Laura", "David", "Julia", "Niklas", "Emma", "Alexander", "Mia", "Leon", "Hannah"]
        let lastNames = ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Hoffmann", "Schulz",
                       "Bauer", "Koch", "Richter", "Klein", "Wolf", "Schröder", "Neumann", "Schwarz", "Zimmermann", "Braun"]

        // 30 zufällige Schüler
        for i in 0..<30 {
            let firstName = firstNames[i % firstNames.count]
            let lastName = lastNames[i % lastNames.count] + String(i)

            let student = Student(
                firstName: firstName,
                lastName: lastName,
                classId: classId
            )

            dataStore.addStudent(student)
        }

        // Daten neu laden
        loadStudents(classId: classId)
    }
}
