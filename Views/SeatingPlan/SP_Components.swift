import SwiftUI

// MARK: - SP_StudentCard (Finale Version)

struct SP_StudentCard: View {
    // Basis-Daten
    let student: Student
    let size: CGSize
    let editMode: Bool
    let isAbsent: Bool
    let hasNotes: Bool

    // Drag-Status
    @State private var position: CGPoint
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var showContextMenu = false

    // Größenbegrenzung für das Drag-Verhalten
    let parentSize: CGSize

    // Callbacks
    let onPositionChanged: (UUID, CGPoint) -> Void
    let onAbsenceToggled: (UUID) -> Void
    let onNotesTapped: () -> Void
    let onStudentArchived: ((UUID) -> Void)?
    let onStudentDeleted: ((UUID) -> Void)?

    // Initialisierer
    init(student: Student,
         initialPosition: CGPoint,
         size: CGSize,
         parentSize: CGSize,
         editMode: Bool,
         isAbsent: Bool,
         hasNotes: Bool,
         onPositionChanged: @escaping (UUID, CGPoint) -> Void,
         onAbsenceToggled: @escaping (UUID) -> Void,
         onNotesTapped: @escaping () -> Void,
         onStudentArchived: ((UUID) -> Void)? = nil,
         onStudentDeleted: ((UUID) -> Void)? = nil) {

        self.student = student
        self._position = State(initialValue: initialPosition)
        self.size = size
        self.parentSize = parentSize
        self.editMode = editMode
        self.isAbsent = isAbsent
        self.hasNotes = hasNotes
        self.onPositionChanged = onPositionChanged
        self.onAbsenceToggled = onAbsenceToggled
        self.onNotesTapped = onNotesTapped
        self.onStudentArchived = onStudentArchived
        self.onStudentDeleted = onStudentDeleted
    }

