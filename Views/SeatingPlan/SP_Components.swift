import SwiftUI

// MARK: - StudentCard Position Management
struct SP_StudentCard: View {
    // Student and card properties
    let student: Student
    let initialPosition: CGPoint
    let size: CGSize
    let parentSize: CGSize
    let editMode: Bool
    let isAbsent: Bool
    let hasNotes: Bool

    // State for dragging
    @State private var position: CGPoint
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false

    // Callbacks
    let onPositionChanged: (UUID, CGPoint) -> Void
    let onAbsenceToggled: (UUID) -> Void
    let onNotesTapped: () -> Void
    let onStudentArchived: ((UUID) -> Void)?
    let onStudentDeleted: ((UUID) -> Void)?

    // Rating callback
    let onRatingSelected: ((RatingValue) -> Void)?

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
         onStudentDeleted: ((UUID) -> Void)? = nil,
         onRatingSelected: ((RatingValue) -> Void)? = nil) {

        self.student = student
        self.initialPosition = initialPosition
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
        self.onRatingSelected = onRatingSelected
    }

    // MARK: - View Body Implementation
    var body: some View {
        VStack(spacing: 2) {
            // Student name section
            studentNameView

            Spacer(minLength: 2)

            // Rating buttons
            ratingButtonsView

            // Icons for absence and notes
            iconRowView
        }
        .padding(3)
        .frame(width: size.width, height: size.height)
        .background(isAbsent ? Color.gray.opacity(0.2) : Color.white)
        .cornerRadius(8)
        .shadow(radius: isDragging ? 3 : 0.5)
        .overlay(cardBorder)
        .position(position)
        .offset(dragOffset)
        .gesture(
                editMode ?
                    DragGesture()
                        .onChanged { gesture in
                            isDragging = true
                            dragOffset = gesture.translation
                        }
                        .onEnded { gesture in
                            isDragging = false
                            let newPosition = CGPoint(
                                x: position.x + gesture.translation.width,
                                y: position.y + gesture.translation.height
                            )
                            dragOffset = .zero
                            onPositionChanged(student.id, newPosition)
                        }
                    : nil
            )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }

    // MARK: - Subviews

    private var studentNameView: some View {
        VStack(spacing: 1) {
            // First name
            Text(student.firstName)
                .font(.system(size: 14))
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // Last name
            Text(student.lastName)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 2)
    }

    private var ratingButtonsView: some View {
        HStack(spacing: 3) {
            // ++ Button
            ratingButton(text: "++", color: Color.green.opacity(0.7)) {
                onRatingSelected?(.doublePlus)
            }

            // + Button
            ratingButton(text: "+", color: Color.green.opacity(0.5)) {
                onRatingSelected?(.plus)
            }

            // - Button
            ratingButton(text: "-", color: Color.red.opacity(0.5)) {
                onRatingSelected?(.minus)
            }

            // -- Button
            ratingButton(text: "--", color: Color.red.opacity(0.7)) {
                onRatingSelected?(.doubleMinus)
            }
        }
    }

    private func ratingButton(text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .frame(width: size.width / 5, height: 18)
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .buttonStyle(BorderlessButtonStyle())
        .disabled(editMode)
    }

    private var iconRowView: some View {
        HStack(spacing: 8) {
            // Absent toggle
            Button(action: {
                if !editMode {
                    onAbsenceToggled(student.id)
                }
            }) {
                Image(systemName: isAbsent ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isAbsent ? .red : .green)
            }
            .buttonStyle(BorderlessButtonStyle())
            .disabled(editMode)

            // Notes indicator/button
            if hasNotes {
                Button(action: {
                    if !editMode {
                        onNotesTapped()
                    }
                }) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                .disabled(editMode)
            }

            // "Move" indicator when in edit mode
            if editMode {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .opacity(isDragging ? 0 : 0.7)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(isDragging ? Color.blue : Color.gray.opacity(0.3),
                    lineWidth: isDragging ? 2 : 0.5)
    }
}

// MARK: - SP_GridView Definition
struct SP_GridView: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    let editMode: Bool

    @State var cardWidth: CGFloat = 140
    @State var cardHeight: CGFloat = 80
    @State var occupiedPositions: [CGPoint] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hintergrund-Raster
                SP_GridBackground()

                // Darauf die Schülerkarten
                ForEach(viewModel.students) { student in
                    if let position = viewModel.getPositionForStudent(student.id) {
                        createStudentCard(for: student, position: position, geometry: geometry)
                    }
                }
            }
            .onAppear {
                updateOccupiedPositions()
            }
            .onChange(of: geometry.size) { newSize in
                adjustCardPositionsForNewOrientation(geometry: geometry)
            }
        }
    }

    // Helper to create student card
    private func createStudentCard(
        for student: Student,
        position: SeatingPosition,
        geometry: GeometryProxy
    ) -> some View {
        let initialPos = calculateInitialPosition(position: position, geometry: geometry)

        return SP_StudentCard(
            student: student,
            initialPosition: initialPos,
            size: CGSize(width: cardWidth, height: cardHeight),
            parentSize: geometry.size,
            editMode: editMode,
            isAbsent: false, // Hier müsste der tatsächliche Wert kommen
            hasNotes: student.notes != nil && !student.notes!.isEmpty,
            onPositionChanged: { studentId, newPosition in
                handlePositionChange(studentId: studentId, newPosition: newPosition)
            },
            onAbsenceToggled: { studentId in
                // Abwesenheits-Handling
                print("Abwesenheit für Schüler \(studentId) umgeschaltet")
            },
            onNotesTapped: {
                // Notizen-Anzeige/Bearbeitung
                print("Notizen für Schüler \(student.id) anzeigen/bearbeiten")
            }
        )
    }

    // Handle student position change
    private func handlePositionChange(studentId: UUID, newPosition: CGPoint) {
        // Umrechnung von Bildschirmkoordinaten zu Grid-Koordinaten
        let newX = Int((newPosition.x - cardWidth/2 - 10) / (cardWidth * 1.2))
        let newY = Int((newPosition.y - cardHeight/2 - 10) / (cardHeight * 1.2))

        viewModel.updateStudentPosition(
            studentId: studentId,
            newX: newX,
            newY: newY
        )
    }

    // Calculate initial position with safety bounds
    func calculateInitialPosition(position: SeatingPosition, geometry: GeometryProxy) -> CGPoint {
        let rawX = CGFloat(position.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10
        let rawY = CGFloat(position.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10

        return ensurePositionInBounds(
            CGPoint(x: rawX, y: rawY),
            size: CGSize(width: cardWidth, height: cardHeight),
            parentSize: geometry.size
        )
    }

    // Ensure position stays within visible bounds
    func ensurePositionInBounds(_ position: CGPoint, size: CGSize, parentSize: CGSize) -> CGPoint {
        let safeMargin: CGFloat = 10.0
        let topMargin: CGFloat = 60.0  // Space for header
        let bottomMargin: CGFloat = 70.0  // Space for tab bar

        return CGPoint(
            x: min(max(position.x, size.width/2 + safeMargin),
                   parentSize.width - size.width/2 - safeMargin),
            y: min(max(position.y, size.height/2 + topMargin),
                   parentSize.height - size.height/2 - bottomMargin)
        )
    }

    // Find a position that doesn't overlap with other cards
    func findNonOverlappingPosition(
        proposedPosition: CGPoint,
        studentId: UUID,
        cardSize: CGSize,
        geometry: GeometryProxy
    ) -> CGPoint {
        // First, ensure the position is within bounds
        let boundedPosition = ensurePositionInBounds(proposedPosition, size: cardSize, parentSize: geometry.size)

        // Check for overlap with existing cards
        let maxOverlap: CGFloat = cardSize.width * 0.5
        let currentStudentPositions = getCurrentStudentPosition(studentId)

        // Return the position if no excessive overlap
        if !hasExcessiveOverlap(boundedPosition, studentId: studentId, maxOverlap: maxOverlap) {
            return boundedPosition
        }

        // If overlapping, try adjacent grid positions
        let gridSpacingX = cardSize.width * 1.2
        let gridSpacingY = cardSize.height * 1.2

        // Try positions in a spiral pattern
        return findPositionInSpiralPattern(
            around: boundedPosition,
            studentId: studentId,
            maxOverlap: maxOverlap,
            gridSpacingX: gridSpacingX,
            gridSpacingY: gridSpacingY,
            cardSize: cardSize,
            geometry: geometry
        )
    }

    // Try to find a position in spiral pattern
    private func findPositionInSpiralPattern(
        around center: CGPoint,
        studentId: UUID,
        maxOverlap: CGFloat,
        gridSpacingX: CGFloat,
        gridSpacingY: CGFloat,
        cardSize: CGSize,
        geometry: GeometryProxy
    ) -> CGPoint {
        // Try positions in a spiral pattern around the original position
        for distance in 1...3 {
            for offsetY in -distance...distance {
                for offsetX in -distance...distance {
                    // Skip positions that aren't on the outer edge of the spiral
                    if abs(offsetX) < distance && abs(offsetY) < distance {
                        continue
                    }

                    let alternatePos = CGPoint(
                        x: center.x + CGFloat(offsetX) * gridSpacingX,
                        y: center.y + CGFloat(offsetY) * gridSpacingY
                    )

                    // Ensure position is within bounds
                    let safePos = ensurePositionInBounds(alternatePos, size: cardSize, parentSize: geometry.size)

                    // If this position doesn't overlap, use it
                    if !hasExcessiveOverlap(safePos, studentId: studentId, maxOverlap: maxOverlap) {
                        return safePos
                    }
                }
            }
        }

        // If no free position found, add a small random offset to prevent exact overlap
        return CGPoint(
            x: center.x + CGFloat.random(in: -15...15),
            y: center.y + CGFloat.random(in: -15...15)
        )
    }

    // Helper to check if a position overlaps too much with existing cards
    private func hasExcessiveOverlap(_ position: CGPoint, studentId: UUID, maxOverlap: CGFloat) -> Bool {
        let currentPosition = getCurrentStudentPosition(studentId)

        for otherPosition in occupiedPositions {
            // Skip comparing with the card's own previous position
            if let currentPos = currentPosition,
               abs(otherPosition.x - currentPos.x) < 5 &&
               abs(otherPosition.y - currentPos.y) < 5 {
                continue
            }

            let distance = sqrt(pow(position.x - otherPosition.x, 2) +
                               pow(position.y - otherPosition.y, 2))

            if distance < maxOverlap {
                return true
            }
        }

        return false
    }

    // Helper to get the current position of a student card
    private func getCurrentStudentPosition(_ studentId: UUID) -> CGPoint? {
        if let position = viewModel.getPositionForStudent(studentId) {
            return CGPoint(
                x: CGFloat(position.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10,
                y: CGFloat(position.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10
            )
        }
        return nil
    }

    // Update the list of occupied positions
    func updateOccupiedPositions() {
        occupiedPositions = viewModel.students.compactMap { student in
            guard let position = viewModel.getPositionForStudent(student.id) else {
                return nil
            }

            return CGPoint(
                x: CGFloat(position.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10,
                y: CGFloat(position.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10
            )
        }
    }

    // Adjust card positions after orientation change
    func adjustCardPositionsForNewOrientation(geometry: GeometryProxy) {
        let visibleWidth = geometry.size.width
        let visibleHeight = geometry.size.height

        // If there are too many cards for the current layout, use auto-layout
        if shouldUseAutoLayout(width: visibleWidth) {
            // Calculate optimal columns based on screen width
            let optimalColumns = max(3, Int(visibleWidth / (cardWidth * 1.3)))
            viewModel.arrangeStudentsInGrid(columns: optimalColumns)
            return
        }

        // Otherwise just check each card's position
        for student in viewModel.students {
            if let position = viewModel.getPositionForStudent(student.id) {
                checkAndAdjustPositionIfNeeded(
                    student: student,
                    position: position,
                    visibleWidth: visibleWidth,
                    visibleHeight: visibleHeight,
                    geometry: geometry
                )
            }
        }

        // Update occupation map
        updateOccupiedPositions()
    }

    // Check if auto layout should be used based on student count and screen width
    private func shouldUseAutoLayout(width: CGFloat) -> Bool {
        return viewModel.students.count > 15 || (width < 500 && viewModel.students.count > 8)
    }

    // Check if a position is out of bounds and adjust if needed
    private func checkAndAdjustPositionIfNeeded(
        student: Student,
        position: SeatingPosition,
        visibleWidth: CGFloat,
        visibleHeight: CGFloat,
        geometry: GeometryProxy
    ) {
        // Convert to screen coordinates
        let screenPos = CGPoint(
            x: CGFloat(position.xPos) * (cardWidth * 1.2) + cardWidth/2 + 10,
            y: CGFloat(position.yPos) * (cardHeight * 1.2) + cardHeight/2 + 10
        )

        // Check if position is outside visible area
        let isOutOfBounds = screenPos.x < cardWidth/2 + 10 ||
                           screenPos.x > visibleWidth - cardWidth/2 - 10 ||
                           screenPos.y < cardHeight/2 + 60 ||
                           screenPos.y > visibleHeight - cardHeight/2 - 70

        if isOutOfBounds {
            // Calculate safe position
            let safePos = ensurePositionInBounds(
                screenPos,
                size: CGSize(width: cardWidth, height: cardHeight),
                parentSize: geometry.size
            )

            // Convert back to grid coordinates
            let newX = max(0, Int((safePos.x - cardWidth/2 - 10) / (cardWidth * 1.2)))
            let newY = max(0, Int((safePos.y - cardHeight/2 - 10) / (cardHeight * 1.2)))

            // Update position
            viewModel.updateStudentPosition(
                studentId: student.id,
                newX: newX,
                newY: newY
            )
        }
    }

    // Function for handling student notes
    func editStudentNotes(_ student: Student) {
        // In a complete implementation, show a note editor sheet/modal
        if let notes = student.notes, !notes.isEmpty {
            // Edit existing notes
            print("Editing notes for: \(student.fullName) - Current: \(notes)")
        } else {
            // Add new notes
            print("Adding notes for: \(student.fullName)")
        }

        // Implementation could show an alert with a text field
        // or a separate modal view with a TextEditor
    }
}

// MARK: - SP_GridBackground
struct SP_GridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hintergrund
                Rectangle()
                    .fill(Color(.systemGray6))

                // Vertikale Linien
                ForEach(0...10, id: \.self) { x in
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1)
                        .position(x: CGFloat(x) * (geometry.size.width / 10), y: geometry.size.height / 2)
                        .frame(height: geometry.size.height)
                }

                // Horizontale Linien
                ForEach(0...10, id: \.self) { y in
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 1)
                        .position(x: geometry.size.width / 2, y: CGFloat(y) * (geometry.size.height / 10))
                        .frame(width: geometry.size.width)
                }
            }
        }
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
            classSelectionButton

            // Schüleranzahl anzeigen
            Text("\(viewModel.students.count) Schüler")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.leading, 8)

            Spacer()

            // Bearbeiten-Modus mit besserer Beschreibung
            editModeToggleButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(radius: 1)
    }

    private var classSelectionButton: some View {
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
    }

    private var editModeToggleButton: some View {
        Button(action: {
            editMode.toggle()
        }) {
            HStack {
                Text(editMode ? "Sitzplan bearbeiten" : "Noten vergeben")
                    .font(.caption)
                    .foregroundColor(editMode ? .green : .blue)

                Image(systemName: editMode ? "arrow.up.and.down.and.arrow.left.and.right" : "pencil")
                    .font(.caption)
                    .foregroundColor(editMode ? .green : .blue)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(editMode ? .green : .blue).opacity(0.1))
            .cornerRadius(8)
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
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding()
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

    var body: some View {
        VStack {
            if viewModel.classes.isEmpty {
                SP_EmptyClassesView(selectedTab: $selectedTab)
            } else if viewModel.selectedClass == nil {
                SP_ClassSelectionView(showClassPicker: $showClassPicker)
            } else if viewModel.students.isEmpty {
                SP_EmptyStudentsView(selectedTab: $selectedTab)
            } else {
                SP_GridView(viewModel: viewModel, editMode: editMode)
            }
        }
    }
}

// MARK: - Empty State Views
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
