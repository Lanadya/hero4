import SwiftUI

struct EnhancedSeatingView: View {
    @StateObject private var viewModel = EnhancedSeatingViewModel()
    @Binding var selectedTab: Int
    @State private var showClassPicker = false

    // Einstellungen für das Layout
    @State private var cardWidth: CGFloat = 140
    @State private var cardHeight: CGFloat = 80
    @State private var editMode: Bool = false
    @State private var showModeSwitchInfo = false

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header mit Klassenauswahl und Steuerungselementen
                headerView

                if viewModel.classes.isEmpty {
                    emptyClassesView
                } else if viewModel.selectedClass == nil {
                    classSelectionView
                } else if viewModel.students.isEmpty {
                    emptyStudentsView
                } else {
                    // Hier kommt der Sitzplan mit drag & drop
                    ZStack {
                        // Hintergrund-Raster
                        gridBackground

                        // Darauf die Schülerkarten
                        ForEach(viewModel.students) { student in
                            if let position = viewModel.getPositionForStudent(student.id) {
                                DraggableStudentCard(
                                    student: student,
                                    initialPosition: CGPoint(
                                        // Sicherstellen, dass die Karten nicht über dem Header erscheinen
                                        x: CGFloat(position.xPos) * (cardWidth + 10) + cardWidth/2 + 20,
                                        y: CGFloat(position.yPos) * (cardHeight + 10) + cardHeight/2 + 100 // Mehr vertikaler Abstand zum Header
                                    ),
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight,
                                    editMode: editMode,
                                    onPositionChanged: { studentId, newPosition in
                                        // Hier die neue Position speichern
                                        // Konvertiere Bildschirmkoordinaten zurück zu Rasterkoordinaten
                                        let newX = Int(newPosition.x / (cardWidth + 10))
                                        let newY = Int((newPosition.y - 100) / (cardHeight + 10)) // Anpassung für den Header-Abstand
                                        viewModel.updateStudentPosition(
                                            studentId: studentId,
                                            newX: newX,
                                            newY: newY
                                        )
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()

                    // Auto-Layout-Button am unteren Rand
                    autoLayoutButton
                }
            }
            .navigationBarTitle("Sitzplan", displayMode: .inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showClassPicker) {
                ClassPickerView(viewModel: viewModel)
            }
            .onAppear {
                // Lade verfügbare Klassen
                viewModel.loadClasses()

                // Falls keine Klasse ausgewählt ist, aber Klassen vorhanden sind, wähle die erste
                if viewModel.selectedClass == nil && !viewModel.classes.isEmpty {
                    viewModel.selectClass(viewModel.classes[0].id)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Header View

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

            // Bearbeiten-Modus mit besserer Beschreibung
            Button(action: {
                editMode.toggle()
                // Zeige Info an, wenn Modus gewechselt wird
                showModeSwitchInfo = true
                // Ausblenden nach 3 Sekunden
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showModeSwitchInfo = false
                    }
                }
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
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(radius: 1)
    }

    // MARK: - Grid-Hintergrund

    private var gridBackground: some View {
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

    // MARK: - Auto Layout Button

    private var autoLayoutButton: some View {
        Button(action: {
            // Schüler automatisch anordnen
            viewModel.arrangeStudentsInGrid(columns: 6) // Mehr Spalten für rechteckige Karten

            // Reload positions to reflect the changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.loadSeatingPositionsForSelectedClass()
            }
        }) {
            HStack {
                Image(systemName: "rectangle.grid.2x2")
                Text("Auto-Layout")
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Leere Ansichten

    private var emptyClassesView: some View {
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

    private var classSelectionView: some View {
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

    private var emptyStudentsView: some View {
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

// MARK: - Klassen-Auswahl-View

struct ClassPickerView: View {
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