    var body: some View {
        VStack(spacing: 0) { // Minimaler Abstand
            // Namensbereich - maximale Größe
            Button(action: {
                if !editMode {
                    showContextMenu = true
                }
            }) {
                // Namensanzeige - größer und mit weniger Abstand
                VStack(alignment: .center, spacing: 0) {
                    Text(student.firstName)
                        .font(.system(size: 16)) // Größerer Text
                        .fontWeight(.medium)
                        .foregroundColor(isAbsent ? .gray : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6) // Stärkere Skalierung wenn nötig

                    Text(student.lastName)
                        .font(.system(size: 15, weight: .bold)) // Größerer Text
                        .foregroundColor(isAbsent ? .gray : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6) // Stärkere Skalierung wenn nötig
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 1) // Minimaler Abstand
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(editMode)
            .sheet(isPresented: $showContextMenu) {
                SP_StudentActionMenu(
                    student: student,
                    isAbsent: isAbsent,
                    onAbsenceToggled: { onAbsenceToggled(student.id) },
                    onNotesTapped: onNotesTapped,
                    onStudentArchived: onStudentArchived != nil ? { onStudentArchived!(student.id) } : nil,
                    onStudentDeleted: onStudentDeleted != nil ? { onStudentDeleted!(student.id) } : nil
                )
            }

            // Statusanzeigen entfernt, mehr Platz für den Namen

            Spacer(minLength: 1)

            // Bewertungsbuttons - mit minimiertem Abstand
            HStack(spacing: 1) { // Minimaler Abstand
                Button(action: {
                    // Bewertung ++
                }) {
                    Text("++")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 25, height: 20)
                        .background(Color.green.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isAbsent || editMode)

                Button(action: {
                    // Bewertung +
                }) {
                    Text("+")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 25, height: 20)
                        .background(Color.green.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isAbsent || editMode)

                Spacer(minLength: 2) // Minimaler Abstand, aber noch erkennbar

                Button(action: {
                    // Bewertung -
                }) {
                    Text("-")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 25, height: 20)
                        .background(Color.red.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isAbsent || editMode)

                Button(action: {
                    // Bewertung --
                }) {
                    Text("--")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 25, height: 20)
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(isAbsent || editMode)
            }
            .padding(.horizontal, 2) // Minimaler Abstand
            .padding(.bottom, 2)
            .opacity(isAbsent ? 0.3 : 1.0)
        }
        .frame(width: size.width, height: size.height)
        .background(isAbsent ? Color.gray.opacity(0.1) : Color.white)
        .cornerRadius(8)
        .shadow(radius: isDragging ? 3 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragging ? Color.blue : (isAbsent ? Color.red.opacity(0.5) : Color.gray.opacity(0.3)),
                        lineWidth: isDragging ? 2 : 1)
        )
        // Position der Karte
        .position(position)
        .offset(dragOffset)
        // Drag-Geste (nur im Bearbeitungsmodus) - mit Begrenzung
        .gesture(
            editMode ?
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        dragOffset = gesture.translation
                    }
                    .onEnded { gesture in
                        isDragging = false

                        // Neue Position berechnen
                        var newPosition = CGPoint(
                            x: position.x + gesture.translation.width,
                            y: position.y + gesture.translation.height
                        )

                        // Begrenzung, damit die Karten nicht aus dem sichtbaren Bereich verschwinden
                        let safeMargin: CGFloat = 10.0

                        // Sicherheitsrand oben (Header berücksichtigen)
                        let topMargin: CGFloat = 60.0

                        // Sicherheitsrand unten (TabBar berücksichtigen)
                        let bottomMargin: CGFloat = 70.0

                        // Horizontale Begrenzung
                        newPosition.x = max(size.width/2 + safeMargin, newPosition.x)
                        newPosition.x = min(parentSize.width - size.width/2 - safeMargin, newPosition.x)

                        // Vertikale Begrenzung
                        newPosition.y = max(size.height/2 + topMargin, newPosition.y)
                        newPosition.y = min(parentSize.height - size.height/2 - bottomMargin, newPosition.y)

                        // Anti-Überlappungs-Logik: Verhindert, dass Karten zu 100% übereinander liegen
                        // In der Realität würde man hier prüfen, ob die Position bereits von einer anderen Karte belegt ist

                        // Drag zurücksetzen und neue Position übernehmen
                        dragOffset = .zero
                        position = newPosition

                        // Callback aufrufen, um die Position zu speichern
                        onPositionChanged(student.id, newPosition)
                    }
                : nil
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}


// MARK: - SP_StudentActionMenu - Erweitertes Aktionsmenü

struct SP_StudentActionMenu: View {
    let student: Student
    let isAbsent: Bool
    let onAbsenceToggled: () -> Void
    let onNotesTapped: () -> Void
    let onStudentArchived: (() -> Void)?
    let onStudentDeleted: (() -> Void)?

    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Schüler: \(student.fullName)")) {
                    // Abwesenheitsstatus
                    Button(action: {
                        onAbsenceToggled()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: isAbsent ? "person.fill.checkmark" : "person.fill.xmark")
                                .foregroundColor(isAbsent ? .green : .red)
                            Text(isAbsent ? "Als anwesend markieren" : "Als abwesend markieren")
                        }
                    }

