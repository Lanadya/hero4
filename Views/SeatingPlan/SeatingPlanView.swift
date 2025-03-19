////
////  SeatingPlanView.swift
////  hero4
////
////  Created by Nina Klee on 18.03.25.
////
//
//import Foundation
////
////  SeatingPlanViewModel.swift
////  hero4
////
////  Created by Nina Klee on 18.03.25.
////
//
//import Foundation
//import SwiftUI
//
//struct SeatingPlanView: View {
//    @StateObject private var viewModel: SeatingPlanViewModel
//    @Binding var selectedTab: Int
//    @State private var isFullscreen = false
//    @State private var showClassPicker = false
//    @State private var draggedStudentId: UUID?
//    @State private var gridSpacing: CGFloat = 10
//    @State private var cardSize: CGFloat = 120
//
//    // Dynamische Spaltenzahl basierend auf Gerätetyp und Orientierung
//    @State private var columnCount = 5
//
//    init(classId: UUID? = nil, selectedTab: Binding<Int>) {
//        self._viewModel = StateObject(wrappedValue: SeatingPlanViewModel(classId: classId))
//        self._selectedTab = selectedTab
//    }
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                VStack(spacing: 0) {
//                    // Kompakter Header (nur wenn nicht im Vollbildmodus)
//                    if !isFullscreen {
//                        headerView
//                            .zIndex(100) // Stellt sicher, dass der Header über den Karten bleibt
//                    }
//
//                    if viewModel.students.isEmpty {
//                        emptyView
//                    } else {
//                        // Hier kommt der eigentliche Sitzplan
//                        seatingPlanContent(size: geometry.size)
//                    }
//
//                    // Kontrollleiste für den Sitzplan
//                    if !isFullscreen && !viewModel.students.isEmpty {
//                        controlBar
//                    }
//                }
//
//                // Fullscreen-Steuerung - dezent in der Ecke
//                fullscreenButton
//
//                // Minimaler Overlay im Vollbildmodus für Klasseninfo und Schließen
//                fullscreenOverlay
//            }
//            .onAppear {
//                // Spaltenanzahl anpassen basierend auf Gerätegröße
//                adjustLayoutForSize(geometry.size)
//
//                if viewModel.selectedClassId == nil {
//                    // Lade verfügbare Klassen und wähle die erste, falls keine ausgewählt ist
//                    let classes = DataStore.shared.classes.filter { !$0.isArchived }
//                    if !classes.isEmpty {
//                        viewModel.selectClass(classes[0].id)
//                    }
//                }
//            }
//            .onChange(of: geometry.size) { newSize in
//                adjustLayoutForSize(newSize)
//            }
//            .sheet(isPresented: $showClassPicker) {
//                ClassPickerSheet(viewModel: viewModel)
//            }
//            .alert(isPresented: $viewModel.showError) {
//                Alert(
//                    title: Text("Fehler"),
//                    message: Text(viewModel.errorMessage ?? "Unbekannter Fehler"),
//                    dismissButton: .default(Text("OK"))
//                )
//            }
//            .navigationBarHidden(true)
//        }
//    }
//
//    // MARK: - Header View
//
//    private var headerView: some View {
//        HStack {
//            // Klassenauswahl-Button
//            Button(action: {
//                showClassPicker = true
//            }) {
//                HStack {
//                    if let className = viewModel.selectedClass?.name {
//                        Text(className)
//                            .fontWeight(.medium)
//
//                        if let note = viewModel.selectedClass?.note, !note.isEmpty {
//                            Text("(\(note))")
//                                .font(.caption)
//                                .foregroundColor(.gray)
//                        }
//                    } else {
//                        Text("Klasse wählen")
//                    }
//                    Image(systemName: "checkmark")
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
//
//// MARK: - Bewertungswerte-Enum
//
//enum RatingValue {
//    case doublePlus
//    case plus
//    case minus
//    case doubleMinus
//
//    var stringValue: String {
//        switch self {
//        case .doublePlus: return "++"
//        case .plus: return "+"
//        case .minus: return "-"
//        case .doubleMinus: return "--"
//        }
//    }
//
//    var numericValue: Int {
//        switch self {
//        case .doublePlus: return 1
//        case .plus: return 2
//        case .minus: return 3
//        case .doubleMinus: return 4
//        }
//    }
//} "chevron.down")
//                        .font(.caption)
//                }
//                .padding(.vertical, 8)
//                .padding(.horizontal, 12)
//                .background(Color(.systemGray6))
//                .cornerRadius(8)
//                .foregroundColor(.primary)
//            }
//
//            // Schüleranzahl anzeigen
//            Text("\(viewModel.students.count) Schüler")
//                .font(.caption)
//                .foregroundColor(.gray)
//                .padding(.leading, 8)
//
//            Spacer()
//
//            // Bearbeiten-Button
//            Button(action: {
//                viewModel.isEditMode.toggle()
//            }) {
//                Image(systemName: viewModel.isEditMode ? "checkmark.circle.fill" : "pencil.circle")
//                    .font(.title3)
//                    .foregroundColor(viewModel.isEditMode ? .green : .blue)
//            }
//            .padding(.horizontal, 8)
//        }
//        .padding(.horizontal)
//        .padding(.vertical, 8)
//        .background(Color.white)
//        .shadow(radius: 1)
//    }
//
//    // MARK: - Hauptinhalt des Sitzplans
//
//    private func seatingPlanContent(size: CGSize) -> some View {
//        ZStack {
//            // Hintergrund: Rastergitter oder Klassenzimmer
//            backgroundGrid(size: size)
//                .zIndex(1)
//
//            // Darauf die verschiebbaren Schülerkarten
//            studentCardsLayer(size: size)
//                .zIndex(2)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//
//    private func backgroundGrid(size: CGSize) -> some View {
//        let gridWidth = CGFloat(columnCount) * (cardSize + gridSpacing) + gridSpacing
//        let gridHeight = CGFloat(ceil(Double(viewModel.students.count) / Double(columnCount))) * (cardSize + gridSpacing) + gridSpacing
//
//        return ZStack {
//            Rectangle()
//                .fill(Color(.systemGray6))
//                .frame(width: gridWidth, height: gridHeight)
//
//            // Vertikale Linien
//            ForEach(0...columnCount, id: \.self) { column in
//                Rectangle()
//                    .fill(Color(.systemGray4))
//                    .frame(width: 1, height: gridHeight)
//                    .position(x: CGFloat(column) * (cardSize + gridSpacing) + gridSpacing/2, y: gridHeight/2)
//            }
//
//            // Horizontale Linien
//            let rowCount = Int(ceil(Double(viewModel.students.count) / Double(columnCount)))
//            ForEach(0...rowCount, id: \.self) { row in
//                Rectangle()
//                    .fill(Color(.systemGray4))
//                    .frame(width: gridWidth, height: 1)
//                    .position(x: gridWidth/2, y: CGFloat(row) * (cardSize + gridSpacing) + gridSpacing/2)
//            }
//        }
//        .padding()
//    }
//
//    private func studentCardsLayer(size: CGSize) -> some View {
//        ZStack {
//            ForEach(viewModel.students) { student in
//                if let position = viewModel.getPositionForStudent(student.id) {
//                    DraggableStudentCard(
//                        student: student,
//                        position: position,
//                        cardSize: cardSize,
//                        gridSpacing: gridSpacing,
//                        isEditMode: viewModel.isEditMode,
//                        onPositionChanged: { studentId, newX, newY in
//                            viewModel.updateSeatingPosition(studentId: studentId, newX: newX, newY: newY)
//                        },
//                        onRatingAdded: { studentId, rating in
//                            viewModel.addRating(studentId: studentId, value: rating)
//                        },
//                        onAbsenceToggled: { studentId, isAbsent in
//                            viewModel.markStudentAbsent(studentId, isAbsent: isAbsent)
//                        }
//                    )
//                }
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//
//    // MARK: - Unterste Kontrollleiste
//
//    private var controlBar: some View {
//        HStack {
//            // Anzeigegrößen-Steuerung
//            HStack(spacing: 16) {
//                Button(action: {
//                    if cardSize > 90 {
//                        cardSize -= 10
//                    }
//                }) {
//                    Image(systemName: "minus.circle")
//                        .foregroundColor(.gray)
//                }
//
//                Text("\(Int(cardSize))px")
//                    .font(.caption)
//                    .foregroundColor(.gray)
//
//                Button(action: {
//                    if cardSize < 150 {
//                        cardSize += 10
//                    }
//                }) {
//                    Image(systemName: "plus.circle")
//                        .foregroundColor(.gray)
//                }
//            }
//            .padding(8)
//            .background(Color.white.opacity(0.7))
//            .cornerRadius(20)
//
//            Spacer()
//
//            // Ansicht zurücksetzen
//            Button(action: {
//                // Dialog zur Bestätigung anzeigen
//                // Für jetzt direkt zurücksetzen
//                viewModel.arrangeInGrid()
//            }) {
//                HStack {
//                    Image(systemName: "arrow.counterclockwise.circle")
//                    Text("Anordnung zurücksetzen")
//                }
//                .padding(8)
//                .background(Color.white.opacity(0.7))
//                .cornerRadius(20)
//                .foregroundColor(.blue)
//            }
//        }
//        .padding(.horizontal)
//        .padding(.vertical, 8)
//        .background(Color.white)
//        .shadow(radius: 1)
//    }
//
//    // MARK: - Fullscreen-Steuerungselemente
//
//    private var fullscreenButton: some View {
//        VStack {
//            Spacer()
//
//            HStack {
//                Button(action: {
//                    withAnimation {
//                        isFullscreen.toggle()
//                    }
//                }) {
//                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
//                        .padding(8)
//                        .background(Color.black.opacity(0.2))
//                        .foregroundColor(.white)
//                        .clipShape(Circle())
//                }
//                .padding(12)
//
//                Spacer()
//            }
//        }
//    }
//
//    private var fullscreenOverlay: some View {
//        Group {
//            if isFullscreen {
//                VStack {
//                    HStack {
//                        // Klassenname
//                        if let selectedClass = viewModel.selectedClass {
//                            Button(action: {
//                                showClassPicker = true
//                            }) {
//                                HStack {
//                                    Text(selectedClass.name)
//                                        .fontWeight(.medium)
//                                    Image(systemName: "chevron.down")
//                                        .font(.caption)
//                                }
//                                .padding(6)
//                                .background(Color.black.opacity(0.5))
//                                .foregroundColor(.white)
//                                .cornerRadius(12)
//                            }
//                        }
//
//                        Spacer()
//
//                        // Fullscreen verlassen
//                        Button(action: {
//                            withAnimation {
//                                isFullscreen = false
//                            }
//                        }) {
//                            Image(systemName: "xmark.circle.fill")
//                                .foregroundColor(.white)
//                                .padding(6)
//                                .background(Color.black.opacity(0.5))
//                                .clipShape(Circle())
//                        }
//                    }
//                    .padding(.horizontal, 12)
//                    .padding(.top, 8)
//
//                    Spacer()
//                }
//            }
//        }
//    }
//
//    // MARK: - Hilfsfunktionen
//
//    private func adjustLayoutForSize(_ size: CGSize) {
//        let width = size.width
//
//        // Anpassung basierend auf Breite
//        if width < 400 {  // iPhone SE/Klein
//            columnCount = 3
//            cardSize = 100
//        } else if width < 700 {  // iPhone/iPad Portrait
//            columnCount = 4
//            cardSize = 110
//        } else if width < 900 {  // iPad Portrait/kleinere iPads Landscape
//            columnCount = 5
//            cardSize = 120
//        } else {  // iPad Pro Landscape und größer
//            columnCount = 6
//            cardSize = 130
//        }
//
//        viewModel.gridColumns = columnCount
//    }
//
//    // MARK: - Leere Ansicht wenn keine Daten
//
//    private var emptyView: some View {
//        VStack(spacing: 20) {
//            Spacer()
//
//            Image(systemName: "rectangle.grid.2x2")
//                .font(.system(size: 60))
//                .foregroundColor(.gray)
//
//            Text("Keine Klasse ausgewählt")
//                .font(.headline)
//
//            Button(action: {
//                showClassPicker = true
//            }) {
//                Text("Klasse auswählen")
//                    .padding()
//                    .background(Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//            }
//
//            Spacer()
//        }
//    }
//}
//
//// MARK: - Draggable Student Card
//
//struct DraggableStudentCard: View {
//    let student: Student
//    let position: SeatingPosition
//    let cardSize: CGFloat
//    let gridSpacing: CGFloat
//    let isEditMode: Bool
//    let onPositionChanged: (UUID, Int, Int) -> Void
//    let onRatingAdded: (UUID, RatingValue) -> Void
//    let onAbsenceToggled: (UUID, Bool) -> Void
//
//    @State private var dragOffset = CGSize.zero
//    @State private var isDragging = false
//    @State private var showAbsentMarker = false
//    @State private var showRatingButtons = false
//
//    var body: some View {
//        VStack(spacing: 2) {
//            // Vorname (etwas größer)
//            Text(student.firstName)
//                .font(.system(size: 15))
//                .fontWeight(.medium)
//                .lineLimit(1)
//
//            // Nachname (fett)
//            Text(student.lastName)
//                .font(.system(size: 14, weight: .bold))
//                .lineLimit(1)
//
//            if showRatingButtons {
//                // Bewertungs-Buttons
//                HStack(spacing: 4) {
//                    Button(action: { onRatingAdded(student.id, .doublePlus) }) {
//                        Text("++")
//                            .font(.system(size: 12, weight: .bold))
//                            .frame(width: 20, height: 20)
//                            .background(Color.green.opacity(0.7))
//                            .foregroundColor(.white)
//                            .cornerRadius(4)
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//
//                    Button(action: { onRatingAdded(student.id, .plus) }) {
//                        Text("+")
//                            .font(.system(size: 12, weight: .bold))
//                            .frame(width: 20, height: 20)
//                            .background(Color.green.opacity(0.5))
//                            .foregroundColor(.white)
//                            .cornerRadius(4)
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//
//                    Button(action: { onRatingAdded(student.id, .minus) }) {
//                        Text("-")
//                            .font(.system(size: 12, weight: .bold))
//                            .frame(width: 20, height: 20)
//                            .background(Color.red.opacity(0.5))
//                            .foregroundColor(.white)
//                            .cornerRadius(4)
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//
//                    Button(action: { onRatingAdded(student.id, .doubleMinus) }) {
//                        Text("--")
//                            .font(.system(size: 12, weight: .bold))
//                            .frame(width: 20, height: 20)
//                            .background(Color.red.opacity(0.7))
//                            .foregroundColor(.white)
//                            .cornerRadius(4)
//                    }
//                    .buttonStyle(BorderlessButtonStyle())
//                }
//                .padding(.top, 2)
//            } else {
//                // Anzeige der Bewertungstypen, klickbar zum Ausklappen
//                Button(action: {
//                    // Nur im Normalmodus, nicht während des Ziehens
//                    if !isEditMode {
//                        withAnimation {
//                            showRatingButtons.toggle()
//                        }
//                    }
//                }) {
//                    Text("Bewerten")
//                        .font(.system(size: 10))
//                        .padding(.horizontal, 4)
//                        .padding(.vertical, 1)
//                        .background(Color.blue.opacity(0.1))
//                        .foregroundColor(.blue)
//                        .cornerRadius(4)
//                }
//                .buttonStyle(BorderlessButtonStyle())
//                .opacity(isEditMode ? 0.5 : 1)
//            }
//
//            // Anwesend/Abwesend Toggle
//            Button(action: {
//                // Nur im Normalmodus, nicht während des Ziehens
//                if !isEditMode && !isDragging {
//                    withAnimation {
//                        showAbsentMarker.toggle()
//                        onAbsenceToggled(student.id, showAbsentMarker)
//                    }
//                }
//            }) {
//                Text(showAbsentMarker ? "fehlt" : "anwesend")
//                    .font(.system(size: 9))
//                    .padding(.horizontal, 4)
//                    .padding(.vertical, 1)
//                    .background(
//                        showAbsentMarker ? Color.red.opacity(0.3) : Color.green.opacity(0.3)
//                    )
//                    .foregroundColor(showAbsentMarker ? .red : .green)
//                    .cornerRadius(2)
//            }
//            .buttonStyle(BorderlessButtonStyle())
//            .opacity(isEditMode ? 0.5 : 1)
//
//            if isEditMode {
//                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
//                    .font(.system(size: 10))
//                    .foregroundColor(.blue)
//                    .opacity(isDragging ? 0 : 0.7)
//            }
//        }
//        .padding(5)
//        .frame(width: cardSize, height: cardSize)
//        .background(showAbsentMarker ? Color.gray.opacity(0.2) : Color.white)
//        .cornerRadius(8)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .stroke(isDragging ? Color.blue : Color.gray.opacity(0.3), lineWidth: isDragging ? 2 : 0.5)
//        )
//        .shadow(radius: isDragging ? 3 : 0.5)
//        .scaleEffect(isDragging ? 1.05 : 1.0)
//        .position(
//            x: CGFloat(position.xPos) * (cardSize + gridSpacing) + cardSize/2 + gridSpacing,
//            y: CGFloat(position.yPos) * (cardSize + gridSpacing) + cardSize/2 + gridSpacing
//        )
//        .offset(dragOffset)
//        .gesture(
//            DragGesture()
//                .onChanged { gesture in
//                    // Nur Drag erlauben, wenn Edit-Modus aktiviert ist
//                    if isEditMode {
//                        isDragging = true
//                        dragOffset = gesture.translation
//
//                        // Bewertungsschaltflächen während des Ziehens ausblenden
//                        if showRatingButtons {
//                            showRatingButtons = false
//                        }
//                    }
//                }
//                .onEnded { gesture in
//                    if isEditMode {
//                        isDragging = false
//
//                        // Berechne die neue Position in Zellen
//                        let totalOffsetX = CGFloat(position.xPos) * (cardSize + gridSpacing) + dragOffset.width
//                        let totalOffsetY = CGFloat(position.yPos) * (cardSize + gridSpacing) + dragOffset.height
//
//                        let newXPos = max(0, Int(round(totalOffsetX / (cardSize + gridSpacing))))
//                        let newYPos = max(0, Int(round(totalOffsetY / (cardSize + gridSpacing))))
//
//                        // Setze das visuelle Offset zurück
//                        dragOffset = .zero
//
//                        // Aktualisiere die Position im ViewModel
//                        if newXPos != position.xPos || newYPos != position.yPos {
//                            onPositionChanged(student.id, newXPos, newYPos)
//                        }
//                    }
//                }
//        )
//        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
//        .animation(.easeInOut, value: showAbsentMarker)
//        .animation(.easeInOut, value: showRatingButtons)
//        .animation(.easeInOut, value: isEditMode)
//    }
//}
//
//// MARK: - Klassen-Auswahl-Sheet
//
//struct ClassPickerSheet: View {
//    @ObservedObject var viewModel: SeatingPlanViewModel
//    @Environment(\.presentationMode) var presentationMode
//
//    var body: some View {
//        NavigationView {
//            List {
//                ForEach(DataStore.shared.classes.filter { !$0.isArchived }) { classObj in
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
//                                Image(systemName:
