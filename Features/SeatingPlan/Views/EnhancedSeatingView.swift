import SwiftUI

struct EnhancedSeatingView: View {
    @StateObject private var viewModel = EnhancedSeatingViewModel()
    @Binding var selectedTab: Int

    // UI-Zustände
    @State private var showClassPicker = false
    @State private var editMode = false
    @State private var isFullscreen = false
    @State private var zoomLevel: Double = 1.0
    @State private var showStudentDetail: Student? = nil
    @State private var showSettings = false
    @State private var cardSize: CGSize = CGSize(width: 140, height: 90)

    // Bildschirmadaption - fürs iPhone wichtig!
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hauptinhalt
                VStack(spacing: 0) {
                    // Header (nur wenn nicht im Vollbildmodus)
                    if !isFullscreen {
                        SeatingHeaderView(
                            viewModel: viewModel,
                            showClassPicker: $showClassPicker,
                            editMode: $editMode,
                            isFullscreen: $isFullscreen,
                            showSettings: $showSettings,
                            zoomLevel: $zoomLevel
                        )
                    }

                    // Hauptansicht mit Schülerkacheln
                    if viewModel.classes.isEmpty {
                        EmptyClassesView(selectedTab: $selectedTab)
                    } else if viewModel.selectedClass == nil {
                        ClassSelectionPromptView(showClassPicker: $showClassPicker)
                    } else if viewModel.students.isEmpty {
                        EmptyStudentsView(selectedTab: $selectedTab)
                    } else {
                        SeatingGridView(
                            viewModel: viewModel,
                            editMode: editMode,
                            zoomLevel: zoomLevel,
                            onStudentTap: { student in
                                if !editMode {
                                    showStudentDetail = student
                                }
                            },
                            screenSize: geometry.size,
                            isFullscreen: isFullscreen,
                            baseCardSize: adaptiveCardSize(for: geometry.size)
                        )
                    }
                }

                // Fullscreen Exit Button
                if isFullscreen {
                    VStack {
                        HStack {
                            ExitFullscreenButton(isFullscreen: $isFullscreen, editMode: $editMode)
                            Spacer()
                            // Control buttons even in fullscreen
                            HStack(spacing: 16) {
                                // Edit mode toggle
                                Button(action: {
                                    editMode.toggle()
                                }) {
                                    Image(systemName: editMode ? "pencil.slash" : "pencil")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }

                                // Zoom controls
                                Button(action: {
                                    zoomLevel = max(0.5, zoomLevel - 0.1)
                                }) {
                                    Image(systemName: "minus.magnifyingglass")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }

                                Button(action: {
                                    zoomLevel = min(2.0, zoomLevel + 0.1)
                                }) {
                                    Image(systemName: "plus.magnifyingglass")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding()
                        Spacer()
                    }
                }

                // Student Detail Overlay (wenn ein Schüler ausgewählt ist)
                if let student = showStudentDetail {
                    StudentDetailOverlay(
                        student: student,
                        viewModel: viewModel,
                        onDismiss: { showStudentDetail = nil }
                    )
                }

                // Settings Overlay
                if showSettings {
                    SeatingSettingsOverlay(
                        viewModel: viewModel,
                        isPresented: $showSettings
                    )
                }
            }
            .sheet(isPresented: $showClassPicker) {
                SeatingClassPicker(viewModel: viewModel)
            }
            .onAppear {
                // Lade verfügbare Klassen
                viewModel.loadClasses()

                // Bildschirmgröße anpassen
                adjustForScreenSize(geometry.size)

                // Prüfe, ob eine Klasse für den Sitzplan ausgewählt wurde
                checkForSelectedClass()

                // Nach kurzer Verzögerung prüfen, ob die Schüleranordnung initialisiert werden sollte
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !viewModel.students.isEmpty {
                        // Prüfen, ob bereits benutzerdefinierte Positionen existieren
                        let hasCustomPositions = viewModel.seatingPositions.contains { $0.isCustomPosition }

                        // Wenn keine benutzerdefinierten Positionen existieren, in der Ecke anordnen
                        if !hasCustomPositions {
                            viewModel.arrangeStudentsInCorner()
                        }
                    }
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                adjustForScreenSize(newSize)
            }
        }
        .navigationBarTitle("Sitzplan", displayMode: .inline)
        .navigationBarHidden(true)
    }