                    // Notizen
                    Button(action: {
                        onNotesTapped()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(.blue)
                            Text(student.notes == nil || student.notes!.isEmpty ?
                                 "Notiz hinzufügen" : "Notiz bearbeiten")
                        }
                    }
                }

                // Verwaltungsoptionen (Archivieren/Löschen)
                if onStudentArchived != nil || onStudentDeleted != nil {
                    Section(header: Text("Verwaltung")) {
                        // Archivieren-Option
                        if let archiveAction = onStudentArchived {
                            Button(action: {
                                archiveAction()
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "archivebox")
                                        .foregroundColor(.orange)
                                    Text("Schüler archivieren")
                                }
                            }
                        }

                        // Löschen-Option mit Bestätigung
                        if let deleteAction = onStudentDeleted {
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text("Schüler löschen")
                                        .foregroundColor(.red)
                                }
                            }
                            .alert(isPresented: $showDeleteConfirmation) {
                                Alert(
                                    title: Text("Schüler löschen"),
                                    message: Text("Möchten Sie den Schüler '\(student.fullName)' wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden."),
                                    primaryButton: .destructive(Text("Löschen")) {
                                        deleteAction()
                                        presentationMode.wrappedValue.dismiss()
                                    },
                                    secondaryButton: .cancel()
                                )
                            }
                        }
                    }
                }

                // Infosektion
                Section(header: Text("Info")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Erfasst am: \(formattedDate(student.entryDate))")
                            .font(.caption)
                            .foregroundColor(.gray)

                        if let exitDate = student.exitDate {
                            Text("Ausgetreten am: \(formattedDate(exitDate))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Aktionen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Fertig") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .presentationDetents([.medium])
    }

    // Hilfsfunktion für Datumsformatierung
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

// MARK: - SP_HeaderView

struct SP_HeaderView: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    @Binding var showClassPicker: Bool
    @Binding var editMode: Bool
    @Binding var isFullscreen: Bool

    var body: some View {
        HStack {
            // Klassenauswahl-Button
            Button(action: {
                showClassPicker = true
            }) {
                HStack {
                    if let className = viewModel.selectedClass?.name {
                        Text(className)
                            .fontWeight(.medium)

                        if let note = viewModel.selectedClass?.note, !note.isEmpty {
                            Text("(\(note))")
                                .font(.caption)
                                .foregroundColor(.gray)
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
                .foregroundColor(.primary)
            }

            // Schüleranzahl anzeigen
            Text("\(viewModel.students.count) Schüler")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 8)

            Spacer()

            // Vollbildmodus-Button
            Button(action: {
                withAnimation {
                    isFullscreen = true
                }
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 4)

            // Bearbeiten-Modus
            Button(action: {
                editMode.toggle()
            }) {
                HStack {
                    Text(editMode ? "Fertig" : "Bearbeiten")
                        .font(.caption)
                        .foregroundColor(editMode ? .green : .blue)

                    Image(systemName: editMode ? "checkmark" : "pencil")
                        .font(.caption)
                        .foregroundColor(editMode ? .green : .blue)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(editMode ? .green : .blue).opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(radius: 1)
    }
}

// MARK: - SP_EmptyClassesView

struct SP_EmptyClassesView: View {
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
}

// MARK: - SP_ClassSelectionView

struct SP_ClassSelectionView: View {
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

// MARK: - SP_EmptyStudentsView

struct SP_EmptyStudentsView: View {
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
}

// MARK: - SP_ExitButton

struct SP_ExitButton: View {
    @Binding var isFullscreen: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        isFullscreen = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            Spacer()
        }
    }
}

// MARK: - SP_ContentView

struct SP_ContentView: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    @Binding var selectedTab: Int
    @Binding var showClassPicker: Bool
    let editMode: Bool
    let isFullscreen: Bool

    // Einstellungen für die Karten
    private let cardWidth: CGFloat = 110
    private let cardHeight: CGFloat = 70

    var body: some View {
        if viewModel.classes.isEmpty {
            SP_EmptyClassesView(selectedTab: $selectedTab)
        } else if viewModel.selectedClass == nil {
            SP_ClassSelectionView(showClassPicker: $showClassPicker)
        } else if viewModel.students.isEmpty {
            SP_EmptyStudentsView(selectedTab: $selectedTab)
        } else {
            // Der eigentliche Sitzplan
            SP_GridView(
                viewModel: viewModel,
                editMode: editMode,
                cardWidth: cardWidth,
                cardHeight: cardHeight
            )
        }
    }
}


// MARK: - SP_GridView (Finale Version mit Überlappungsvermeidung)

struct SP_GridView: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    let editMode: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    // Überwache Orientierungsänderungen
    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation

    // Speichert die Positionen aller Karten, um Überlappungen zu verhindern
    @State private var occupiedPositions: [CGPoint] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hintergrund
                Color(.systemGray6)
                    .edgesIgnoringSafeArea(.all)

                // Karten
                ForEach(viewModel.students) { student in
                    if let position = viewModel.getPositionForStudent(student.id) {
                        let initialPosition = calculateInitialPosition(position: position, geometry: geometry)

                        SP_StudentCard(
                            student: student,
                            initialPosition: initialPosition,
                            size: CGSize(width: cardWidth, height: cardHeight),
                            parentSize: geometry.size, // Wichtig: Elterngröße übergeben für Positionsbegrenzung
                            editMode: editMode,
                            isAbsent: viewModel.isStudentAbsent(student.id),
                            hasNotes: student.notes != nil && !student.notes!.isEmpty,
                            onPositionChanged: { studentId, newPosition in
                                // Prüfe auf Überlappung und finde eine freie Position, wenn nötig
                                let adjustedPosition = findNonOverlappingPosition(
                                    proposedPosition: newPosition,
                                    studentId: studentId,
                                    cardSize: CGSize(width: cardWidth, height: cardHeight),
                                    geometry: geometry
                                )

                                // Berechne Grid-Koordinaten
                                let newX = max(0, Int((adjustedPosition.x - cardWidth/2 - 10) / (cardWidth * 1.2)))
                                let newY = max(0, Int((adjustedPosition.y - cardHeight/2 - 10) / (cardHeight * 1.2)))

                                // Position im ViewModel aktualisieren
                                viewModel.updateStudentPosition(
                                    studentId: studentId,
                                    newX: newX,
                                    newY: newY
                                )

                                // Aktualisiere die belegten Positionen
                                updateOccupiedPositions()
                            },
                            onAbsenceToggled: { studentId in
                                let currentState = viewModel.isStudentAbsent(studentId)
                                viewModel.updateStudentAbsenceStatus(studentId: studentId, isAbsent: !currentState)
                            },
                            onNotesTapped: {
                                // Notizen bearbeiten
                                editStudentNotes(student)
                            },
                            onStudentArchived: { studentId in
                                // Student archivieren
                                viewModel.archiveStudent(student)
                            },
                            onStudentDeleted: { studentId in
                                // Student löschen
                                viewModel.deleteStudent(id: studentId)
                                // Aktualisiere die belegten Positionen
                                updateOccupiedPositions()
                            }
                        )
                    }
                }
            }
            .onAppear {
                // Initialisiere die belegten Positionen
                updateOccupiedPositions()

                // Überwache Orientierungsänderungen
                NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                                      object: nil, queue: .main) { _ in
                    let newOrientation = UIDevice.current.orientation
                    if newOrientation != orientation && (newOrientation.isLandscape || newOrientation.isPortrait) {
                        orientation = newOrientation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Wenn Orientierung wechselt, stelle sicher, dass alle Karten sichtbar sind
                            adjustCardPositionsForNewOrientation(geometry: geometry)
                        }
                    }
                }
            }
            .onDisappear {
                // Beobachter entfernen
                NotificationCenter.default.removeObserver(self)
            }
        }
    }

    // Berechnet die initiale Position einer Karte basierend auf den Grid-Koordinaten
    private func calculateInitialPosition(position: SeatingPosition, geometry: GeometryProxy) -> CGPoint {
        // Standardberechnung
        let x = CGFloat(position.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10
        let y = CGFloat(position.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10

        // Sicherheitsabfrage: Stelle sicher, dass die Position im sichtbaren Bereich ist
        let safeX = min(max(x, cardWidth/2 + 10), geometry.size.width - cardWidth/2 - 10)
        let safeY = min(max(y, cardHeight/2 + 60), geometry.size.height - cardHeight/2 - 70)

        return CGPoint(x: safeX, y: safeY)
    }

    // Aktualisiert die Liste der belegten Positionen
    private func updateOccupiedPositions() {
        occupiedPositions = viewModel.students.compactMap { student in
            if let position = viewModel.getPositionForStudent(student.id) {
                return CGPoint(
                    x: CGFloat(position.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10,
                    y: CGFloat(position.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10
                )
            }
            return nil
        }
    }

    // Findet eine Position, die nicht mit anderen Karten überlappt
    private func findNonOverlappingPosition(
        proposedPosition: CGPoint,
        studentId: UUID,
        cardSize: CGSize,
        geometry: GeometryProxy
    ) -> CGPoint {
        // Wenn die Position nicht von einer anderen Karte belegt ist, verwende sie
        let maxOverlap: CGFloat = cardSize.width * 0.5 // Maximal 50% Überlappung erlaubt

        // Prüfe, ob die vorgeschlagene Position zu stark mit einer anderen überlappt
        var overlapsExcessively = false

        for position in occupiedPositions {
            // Ignoriere die Position der aktuellen Karte
            if let currentPosition = viewModel.getPositionForStudent(studentId),
               abs(position.x - (CGFloat(currentPosition.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10)) < 5 &&
               abs(position.y - (CGFloat(currentPosition.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10)) < 5 {
                continue
            }

            // Berechne den Abstand zwischen der vorgeschlagenen Position und der belegten Position
            let distance = sqrt(pow(proposedPosition.x - position.x, 2) + pow(proposedPosition.y - position.y, 2))

            // Wenn der Abstand kleiner als die halbe Kartengröße ist, überlappt die Karte zu stark
            if distance < maxOverlap {
                overlapsExcessively = true
                break
            }
        }

        // Wenn keine übermäßige Überlappung besteht, verwende die vorgeschlagene Position
        if !overlapsExcessively {
            return proposedPosition
        }

        // Andernfalls finde eine nahegelegene freie Position
        let gridSpacingX = cardWidth * 1.2
        let gridSpacingY = cardHeight * 1.2

        // Versuche umliegende Positionen im Raster
        for offsetX in [-1, 0, 1] {
            for offsetY in [-1, 0, 1] {
                if offsetX == 0 && offsetY == 0 {
                    continue // Überspringe die ursprüngliche Position
                }

                let alternateX = proposedPosition.x + CGFloat(offsetX) * gridSpacingX
                let alternateY = proposedPosition.y + CGFloat(offsetY) * gridSpacingY

                // Prüfe, ob die Position im sichtbaren Bereich liegt
                if alternateX < cardSize.width/2 + 10 || alternateX > geometry.size.width - cardSize.width/2 - 10 ||
                   alternateY < cardSize.height/2 + 60 || alternateY > geometry.size.height - cardSize.height/2 - 70 {
                    continue
                }

                // Prüfe, ob die Position frei ist
                var isFree = true
                for position in occupiedPositions {
                    // Ignoriere die Position der aktuellen Karte
                    if let currentPosition = viewModel.getPositionForStudent(studentId),
                       abs(position.x - (CGFloat(currentPosition.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10)) < 5 &&
                       abs(position.y - (CGFloat(currentPosition.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10)) < 5 {
                        continue
                    }

                    let distance = sqrt(pow(alternateX - position.x, 2) + pow(alternateY - position.y, 2))
                    if distance < maxOverlap {
                        isFree = false
                        break
                    }
                }

                if isFree {
                    return CGPoint(x: alternateX, y: alternateY)
                }
            }
        }

        // Wenn keine freie Position gefunden wurde, verwende die vorgeschlagene Position
        // mit einer kleinen Verschiebung, um zu verhindern, dass Karten exakt übereinander liegen
        return CGPoint(
            x: proposedPosition.x + CGFloat.random(in: -20...20),
            y: proposedPosition.y + CGFloat.random(in: -20...20)
        )
    }

    // Passt Kartenpositionen an, wenn die Orientierung wechselt
    private func adjustCardPositionsForNewOrientation(geometry: GeometryProxy) {
        // Für jeden Schüler
        for student in viewModel.students {
            if let position = viewModel.getPositionForStudent(student.id) {
                // Berechne die aktuelle Position in Bildschirmkoordinaten
                let currentPos = CGPoint(
                    x: CGFloat(position.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10,
                    y: CGFloat(position.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10
                )

                // Prüfe, ob die Position im sichtbaren Bereich liegt
                let isVisible = currentPos.x >= cardWidth/2 + 10 &&
                                currentPos.x <= geometry.size.width - cardWidth/2 - 10 &&
                                currentPos.y >= cardHeight/2 + 60 &&
                                currentPos.y <= geometry.size.height - cardHeight/2 - 70

                // Wenn nicht, passe die Position an
                if !isVisible {
                    // Berechne eine neue Position im sichtbaren Bereich
                    let safeX = min(max(currentPos.x, cardWidth/2 + 10), geometry.size.width - cardWidth/2 - 10)
                    let safeY = min(max(currentPos.y, cardHeight/2 + 60), geometry.size.height - cardHeight/2 - 70)

                    // Neue Grid-Koordinaten berechnen
                    let newX = max(0, Int((safeX - cardWidth/2 - 10) / (cardWidth * 1.2)))
                    let newY = max(0, Int((safeY - cardHeight/2 - 10) / (cardHeight * 1.2)))

                    // Position aktualisieren
                    viewModel.updateStudentPosition(
                        studentId: student.id,
                        newX: newX,
                        newY: newY
                    )
                }
            }
        }

        // Aktualisiere die belegten Positionen
        updateOccupiedPositions()
    }

    // Hilfsfunktion für Notizen
    private func editStudentNotes(_ student: Student) {
        print("Notizen bearbeiten für: \(student.fullName)")
        // In einer vollständigen Implementierung würde hier ein Notizen-Editor erscheinen
    }
}

// MARK: - SP_ClassPickerView

struct SP_ClassPickerView: View {
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
    }
}
