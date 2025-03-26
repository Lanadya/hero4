
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
            .onChange(of: geometry.size) { newSize in
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

// Ersetzen Sie die bestehende SeatingHeaderView mit dieser optimierten Version
struct SeatingHeaderView: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    @Binding var showClassPicker: Bool
    @Binding var editMode: Bool
    @Binding var isFullscreen: Bool
    @Binding var showSettings: Bool
    @Binding var zoomLevel: Double

    var body: some View {
        VStack(spacing: 0) {
            // Obere Zeile: Klassenauswahl und Modus-Button
            HStack {
                // Klassenauswahl-Button
                Button(action: {
                    showClassPicker = true
                }) {
                    HStack {
                        if let className = viewModel.selectedClass?.name {
                            Text(className)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            if let note = viewModel.selectedClass?.note, !note.isEmpty {
                                Text("(\(note))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        } else {
                            Text("Klasse wählen")
                        }

                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                Spacer()

                // Modus-Button (Bearbeiten/Bewerten)
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
                    .background(
                        Capsule()
                            .fill(editMode ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    )
                    .foregroundColor(editMode ? .blue : .green)
                }

                // Vollbildmodus-Button
                Button(action: {
                    withAnimation {
                        isFullscreen = true
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Zweite Zeile: Info und Modus-Anzeige
            HStack {
                // Schüleranzahl & Abwesende
                HStack(spacing: 4) {
                    Text("\(viewModel.students.count) Schüler")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !viewModel.absentStudents.isEmpty {
                        Text("(\(viewModel.absentStudents.count) abwesend)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                // Aktueller Modus-Indikator
                if editMode {
                    Text("Ziehen und Positionieren")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()
        }
        .background(Color.white)
        .shadow(radius: 1)
    }
}


// Fullscreen Exit-Button
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

            // Schülerkacheln
            // In the ForEach loop in SeatingGridView
            ForEach(viewModel.students) { student in
                if let position = getPosition(for: student.id) {
                    StudentCard(
                        student: student,
                        position: position,
                        size: scaledCardSize,
                        isAbsent: viewModel.absentStudents.contains(student.id),
                        hasNotes: student.notes != nil && !student.notes!.isEmpty,
                        editMode: editMode,
                        screenWidth: screenSize.width,
                        onTap: {
                            // This can be used for other actions, like showing notes
                            // or toggling absence, but not for rating
                            onStudentTap(student)
                        },
                        onDragChanged: { offset in
                            handleDrag(studentId: student.id, offset: offset)
                        },
                        onDragEnded: { offset in
                            handleDragEnd(studentId: student.id, finalOffset: offset)
                        },
                        // Add the direct rating callback
                        onRatingSelected: { rating in
                            viewModel.addRatingForStudent(studentId: student.id, value: rating)
                            // Optional: provide subtle visual feedback
                        }
                    )
                }
            }
        }
        .scaleEffect(zoomLevel)
        .contentShape(Rectangle())
        .onAppear {
            loadPositions()
        }
        .onChange(of: viewModel.seatingPositions) { _ in
            loadPositions()
        }
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
        for position in viewModel.seatingPositions {
            let screenPosition = gridToScreenPosition(
                x: position.xPos,
                y: position.yPos,
                cardSize: baseCardSize
            )
            positions[position.studentId] = screenPosition
        }
    }

    private func getPosition(for studentId: UUID) -> CGPoint? {
        return positions[studentId]
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

    // Ersetzen Sie die bestehende handleDragEnd-Funktion in SeatingGridView mit dieser sicheren Version
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

struct StudentCard: View {
    let student: Student
    let position: CGPoint
    let size: CGSize
    let isAbsent: Bool
    let hasNotes: Bool
    let editMode: Bool
    let screenWidth: CGFloat
    let onTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize) -> Void
    let onRatingSelected: (RatingValue) -> Void

    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false

    // Erkennen kleiner Bildschirme für kompaktes Layout
    private var isCompactLayout: Bool {
        return screenWidth < 600
    }

    var body: some View {
        VStack(spacing: 2) {
            // Schülername - bei kompakten Layouts nur Nachnamen oder kürzen
            if isCompactLayout {
                // Kompaktes Layout für kleine Bildschirme
                Text(student.lastName)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            } else {
                // Ausführliches Layout für größere Bildschirme
                VStack(spacing: 1) {
                    Text(student.firstName)
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)

                    Text(student.lastName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 1)

            // Bewertungsbuttons - direkt klickbar ohne Overlay
            if !editMode {
                HStack(spacing: isCompactLayout ? 1 : 3) {
                    // Direct rating buttons
                    Button(action: { onRatingSelected(.doublePlus) }) {
                        Text("++")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    Button(action: { onRatingSelected(.plus) }) {
                        Text("+")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .background(Color.green.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    Button(action: { onRatingSelected(.minus) }) {
                        Text("-")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .background(Color.red.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }

                    Button(action: { onRatingSelected(.doubleMinus) }) {
                        Text("--")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 18)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }

            // Statusanzeige unten
            if !isCompactLayout || !editMode {
                HStack(spacing: 8) {
                    // Abwesenheitsindikator
                    if isAbsent {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: isCompactLayout ? 10 : 12))
                            .foregroundColor(.red)
                    }

                    // Notizindikator
                    if hasNotes {
                        Image(systemName: "note.text")
                            .font(.system(size: isCompactLayout ? 10 : 12))
                            .foregroundColor(.blue)
                    }

                    // "Move" Indikator im Bearbeitungsmodus
                    if editMode {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: isCompactLayout ? 10 : 12))
                            .foregroundColor(.blue)
                            .opacity(isDragging ? 0 : 0.7)
                    }

                    Spacer()
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .padding(isCompactLayout ? 2 : 3)
        .frame(width: size.width, height: size.height)
        .background(cardBackground)
        .cornerRadius(8)
        .shadow(radius: isDragging ? 3 : 0.5)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardBorderColor, lineWidth: isDragging ? 2 : 0.5)
        )
        .contentShape(Rectangle())
        .position(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { gesture in
                    if editMode {
                        // Direkte 1:1 Bewegung mit dem Finger/Cursor
                        isDragging = true
                        dragOffset = gesture.translation
                        // Wir informieren den Parent über die aktuelle Position ohne Animation
                        onDragChanged(gesture.translation)
                    }
                }
                .onEnded { gesture in
                    if editMode {
                        // Animation beim Loslassen ausblenden
                        isDragging = false

                        // Finale Position an Parent melden, der die dauerhafte Positionierung übernimmt
                        onDragEnded(gesture.translation)

                        // Offset zurücksetzen (weil die Basis-Position vom Parent aktualisiert wird)
                        dragOffset = .zero
                    }
                }
        )
        .onTapGesture {
            if !editMode {
                onTap()
            }
        }
    }

    // Hintergrundfarbe basierend auf Status
    private var cardBackground: Color {
        if isAbsent {
            return Color.gray.opacity(0.2)
        } else {
            return Color.white
        }
    }

    // Rahmenfarbe basierend auf Zustand
    private var cardBorderColor: Color {
        if isDragging {
            return Color.blue
        } else if isAbsent {
            return Color.gray.opacity(0.3)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// Overlay für Schülerdetails und Bewertung
struct StudentDetailOverlay: View {
    let student: Student
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    let onDismiss: () -> Void

    @State private var showConfirmation = false
    @State private var confirmedAction: (() -> Void)? = nil
    @State private var confirmationMessage = ""
    @State private var isAbsent: Bool

    init(student: Student, viewModel: EnhancedSeatingViewModel, onDismiss: @escaping () -> Void) {
        self.student = student
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self._isAbsent = State(initialValue: viewModel.isStudentAbsent(student.id))
    }

    var body: some View {
        ZStack {
            // Halbtransparenter Hintergrund
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }

            // Inhalt-Karte
            VStack(spacing: 0) {
                // Header: Schülername und Schließen-Button
                HStack {
                    Text(student.fullName)
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gradePrimary)

                // Hauptinhalt
                VStack(spacing: 16) {
                    // Status-Anzeige
                    HStack {
                        Text("Status:")
                            .fontWeight(.medium)

                        Spacer()

                        Toggle("Abwesend", isOn: $isAbsent)
                            .labelsHidden()
                            .onChange(of: isAbsent) { newValue in
                                viewModel.updateStudentAbsenceStatus(studentId: student.id, isAbsent: newValue)
                            }

                        Text(isAbsent ? "Abwesend" : "Anwesend")
                            .foregroundColor(isAbsent ? .red : .green)
                    }

                    // Notizen
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notizen:")
                            .fontWeight(.medium)

                        if let notes = student.notes, !notes.isEmpty {
                            Text(notes)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Keine Notizen vorhanden")
                                .foregroundColor(.gray)
                                .italic()
                        }
                    }

                    Divider()

                    // Bewertungsoptionen
                    Text("Bewertung hinzufügen:")
                        .fontWeight(.medium)

                    VStack(spacing: 12) {
                        // Erste Zeile
                        HStack(spacing: 16) {
                            RatingButton(label: "Sehr gut", symbol: "++", color: .green) {
                                addRating(.doublePlus)
                            }
                            RatingButton(label: "Gut", symbol: "+", color: Color.green.opacity(0.7)) {
                                addRating(.plus)
                            }
                        }

                        // Zweite Zeile
                        HStack(spacing: 16) {
                            RatingButton(label: "Schlecht", symbol: "-", color: Color.red.opacity(0.7)) {
                                addRating(.minus)
                            }
                            RatingButton(label: "Sehr schlecht", symbol: "--", color: .red) {
                                addRating(.doubleMinus)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white)
            }
            .frame(width: min(400, UIScreen.main.bounds.width - 40))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
        .alert(isPresented: $showConfirmation) {
            Alert(
                title: Text("Bestätigung"),
                message: Text(confirmationMessage),
                primaryButton: .default(Text("Ja")) {
                    if let action = confirmedAction {
                        action()
                    }
                },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
    }

    private func addRating(_ value: RatingValue) {
        confirmationMessage = "Möchten Sie wirklich eine \(value.stringValue)-Bewertung für \(student.fullName) hinzufügen?"
        confirmedAction = {
            viewModel.addRatingForStudent(studentId: student.id, value: value)
            // Optional: Bestätigung anzeigen
            onDismiss()
        }
        showConfirmation = true
    }
}

struct RatingButton: View {
    let label: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Text(symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(8)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
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
                ForEach(viewModel.classes) { classObj in
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
            .navigationBarTitle("Klasse auswählen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Fertig") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

//import SwiftUI
//
//struct EnhancedSeatingView: View {
//    @StateObject private var viewModel = EnhancedSeatingViewModel()
//    @Binding var selectedTab: Int
//    @State private var showClassPicker = false
//    @State private var editMode = false
//    @State private var isFullscreen = false
//    @State private var showModeSwitchInfo = false // Temporär deaktiviert
//    init(selectedTab: Binding<Int>) {
//        self._selectedTab = selectedTab
//    }
//
//    var body: some View {
//        NavigationView {
//            ZStack {
//                VStack(spacing: 0) {
//                    // Header (nur wenn nicht im Vollbildmodus)
//                    if !isFullscreen {
//                        SP_HeaderView(
//                            viewModel: viewModel,
//                            showClassPicker: $showClassPicker,
//                            editMode: $editMode,
//                            isFullscreen: $isFullscreen
//                        )
//                    }
//
//                    // Content area
//                    SP_ContentView(
//                        viewModel: viewModel,
//                        selectedTab: $selectedTab,
//                        showClassPicker: $showClassPicker,
//                        editMode: editMode,
//                        isFullscreen: isFullscreen
//                    )
//                }
//
//                // Vollbildmodus-X in der oberen rechten Ecke (nur im Vollbildmodus)
//                if isFullscreen {
//                    SP_ExitButton(isFullscreen: $isFullscreen)
//                }
//
//                //  !!!!!!!!!Info-Toast beim Moduswechsel TEMPORÄR DEAKTIVIERT !!!!!!!!!!!!
////                if showModeSwitchInfo {
////                    VStack {
////                        Spacer().frame(height: 60)
////
////                        HStack {
////                            Image(systemName: editMode ? "arrow.up.and.down.and.arrow.left.and.right" : "pencil")
////                                .foregroundColor(.white)
////                            Text(editMode ? "Positioniere Schüler durch Ziehen" : "Tippe auf Buttons, um Noten zu vergeben")
////                                .foregroundColor(.white)
////                                .font(.footnote)
////                        }
////                        .padding(10)
////                        .background(Color.black.opacity(0.7))
////                        .cornerRadius(20)
////                        .transition(.move(edge: .top).combined(with: .opacity))
////
////                        Spacer()
////                    }
////                    .zIndex(100)
////                    .animation(.easeInOut, value: showModeSwitchInfo)
////                    .onAppear {
////                        // Info-Toast nach 3 Sekunden ausblenden
////                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
////                            withAnimation {
////                                showModeSwitchInfo = false
////                            }
////                        }
////                    }
////                }
//            }
//            .navigationBarTitle("Sitzplan", displayMode: .inline)
//            .navigationBarHidden(true)
//            .sheet(isPresented: $showClassPicker) {
//                SeatingClassPicker(viewModel: viewModel)
//            }
//            .onAppear {
//                // Lade verfügbare Klassen
//                viewModel.loadClasses()
//
//                // Prüfe, ob eine Klasse für den Sitzplan ausgewählt wurde
//                if let classIdString = UserDefaults.standard.string(forKey: "selectedClassForSeatingPlan"),
//                   let classId = UUID(uuidString: classIdString) {
//                    viewModel.selectClass(classId)
//                    // Nach Nutzung löschen
//                    UserDefaults.standard.removeObject(forKey: "selectedClassForSeatingPlan")
//                }
//                // Falls keine Klasse ausgewählt ist, aber Klassen vorhanden sind, wähle die erste
//                else if viewModel.selectedClass == nil && !viewModel.classes.isEmpty {
//                    viewModel.selectClass(viewModel.classes[0].id)
//                }
//
//                // Initial Info-Nachricht für Moduswechsel
//                // Nur beim ersten Erscheinen einmalig anzeigen
//                if !UserDefaults.standard.bool(forKey: "hasSeenSeatingPlanModeInfo") {
//                    // showModeSwitchInfo = true // Temporär deaktiviert
//                    // Nach 3 Sekunden ausblenden
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//                        withAnimation {
//                            showModeSwitchInfo = false
//                        }
//                    }
//
//                    // Markieren, dass die Info gesehen wurde
//                    UserDefaults.standard.set(true, forKey: "hasSeenSeatingPlanModeInfo")
//                }
//            }
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//    }
//}
//
//// MARK: - Seating Class Picker
//// Diese Komponente ist speziell für den EnhancedSeatingViewModel, um Konflikte mit ClassPickerView zu vermeiden
//struct SeatingClassPicker: View {
//    @ObservedObject var viewModel: EnhancedSeatingViewModel
//    @Environment(\.presentationMode) var presentationMode
//
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(viewModel.classes) { classObj in
//                    Button(action: {
//                        viewModel.selectClass(classObj.id)
//                        presentationMode.wrappedValue.dismiss()
//                    }) {
//                        HStack {
//                            VStack(alignment: .leading) {
//                                Text(classObj.name)
//                                    .font(.headline)
//
//                                if let note = classObj.note, !note.isEmpty {
//                                    Text(note)
//                                        .font(.caption)
//                                        .foregroundColor(.gray)
//                                }
//                            }
//
//                            Spacer()
//
//                            if viewModel.selectedClass?.id == classObj.id {
//                                Image(systemName: "checkmark")
//                                    .foregroundColor(.blue)
//                            }
//                        }
//                    }
//                }
//            }
//            .navigationBarTitle("Klasse auswählen", displayMode: .inline)
//            .navigationBarItems(trailing: Button("Fertig") {
//                presentationMode.wrappedValue.dismiss()
//            })
//        }
//    }
//}