    // Helper-Methoden
    private func adjustForScreenSize(_ size: CGSize) {
        // Passe Kachelgröße basierend auf Bildschirmgröße an
        cardSize = adaptiveCardSize(for: size)
    }

    private func adaptiveCardSize(for size: CGSize) -> CGSize {
        // Für iPhone eine kleinere Kachelgröße
        let isSmallScreen = horizontalSizeClass == .compact || size.width < 600
        let width: CGFloat = isSmallScreen ? 100 : 140
        let height: CGFloat = isSmallScreen ? 70 : 90
        return CGSize(width: width, height: height)
    }

    private func checkForSelectedClass() {
        // Prüfe, ob eine Klasse für den Sitzplan ausgewählt wurde
        if let classIdString = UserDefaults.standard.string(forKey: "selectedClassForSeatingPlan"),
           let classId = UUID(uuidString: classIdString) {
            viewModel.selectClass(classId)
            // Nach Nutzung löschen
            UserDefaults.standard.removeObject(forKey: "selectedClassForSeatingPlan")
        }
        // Falls keine Klasse ausgewählt ist, aber Klassen vorhanden sind, wähle die erste
        else if viewModel.selectedClass == nil && !viewModel.classes.isEmpty {
            viewModel.selectClass(viewModel.classes[0].id)
        }
    }
}

