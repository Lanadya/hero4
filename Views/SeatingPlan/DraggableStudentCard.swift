import SwiftUI

struct DraggableStudentCard: View {
    // Studenten- und Positionsdaten
    let student: Student
    @State private var position: CGPoint
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    // Drag-Status
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false

    // Edit-Modus
    let editMode: Bool

    // Callback-Funktion für Positionsänderungen
    let onPositionChanged: (UUID, CGPoint) -> Void

    // Konstruktor
    init(student: Student,
         initialPosition: CGPoint,
         cardWidth: CGFloat = 140,
         cardHeight: CGFloat = 80,
         editMode: Bool = false,
         onPositionChanged: @escaping (UUID, CGPoint) -> Void) {
        self.student = student
        self._position = State(initialValue: initialPosition)
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.editMode = editMode
        self.onPositionChanged = onPositionChanged
    }

    var body: some View {
        VStack(spacing: 2) {  // Kleinerer Abstand zwischen Elementen
            // Student name section
            VStack(spacing: 1) {  // Noch engerer Abstand zwischen Vor- und Nachname
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
            .padding(.top, 2)  // Kleinerer oberer Abstand

            Spacer(minLength: 2)

            // Bewertungsbuttons in einer Reihe mit kleinem Abstand
            HStack(spacing: 3) { // Noch kleinerer Abstand zwischen Buttons
                Button(action: {
                    // Später Rating-Funktion
                }) {
                    Text("++")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 25, height: 18) // Breitere, flachere Buttons
                        .background(Color.green.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: {
                    // Später Rating-Funktion
                }) {
                    Text("+")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 25, height: 18)
                        .background(Color.green.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: {
                    // Später Rating-Funktion
                }) {
                    Text("-")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 25, height: 18)
                        .background(Color.red.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())

                Button(action: {
                    // Später Rating-Funktion
                }) {
                    Text("--")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 25, height: 18)
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 2) // Minimaler horizontaler Rand
            .padding(.bottom, 2)
        }
        .padding(3) // Noch kleinerer Rand um alle Inhalte
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: isDragging ? 3 : 0.5)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragging ? Color.blue : Color.gray.opacity(0.3), lineWidth: isDragging ? 2 : 0.5)
        )
        // Positionierung an der übergebenen Position plus Drag-Offset
        .position(position)
        .offset(dragOffset)
        // Drag-Geste hinzufügen
        .gesture(
            editMode ?
                DragGesture()
                    .onChanged { gesture in
                        // Während des Ziehens nur das Offset aktualisieren
                        isDragging = true
                        dragOffset = gesture.translation
                    }
                    .onEnded { gesture in
                        // Nach Ende des Ziehens die gesamte Position aktualisieren
                        isDragging = false
                        let newPosition = CGPoint(
                            x: position.x + gesture.translation.width,
                            y: position.y + gesture.translation.height
                        )
                        position = newPosition
                        dragOffset = .zero

                        // Callback aufrufen, um die Positionsänderung zu melden
                        onPositionChanged(student.id, newPosition)
                    }
                : nil
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}