// SeatingHeaderView - keine Änderungen nötig
struct SeatingHeaderView: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    @Binding var showClassPicker: Bool
    @Binding var editMode: Bool
    @Binding var isFullscreen: Bool
    @Binding var showSettings: Bool
    @Binding var zoomLevel: Double
    @State private var showInfoDialog = false

    var body: some View {
        VStack(spacing: 0) {
            // Obere Zeile: Alle Steuerelemente einheitlich nebeneinander
            HStack(spacing: 8) {
                // Klassenauswahl-Button
                Button(action: {
                    showClassPicker = true
                }) {
                    HStack {
                        if let selectedClass = viewModel.selectedClass {
                            Text(selectedClass.name)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        } else {
                            Text("Klasse wählen")
                        }

                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 10)
                    .background(Color.gradePrimaryLight)
                    .cornerRadius(8)
                    .foregroundColor(.gradePrimary)
                }

                // Modus-Umschalter
                Button(action: {
                    editMode.toggle()
                }) {
                    HStack {
                        // Icon je nach Modus
                        Image(systemName: editMode ? "pencil.circle" : "hand.tap")

                        // Text mit korrekten Bezeichnungen
                        Text(editMode ? "Bearbeitungsmodus" : "Bewertungsmodus")
                            .font(.caption)

                        // Umschaltpfeil
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 10)
                    .background(editMode ? Color.heroSecondaryLight : Color.accentGreenLight)
                    .cornerRadius(8)
                    .foregroundColor(editMode ? .heroSecondary : .accentGreen)
                }

                Spacer()

                // Info-Button - nur Icon, konsistent mit Startseite
                Button(action: {
                    showInfoDialog = true
                }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.heroSecondary)
                        .padding(6)
                        .background(Color.heroSecondaryLight)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Vollbildmodus-Button - gleicher Stil wie Info-Button
                Button(action: {
                    withAnimation {
                        isFullscreen = true
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 22))
                        .foregroundColor(.heroSecondary)
                        .padding(6)
                        .background(Color.heroSecondaryLight)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Schüleranzahl-Leiste
            HStack {
                Text("\(viewModel.students.count) Schüler")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !viewModel.absentStudents.isEmpty {
                    Text("(\(viewModel.absentStudents.count) abwesend)")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()
        }
        .background(Color.white)
        .shadow(radius: 1)
        .sheet(isPresented: $showInfoDialog) {
            InfoDialogView(
                isPresented: $showInfoDialog,
                title: "Sitzplan-Hilfe",
                content: "• Bewertungsmodus: Tippen Sie auf einen Schüler, um eine Bewertung (++, +, -, --) zu vergeben oder den Anwesenheitsstatus zu ändern.\n\n• Bearbeitungsmodus: Ziehen Sie die Schülerkarten, um den Sitzplan nach Ihren Wünschen zu gestalten.\n\n• Nutzen Sie den Vollbildmodus für eine bessere Übersicht bei großen Klassen.\n\n• Alle vergebenen Bewertungen werden automatisch in der Notenliste gespeichert.",
                buttonText: "Verstanden"
            )
        }
    }
}

// Fullscreen Exit-Button - keine Änderungen nötig
struct ExitFullscreenButton: View {
    @Binding var isFullscreen: Bool
    @Binding var editMode: Bool

    var body: some View {
        VStack {
            HStack {
                // Nur der Exit-Button und der Modus-Umschalter
                Button(action: {
                    withAnimation {
                        isFullscreen = false
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }

                Spacer()

                // Modus-Umschalter
                Button(action: {
                    editMode.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: editMode ? "pencil.circle.fill" : "hand.tap.fill")
                        Text(editMode ? "Bearbeiten" : "Bewerten")
                            .font(.caption)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.black.opacity(0.4))
                    .foregroundColor(.white)
                }
            }
            .padding()

            Spacer()
        }
    }
}

// Hauptansicht mit Schülerkacheln
struct SeatingGridView: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    let editMode: Bool
    let zoomLevel: Double
    let onStudentTap: (Student) -> Void
    let screenSize: CGSize
    let isFullscreen: Bool
    let baseCardSize: CGSize

    @State private var positions: [UUID: CGPoint] = [:]
    @State private var draggedStudent: UUID? = nil

    var body: some View {
        ZStack {
            // Hintergrund-Raster
            GridBackgroundView()

            // Studentenkarten ohne ForEach
            studentCardsView
        }
        .scaleEffect(zoomLevel)
        .contentShape(Rectangle())
        .onAppear {
            loadPositions()
        }
        .onChange(of: viewModel.seatingPositions) { oldValue, newValue in
            loadPositions()
        }
    }

    // Ausgelagerte View für Studentenkarten
    private var studentCardsView: some View {
        // Statt ForEach verwenden wir Group mit manuell erzeugten Views
        Group {
            // Manuell die Views für jeden Studenten erzeugen
            createStudentCards()
        }
    }

    // Hilfsfunktion zum Erstellen aller StudentCards
    @ViewBuilder
    private func createStudentCards() -> some View {
        // Manuelles Iteration durch das Array
        ZStack {
            // Erste 20 Studenten
            createStudentGroup(startIndex: 0, endIndex: 19)

            // Zweite 20 Studenten
            createStudentGroup(startIndex: 20, endIndex: 39)
        }
    }

    // Hilfsfunktion zum Erstellen einer Gruppe von StudentCards
    @ViewBuilder
    private func createStudentGroup(startIndex: Int, endIndex: Int) -> some View {
        ZStack {
            // Für jeden Studenten mit Position eine Karte erstellen
            ForEach(startIndex...endIndex, id: \.self) { index in
                if index < viewModel.students.count,
                   let student = viewModel.students[safe: index],
                   let position = positions[student.id] {
                    createCard(for: student, at: position)
                }
            }
        }
    }


    // Hilfsfunktion zum Erstellen einer einzelnen Karte
    private func createCard(for student: Student, at position: CGPoint) -> some View {
        StudentCard(
            student: student,
            position: position,
            size: scaledCardSize,
            isAbsent: viewModel.isStudentAbsent(student.id),
            editMode: editMode,
            screenWidth: screenSize.width,
            onTap: {
                onStudentTap(student)
            },
            onDragChanged: { offset in
                handleDrag(studentId: student.id, offset: offset)
            },
            onDragEnded: { offset in
                handleDragEnd(studentId: student.id, finalOffset: offset)
            },
            onRatingSelected: { rating in
                viewModel.addRatingForStudent(studentId: student.id, value: rating)
            }
        )
    }

    // Berechnete Eigenschaften
    private var scaledCardSize: CGSize {
        return CGSize(
            width: baseCardSize.width * zoomLevel,
            height: baseCardSize.height * zoomLevel
        )
    }

    // Helper-Methoden
    private func loadPositions() {
        positions.removeAll()
        for position in viewModel.seatingPositions {
            let screenPosition = gridToScreenPosition(
                x: position.xPos,
                y: position.yPos,
                cardSize: baseCardSize
            )
            positions[position.studentId] = screenPosition
        }
    }

    private func handleDrag(studentId: UUID, offset: CGSize) {
        if editMode {
            draggedStudent = studentId
            if var currentPos = positions[studentId] {
                currentPos.x += offset.width
                currentPos.y += offset.height
                positions[studentId] = currentPos
            }
        }
    }

    private func handleDragEnd(studentId: UUID, finalOffset: CGSize) {
        if editMode, let position = positions[studentId] {
            // Berechne neue Position
            let newPosition = CGPoint(
                x: position.x + finalOffset.width,
                y: position.y + finalOffset.height
            )

            // Stelle sicher, dass die Position innerhalb des sichtbaren Bereichs bleibt
            let safeX = max(scaledCardSize.width/2 + 10,
                            min(newPosition.x, screenSize.width - scaledCardSize.width/2 - 10))
            let safeY = max(scaledCardSize.height/2 + 10,
                           min(newPosition.y, screenSize.height - scaledCardSize.height/2 - 10))

            // Konvertiere die sichere Bildschirmposition zu Grid-Koordinaten
            let (gridX, gridY) = screenToGridPosition(
                x: safeX,
                y: safeY,
                cardSize: baseCardSize
            )

            // Aktualisiere die Position in der Datenbank
            viewModel.updateStudentPosition(
                studentId: studentId,
                newX: max(0, gridX),
                newY: max(0, gridY)
            )

            draggedStudent = nil
        }
    }

    private func gridToScreenPosition(x: Int, y: Int, cardSize: CGSize) -> CGPoint {
        let spacing: CGFloat = 10
        let screenX = CGFloat(x) * (cardSize.width + spacing) + cardSize.width/2 + spacing
        let screenY = CGFloat(y) * (cardSize.height + spacing) + cardSize.height/2 + spacing
        return CGPoint(x: screenX, y: screenY)
    }

    private func screenToGridPosition(x: CGFloat, y: CGFloat, cardSize: CGSize) -> (Int, Int) {
        let spacing: CGFloat = 10
        let gridX = Int((x - cardSize.width/2 - spacing) / (cardSize.width + spacing))
        let gridY = Int((y - cardSize.height/2 - spacing) / (cardSize.height + spacing))
        return (max(0, gridX), max(0, gridY))
    }
}

// Erweiterung für sicheren Array-Zugriff
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct StudentCard: View {
    // Student und Card-Properties
    let student: Student
    let position: CGPoint
    let size: CGSize  // Jetzt als Parameter, keine feste Größe
    let isAbsent: Bool
    let editMode: Bool
    let screenWidth: CGFloat

    // Aktuelle Bewertung
    @State private var currentRating: RatingValue?

    // Drag-State
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false

    // Callbacks
    let onTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let onRatingSelected: (RatingValue) -> Void

    // Layout-Eigenschaften
    private var isCompactLayout: Bool {
        return screenWidth < 600
    }

    var body: some View {
        VStack(spacing: 0) {
            // Name-Bereich - ohne farbigen Hintergrund
            Button(action: {
                if !editMode {
                    onTap()
                }
            }) {
                VStack(spacing: 0) {
                    if !isCompactLayout {
                        Text(truncateName(student.firstName, limit: 10))
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }

                    Text(truncateName(student.lastName, limit: 12))
                        .font(.system(size: isCompactLayout ? 12 : 13, weight: .bold))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(isAbsent ? .gray : .primary)

            Spacer(minLength: 2)

            // Bewertungsbuttons - direkt unter dem Namen
            if !editMode {
                HStack(spacing: isCompactLayout ? 0 : 1) {
                    ratingButton("++", .doublePlus)
                    ratingButton("+", .plus)
                    ratingButton("-", .minus)
                    ratingButton("--", .doubleMinus)
                }
                .padding(.vertical, 2)
                .opacity(isAbsent ? 0.5 : 1.0)
                .disabled(isAbsent) // Keine Bewertung für abwesende Schüler
            }
        }
        .frame(width: size.width, height: size.height)
        .background(isAbsent ? Color.gray.opacity(0.2) : Color.white)
        .cornerRadius(8)
        .shadow(radius: isDragging ? 3 : 0.5)
        .overlay(
            // Rahmen
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: isDragging ? 2 : 0.5)
        )
        .position(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { gesture in
                    if editMode {
                        isDragging = true
                        dragOffset = gesture.translation
                        onDragChanged(gesture.translation)
                    }
                }
                .onEnded { gesture in
                    if editMode {
                        isDragging = false
                        onDragEnded(gesture.translation)
                        dragOffset = .zero
                    }
                }
        )
    }

    // Bewertungsbutton mit Hervorhebung und strenger Begrenzung
    private func ratingButton(_ text: String, _ value: RatingValue) -> some View {
        let isActive = currentRating == value

        let baseColor: Color
        switch value {
        case .doublePlus: baseColor = .green
        case .plus: baseColor = .green.opacity(0.7)
        case .minus: baseColor = .red.opacity(0.7)
        case .doubleMinus: baseColor = .red
        }

        let buttonColor = isActive ? baseColor : baseColor.opacity(0.3)

        return Button(action: {
            onRatingSelected(value)
            withAnimation(.easeInOut(duration: 0.2)) {
                currentRating = value
            }
        }) {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(buttonColor)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .buttonStyle(BorderlessButtonStyle())
        .contentShape(Rectangle()) // Begrenzt die Hitbox auf den sichtbaren Bereich
    }

    private var cardBorderColor: Color {
        if isDragging {
            return Color.blue
        } else if isAbsent {
            return Color.red.opacity(0.3)
        } else {
            return Color.gray.opacity(0.3)
        }
    }

    // Namenbegrenzung für einheitliche Kartengröße
    private func truncateName(_ name: String, limit: Int) -> String {
        if name.count <= limit {
            return name
        }
        return String(name.prefix(limit-1)) + "…"
    }
}

// Overlay für Schülerdetails und Bewertung
struct StudentDetailOverlay: View {
    let student: Student
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    let onDismiss: () -> Void

    @State private var isAbsent: Bool
    @State private var studentNotes: String
    @State private var originalNotes: String
    @State private var showSaveConfirmation = false
    @State private var changesMade = false

    init(student: Student, viewModel: EnhancedSeatingViewModel, onDismiss: @escaping () -> Void) {
        self.student = student
        self.viewModel = viewModel
        self.onDismiss = onDismiss

        // Initialen Zustand laden
        self._isAbsent = State(initialValue: viewModel.isStudentAbsent(student.id))
        self._studentNotes = State(initialValue: student.notes ?? "")
        self._originalNotes = State(initialValue: student.notes ?? "")
    }

    var body: some View {
        ZStack {
            // Hintergrund
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    if changesMade {
                        showSaveConfirmation = true
                    } else {
                        onDismiss()
                    }
                }

            // Inhalt
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(student.fullName)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        if changesMade {
                            showSaveConfirmation = true
                        } else {
                            onDismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gradePrimary)

                // Hauptinhalt
                VStack(spacing: 16) {
                    // Anwesenheitsstatus
                    HStack {
                        Text("Anwesenheit:")
                            .fontWeight(.medium)

                        Spacer()

                        Toggle("Abwesend", isOn: $isAbsent)
                            .labelsHidden()
                            .onChange(of: isAbsent) { oldValue, newValue in
                                // Markieren, dass Änderungen vorgenommen wurden
                                changesMade = true

                                // Direktes Update der Abwesenheit im ViewModel
                                viewModel.updateStudentAbsenceStatus(studentId: student.id, isAbsent: newValue)
                            }

                        Text(isAbsent ? "Abwesend" : "Anwesend")
                            .foregroundColor(isAbsent ? .red : .green)
                    }

                    // Notizen
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen:")
                            .fontWeight(.medium)

                        TextEditor(text: $studentNotes)
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(4)
                            .onChange(of: studentNotes) { oldValue, newValue in
                                changesMade = originalNotes != newValue
                            }
                    }

                    // Buttons für Aktionen
                    HStack {
                        // Abbrechen-Button
                        Button(action: {
                            // Änderungen verwerfen
                            studentNotes = originalNotes
                            // Abwesenheitsstatus zurücksetzen
                            viewModel.updateStudentAbsenceStatus(studentId: student.id, isAbsent: viewModel.isStudentAbsent(student.id))
                            onDismiss()
                        }) {
                            Text("Abbrechen")
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }

                        Spacer()

                        // Speichern-Button
                        Button(action: {
                            // Speichere Änderungen und schließe Overlay
                            saveChanges()
                            onDismiss()
                        }) {
                            Text("Speichern")
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(changesMade ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(!changesMade)
                    }
                }
                .padding()
                .background(Color.white)
            }
            .frame(width: min(400, UIScreen.main.bounds.width - 40))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
        .alert(isPresented: $showSaveConfirmation) {
            Alert(
                title: Text("Änderungen speichern?"),
                message: Text("Möchten Sie die Änderungen speichern?"),
                primaryButton: .default(Text("Speichern")) {
                    saveChanges()
                    onDismiss()
                },
                secondaryButton: .destructive(Text("Verwerfen")) {
                    onDismiss()
                }
            )
        }
    }

    private func saveChanges() {
        // Speichere Notizen
        if studentNotes != originalNotes {
            viewModel.updateStudentNotes(studentId: student.id, notes: studentNotes)
        }

        // Abwesenheit ist bereits in Echtzeit über die Toggle-Änderung gespeichert

        // Auch eine Bewertung für diesen Tag hinzufügen/aktualisieren, wenn der Schüler abwesend ist
        if isAbsent {
            // Einen Eintrag ohne Bewertung, aber mit Abwesenheit erstellen
            // Dies stellt sicher, dass die Abwesenheit auch in der Notenliste erscheint
            viewModel.addRatingForAbsentStudent(studentId: student.id)
        }
    }
}

// Einstellungen-Overlay
struct SeatingSettingsOverlay: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    @Binding var isPresented: Bool
    @State private var columnsForAutoArrange: Int = 5

    var body: some View {
        ZStack {
            // Halbtransparenter Hintergrund
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }

            // Inhalt-Karte
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Sitzplan-Einstellungen")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gradePrimary)

                // Hauptinhalt
                VStack(spacing: 16) {
                    // Automatische Anordnung
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Automatische Anordnung")
                            .font(.headline)

                        Text("Ordnet alle Schüler automatisch in einem Raster an. Bestehende Positionen werden überschrieben.")
                            .font(.caption)
                            .foregroundColor(.gray)

                        HStack {
                            Text("Spalten:")
                                .font(.subheadline)

                            Spacer()

                            Stepper("\(columnsForAutoArrange)", value: $columnsForAutoArrange, in: 2...10)
                                .labelsHidden()
                                .frame(width: 100)
                        }

                        Button(action: {
                            viewModel.arrangeStudentsInGrid(columns: columnsForAutoArrange)
                            isPresented = false
                        }) {
                            Text("Automatisch anordnen")
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }

                    Divider()

                    // Weitere Einstellungen könnten hier hinzugefügt werden
                    // z.B. Farbschemata, Kartengrößen, etc.

                    // Abstandhalter
                    Spacer()
                }
                .padding()
                .background(Color.white)
            }
            .frame(width: min(400, UIScreen.main.bounds.width - 40))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

// Hintergrund-Raster
struct GridBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hintergrund
                Rectangle()
                    .fill(Color(.systemGray6))

                // Vertikale Linien
                ForEach(0...20, id: \.self) { x in
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1)
                        .position(x: CGFloat(x) * (geometry.size.width / 20), y: geometry.size.height / 2)
                        .frame(height: geometry.size.height)
                }

                // Horizontale Linien
                ForEach(0...20, id: \.self) { y in
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .position(x: geometry.size.width / 2, y: CGFloat(y) * (geometry.size.height / 20))
                        .frame(width: geometry.size.width)
                }
            }
        }
    }
}

// Ansicht wenn keine Klassen vorhanden sind
struct EmptyClassesView: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "rectangle.on.rectangle.slash")
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
                selectedTab = 0 // Zur Stundenplan-Ansicht wechseln
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
}

// Ansicht wenn keine Klasse ausgewählt ist
struct ClassSelectionPromptView: View {
    @Binding var showClassPicker: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Bitte wählen Sie eine Klasse")
                .font(.headline)

            Button(action: {
                showClassPicker = true
            }) {
                Text("Klasse auswählen")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Spacer()
        }
    }
}

// Ansicht wenn keine Schüler in der Klasse sind
struct EmptyStudentsView: View {
    @Binding var selectedTab: Int

    var body: some View {
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
                selectedTab = 1 // Zur Schülerverwaltung
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
}

// Klassenauswahl-Dialog
struct SeatingClassPicker: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.classesByWeekday, id: \.weekday) { group in
                    Section(header: Text(group.weekday)) {
                        ForEach(group.classes) { classObj in
                            Button(action: {
                                viewModel.selectClass(classObj.id)
                                presentationMode.wrappedValue.dismiss()
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
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Klasse auswählen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Fertig") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
