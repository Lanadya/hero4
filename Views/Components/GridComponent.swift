import SwiftUI

enum CellType {
    case unusable
    case columnHeader
    case rowHeader
    case interactive
}

enum CellState {
    case empty
    case filled
    case editing
    case error
}

struct GridCellData {
    var type: CellType
    var state: CellState = .empty
    var text: String = ""
    var secondaryText: String = ""
    var row: Int
    var column: Int
    var classObject: Class?
}

struct GridComponent: View {
    @ObservedObject var viewModel: TimetableViewModel
    @Binding var selectedTab: Int
    @Binding var showDebugControls: Bool
    @State private var selectedCellRow: Int = 0
    @State private var selectedCellColumn: Int = 0
    @State private var selectedClass: Class?
    @State private var showAddClassModal = false
    @State private var showEditClassModal = false
    @State private var currentClasses: [Class] = []

    // Layout-spezifische States
    @State private var isLandscape = false
    @State private var showNotes = true
    @State private var needsScrolling = false
//    @State private var showIntroOverlay = false
    @State private var showHelpAlert = false

    private let rows = 13  // 1 Header + 12 Stunden
    private let columns = 6  // 1 Header + 5 Tage

    private let weekdays = ["", "Mo", "Di", "Mi", "Do", "Fr"]

    init(viewModel: TimetableViewModel, showDebugControls: Binding<Bool>, selectedTab: Binding<Int> = .constant(0)) {
        self.viewModel = viewModel
        self._showDebugControls = showDebugControls
        self._selectedTab = selectedTab
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            // Prüfen, ob wir uns im Landscape-Modus befinden
            let isLandscapeMode = screenWidth > screenHeight

            // Berechne, wie viel Platz wir für die Tabelle haben
            // Berücksichtige Header und Debug-Bereich
            let availableHeight = screenHeight - (showDebugControls ? 60 : 20)

            // Feste Höhe für die Überschriftenzeile
            let headerHeight: CGFloat = 30

            // Berechne die maximale Höhe für eine Stundenzeile
            let maxRowHeight = (availableHeight - headerHeight) / 12

            // Berechne die Breite für interaktive Zellen
            // Die erste Spalte (Stundennummern) hat 40 Punkte Breite
            let interactiveCellWidth = (screenWidth - 50) / 5

            // Minimale Höhe für vernünftige Darstellung
            let rowHeight = max(min(maxRowHeight, 70), 30)

            // Entscheide, ob Notizen angezeigt werden sollen
            let shouldShowNotes = isLandscapeMode ?
            interactiveCellWidth >= 100 && rowHeight >= 45 :
            interactiveCellWidth >= 80 && rowHeight >= 50

            // Berechne, ob wir scrollen müssen
            let totalGridHeight = headerHeight + (rowHeight * 12)
            let needsToScroll = totalGridHeight > availableHeight

            VStack(spacing: 0) {
                // Nur ScrollView verwenden, wenn wirklich nötig
                if needsToScroll {
                    ScrollView([.vertical], showsIndicators: true) {
                        gridContent(
                            rowHeight: rowHeight,
                            headerHeight: headerHeight,
                            cellWidth: interactiveCellWidth,
                            isLandscape: isLandscapeMode,
                            showNotes: shouldShowNotes
                        )
                        .padding([.horizontal, .top], 4)
                    }
                } else {
                    gridContent(
                        rowHeight: rowHeight,
                        headerHeight: headerHeight,
                        cellWidth: interactiveCellWidth,
                        isLandscape: isLandscapeMode,
                        showNotes: shouldShowNotes
                    )
                    .padding([.horizontal, .top], 4)
                }

                // Debug-Info über aktuelle Klassen
#if DEBUG
                if showDebugControls {
                    VStack(alignment: .leading) {
                        Text("DEBUG: Aktive Klassen: \(viewModel.classes.count)")
                            .font(.caption)
                            .foregroundColor(.gray)

                        ForEach(viewModel.classes) { classObj in
                            Text("- \(classObj.name) an (\(classObj.row),\(classObj.column))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                }
#endif

                // Fehleranzeige
                if viewModel.showError, let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .onAppear {
                print("DEBUG GridComponent: onAppear aufgerufen")
                viewModel.loadClasses()

                // Initialen Status setzen
                self.isLandscape = isLandscapeMode
                self.showNotes = shouldShowNotes
                self.needsScrolling = needsToScroll
            }
            .onChange(of: geometry.size) { oldValue, newValue in
                // Parameter neu berechnen bei Größenänderung
                let newIsLandscape = newValue.width > newValue.height
                let newAvailableHeight = newValue.height - (showDebugControls ? 60 : 20)
                let newMaxRowHeight = (newAvailableHeight - headerHeight) / 12
                let newInteractiveCellWidth = (newValue.width - 50) / 5
                let newRowHeight = max(min(newMaxRowHeight, 70), 30)
                let newShouldShowNotes = newIsLandscape ?
                newInteractiveCellWidth >= 100 && newRowHeight >= 45 :
                newInteractiveCellWidth >= 80 && newRowHeight >= 50
                let newTotalGridHeight = headerHeight + (newRowHeight * 12)
                let newNeedsToScroll = newTotalGridHeight > newAvailableHeight

                self.isLandscape = newIsLandscape
                self.showNotes = newShouldShowNotes
                self.needsScrolling = newNeedsToScroll
            }
            .onChange(of: viewModel.classes) { oldClasses, newClasses in
                print("DEBUG GridComponent: classes geändert, Anzahl: \(newClasses.count)")
                currentClasses = newClasses
            }
            .sheet(isPresented: $showAddClassModal) {
                // Übergebe nur gültige Werte: Zeilen 1-12, Spalten 1-5
                let validRow = max(1, min(12, selectedCellRow))
                let validColumn = max(1, min(5, selectedCellColumn))

                AddClassView(
                    row: validRow,
                    column: validColumn,
                    viewModel: viewModel,
                    isPresented: $showAddClassModal,
                    selectedTab: $selectedTab
                )
            }
            .sheet(isPresented: $showEditClassModal) {
                if let classObj = selectedClass {
                    EditClassView(class: classObj, viewModel: viewModel, isPresented: $showEditClassModal)
                }
            }
            // Auslösen einer Aktualisierung, wenn Modal geschlossen wird
            .onChange(of: showAddClassModal) { oldValue, isShowing in
                if !isShowing {
                    print("DEBUG GridComponent: AddClassModal geschlossen, Aktualisiere Grid")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.loadClasses()
                    }
                }
            }
            .onChange(of: showEditClassModal) { oldValue, isShowing in
                if !isShowing {
                    print("DEBUG GridComponent: EditClassModal geschlossen, Aktualisiere Grid")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.loadClasses()
                    }
                }
            }
        }
    }
//        // Im View-Body nach GeometryReader
//        .overlay(
//            Group {
//                if showIntroOverlay && viewModel.classes.isEmpty {
//                    VStack {
//                        Spacer()
//
//                        HStack {
//                            Spacer()
//
//                            VStack(alignment: .center, spacing: 16) {
//                                Image(systemName: "hand.tap")
//                                    .font(.system(size: 40))
//                                    .foregroundColor(.white)
//
//                                Text("Tippen Sie auf eine Zelle, um eine neue Klasse anzulegen")
//                                    .font(.headline)
//                                    .foregroundColor(.white)
//                                    .multilineTextAlignment(.center)
//                                    .padding()
//                            }
//                            .padding()
//                            .background(
//                                RoundedRectangle(cornerRadius: 16)
//                                    .fill(Color.blue.opacity(0.8))
//                            )
//                            .shadow(radius: 8)
//                            .padding()
//
//                            Spacer()
//                        }
//
//                        Spacer()
//                    }
//                    .contentShape(Rectangle())
//                    .onTapGesture {
//                        showIntroOverlay = false
//                        UserDefaults.standard.set(true, forKey: "hasSeenOverlay")
//                    }
//                }
//            }
//        )
//        .onAppear {
//            // Prüfe, ob der Nutzer das Overlay schon gesehen hat
//            if !UserDefaults.standard.bool(forKey: "hasSeenOverlay") {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    showIntroOverlay = true
//                }
//            }
//        }
//    }

    // Extrahiere die eigentliche Grid-Darstellung in eine separate Funktion
    private func gridContent(rowHeight: CGFloat, headerHeight: CGFloat, cellWidth: CGFloat, isLandscape: Bool, showNotes: Bool) -> some View {
        VStack(spacing: 2) {
            // Header-Zeile (Wochentage)
            HStack(spacing: 2) {
                ForEach(0..<columns, id: \.self) { column in
                    let cellData = getCellData(row: 0, column: column)
                    AdaptiveGridCell(
                        data: cellData,
                        showDebugControls: showDebugControls,
                        isLandscape: isLandscape,
                        showNotes: showNotes,
                        calculatedWidth: column == 0 ? 40 : cellWidth,
                        calculatedHeight: headerHeight
                    )
                }
            }

            // Inhaltliche Zeilen (Stunden 1-12)
            ForEach(1..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<columns, id: \.self) { column in
                        let cellData = getCellData(row: row, column: column)
                        AdaptiveGridCell(
                            data: cellData,
                            showDebugControls: showDebugControls,
                            isLandscape: isLandscape,
                            showNotes: showNotes,
                            calculatedWidth: column == 0 ? 40 : cellWidth,
                            calculatedHeight: rowHeight
                        )
                        .onTapGesture {
                            handleCellTap(cellData)
                        }
                        .onLongPressGesture {
                            handleCellLongPress(cellData)
                        }
                    }
                }
            }
        }
    }

    private func getCellData(row: Int, column: Int) -> GridCellData {
        // Zelle (0,0) - unbenutzt
        if row == 0 && column == 0 {
            return GridCellData(type: .unusable, row: row, column: column)
        }

        // Erste Zeile (außer 0,0) - Spaltenüberschriften
        if row == 0 {
            return GridCellData(type: .columnHeader, text: weekdays[column], row: row, column: column)
        }

        // Erste Spalte - Zeilenüberschriften
        if column == 0 {
            return GridCellData(type: .rowHeader, text: "\(row)", row: row, column: column)
        }

        // Interaktive Zellen - manuelles Durchsuchen der Klassen
        let classObject = currentClasses.first {
            $0.row == row &&
            $0.column == column &&
            !$0.isArchived
        }

        let state: CellState = classObject != nil ? .filled : .empty

        return GridCellData(
            type: .interactive,
            state: state,
            text: classObject?.name ?? "",
            secondaryText: classObject?.note ?? "",
            row: row,
            column: column,
            classObject: classObject
        )
    }

    private func handleCellTap(_ cellData: GridCellData) {
        guard cellData.type == .interactive else { return }

        print("DEBUG GridComponent: Zelle angeklickt: Reihe \(cellData.row), Spalte \(cellData.column)")

        if cellData.state == .empty {
            selectedCellRow = cellData.row
            selectedCellColumn = cellData.column

            print("DEBUG GridComponent: Öffne AddClassModal für Position: Reihe \(selectedCellRow), Spalte \(selectedCellColumn)")

            showAddClassModal = true
        } else if cellData.state == .filled {
            if let classObj = cellData.classObject {
                selectedClass = classObj

                // Statt EditClassModal zu öffnen, zum Sitzplan wechseln
                print("DEBUG GridComponent: Wechsle zum Sitzplan für Klasse: \(classObj.name)")

                // Klassen-ID für Sitzplan in UserDefaults speichern
                UserDefaults.standard.set(classObj.id.uuidString, forKey: "selectedClassForSeatingPlan")

                // Zum Sitzplan-Tab wechseln
                selectedTab = 2 // 2 ist der Index für den Sitzplan-Tab
            }
        }
    }

    private func handleCellLongPress(_ cellData: GridCellData) {
        guard cellData.type == .interactive && cellData.state == .filled else { return }

        if let classObj = cellData.classObject {
            selectedClass = classObj

            print("DEBUG GridComponent: Öffne EditClassModal (Longpress) für Klasse: \(classObj.name)")

            showEditClassModal = true
        }
    }
}

struct AdaptiveGridCell: View {
    var data: GridCellData
    var showDebugControls: Bool
    var isLandscape: Bool = false
    var showNotes: Bool = true
    var calculatedWidth: CGFloat?
    var calculatedHeight: CGFloat?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .frame(width: cellWidth, height: cellHeight)
                .overlay(
                    Rectangle()
                        .stroke(data.state == .filled ? Color.gridLineColor : Color.gray.opacity(0.3),
                               lineWidth: 0.5)
                )

            VStack(spacing: 2) {
                if !data.text.isEmpty {
                    Text(data.text)
                        .font(.system(size: getFontSize()))
                        .fontWeight(getFontWeight())
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: cellWidth - 6, alignment: .center)
                }

                // Zeige Notizen nur wenn showNotes true ist und es Notizen gibt
                if showNotes && !data.secondaryText.isEmpty {
                    Text(data.secondaryText)
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: cellWidth - 6, alignment: .center)
                }
            }
            .padding(2) // Minimales Padding für bessere Platznutzung
            .frame(width: cellWidth, height: cellHeight)
        }
        .overlay(
            Group {
                #if DEBUG
                if showDebugControls {
                    Text("\(data.row),\(data.column)")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                        .padding(2)
                }
                #endif
            },
            alignment: .bottomTrailing
        )
    }
//
//    private var backgroundColor: Color {
//        switch data.type {
//        case .unusable:
//            return Color.gray.opacity(0.05)  // Kaum sichtbares Grau
//        case .columnHeader, .rowHeader:
//            return Color.gray.opacity(0.1)   // Sehr helles Grau für Überschriften
//        case .interactive:
//            switch data.state {
//            case .empty:
//                return Color.white            // Weiß für leere Zellen
//            case .filled:
//                return Color(red: 240/255, green: 248/255, blue: 255/255)  // Sehr dezentes Hellblau
//            case .editing:
//                return Color.orange.opacity(0.15)  // Sehr helles Orange
//            case .error:
//                return Color.red.opacity(0.15)     // Sehr helles Rot
//            }
//        }
//    }
//
//    private var textColor: Color {
//        switch data.type {
//        case .unusable:
//            return .gray
//        case .columnHeader, .rowHeader:
//            return .primary
//        case .interactive:
//            return data.state == .filled ? Color(red: 0/255, green: 90/255, blue: 180/255) : .gray  // Dunkleres Blau für Text in gefüllten Zellen
//        }
//    }

    private var backgroundColor: Color {
        switch data.type {
        case .unusable:
            return Color.gray.opacity(0.05)
        case .columnHeader, .rowHeader:
            return Color.gridHeaderBg  // Use your defined color
        case .interactive:
            switch data.state {
            case .empty:
                return Color.white
            case .filled:
                return Color.gridFilledCell  // Use your defined color
            case .editing:
                return Color.accentGreenLight  // Use your defined color for editing state
            case .error:
                return Color.red.opacity(0.15)
            }
        }
    }

    private var textColor: Color {
        switch data.type {
        case .unusable:
            return .gray
        case .columnHeader, .rowHeader:
            return .primary
        case .interactive:
            return data.state == .filled ? Color.gradePrimary : .gray  // Use your defined blue
        }
    }

    private func getFontSize() -> CGFloat {
        switch data.type {
        case .columnHeader:
            return 14
        case .rowHeader:
            return 14
        case .interactive:
            // Im Landscape-Modus kleinere Schrift für optimales Fitting
            return isLandscape ?
                   (calculatedHeight ?? 0) < 40 ? 14 : 16 :
                   16
        case .unusable:
            return 12
        }
    }

    private func getFontWeight() -> Font.Weight {
        switch data.type {
        case .columnHeader, .rowHeader:
            return .bold
        default:
            return .regular
        }
    }

    private var cellWidth: CGFloat {
        if let width = calculatedWidth {
            return width
        }

        switch data.type {
        case .rowHeader:
            return 40
        case .unusable:
            return 40
        case .columnHeader, .interactive:
            return 100
        }
    }

    private var cellHeight: CGFloat {
        if let height = calculatedHeight {
            return height
        }

        switch data.type {
        case .columnHeader:
            return 30
        case .unusable:
            return 30
        case .rowHeader, .interactive:
            return 50
        }
    }
}


//import SwiftUI
//
//enum CellType {
//    case unusable
//    case columnHeader
//    case rowHeader
//    case interactive
//}
//
//enum CellState {
//    case empty
//    case filled
//    case editing
//    case error
//}
//
//struct GridCellData {
//    var type: CellType
//    var state: CellState = .empty
//    var text: String = ""
//    var secondaryText: String = ""
//    var row: Int
//    var column: Int
//    var classObject: Class?
//}
//
//struct GridComponent: View {
//    @ObservedObject var viewModel: TimetableViewModel
//    @Binding var selectedTab: Int
//    @Binding var showDebugControls: Bool
//    @State private var selectedCellRow: Int = 0
//    @State private var selectedCellColumn: Int = 0
//    @State private var selectedClass: Class?
//    @State private var showAddClassModal = false
//    @State private var showEditClassModal = false
//    @State private var currentClasses: [Class] = []
//
//
//    private let rows = 13  // 1 Header + 12 Stunden
//    private let columns = 6  // 1 Header + 5 Tage
//
//    private let weekdays = ["", "Mo", "Di", "Mi", "Do", "Fr"]
//
//    init(viewModel: TimetableViewModel, showDebugControls: Binding<Bool>, selectedTab: Binding<Int> = .constant(0)) {
//        self.viewModel = viewModel
//        self._showDebugControls = showDebugControls
//        self._selectedTab = selectedTab
//    }
//
//    var body: some View {
//        VStack(spacing: 0) {
//            ScrollView([.horizontal, .vertical], showsIndicators: true) {
//                grid
//                    .padding()
//            }
//
//            // Debug-Info über aktuelle Klassen
//            #if DEBUG
//            if showDebugControls {
//                VStack(alignment: .leading) {
//                    Text("DEBUG: Aktive Klassen: \(viewModel.classes.count)")
//                        .font(.caption)
//                        .foregroundColor(.gray)
//
//                    ForEach(viewModel.classes) { classObj in
//                        Text("- \(classObj.name) an (\(classObj.row),\(classObj.column))")
//                            .font(.caption2)
//                            .foregroundColor(.gray)
//                    }
//                }
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding(.horizontal)
//                .padding(.bottom, 4)
//            }
//            #endif
//
//            // Fehleranzeige
//            if viewModel.showError, let errorMessage = viewModel.errorMessage {
//                Text(errorMessage)
//                    .foregroundColor(.red)
//                    .padding()
//            }
//        }
//        .onAppear {
//            print("DEBUG GridComponent: onAppear aufgerufen")
//            viewModel.loadClasses()
//        }
//        .onChange(of: viewModel.classes) { oldClasses, newClasses in
//            print("DEBUG GridComponent: classes geändert, Anzahl: \(newClasses.count)")
//            currentClasses = newClasses
//        }
//        .sheet(isPresented: $showAddClassModal) {
//            // Übergebe nur gültige Werte: Zeilen 1-12, Spalten 1-5
//            let validRow = max(1, min(12, selectedCellRow))
//            let validColumn = max(1, min(5, selectedCellColumn))
//
//            AddClassView(
//                row: validRow,
//                column: validColumn,
//                viewModel: viewModel,
//                isPresented: $showAddClassModal,
//                selectedTab: $selectedTab
//            )
//        }
//        .sheet(isPresented: $showEditClassModal) {
//            if let classObj = selectedClass {
//                EditClassView(class: classObj, viewModel: viewModel, isPresented: $showEditClassModal)
//            }
//        }
//        // Auslösen einer Aktualisierung, wenn Modal geschlossen wird
//        .onChange(of: showAddClassModal) { oldValue, isShowing in
//            if !isShowing {
//                print("DEBUG GridComponent: AddClassModal geschlossen, Aktualisiere Grid")
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    viewModel.loadClasses()
//                }
//            }
//        }
//        .onChange(of: showEditClassModal) { oldValue, isShowing in
//            if !isShowing {
//                print("DEBUG GridComponent: EditClassModal geschlossen, Aktualisiere Grid")
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    viewModel.loadClasses()
//                }
//            }
//        }
//    }
//
//    private var grid: some View {
//        VStack(spacing: 2) {
//            ForEach(0..<rows, id: \.self) { row in
//                HStack(spacing: 2) {
//                    ForEach(0..<columns, id: \.self) { column in
//                        let cellData = getCellData(row: row, column: column)
//                        GridCell(data: cellData, showDebugControls: showDebugControls)
//                            .onTapGesture {
//                                handleCellTap(cellData)
//                            }
//                            .onLongPressGesture {
//                                handleCellLongPress(cellData)
//                            }
//                    }
//                }
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
//    }
//
//    private func getCellData(row: Int, column: Int) -> GridCellData {
//        // Zelle (0,0) - unbenutzt
//        if row == 0 && column == 0 {
//            return GridCellData(type: .unusable, row: row, column: column)
//        }
//
//        // Erste Zeile (außer 0,0) - Spaltenüberschriften
//        if row == 0 {
//            return GridCellData(type: .columnHeader, text: weekdays[column], row: row, column: column)
//        }
//
//        // Erste Spalte - Zeilenüberschriften
//        if column == 0 {
//            return GridCellData(type: .rowHeader, text: "\(row)", row: row, column: column)
//        }
//
//        // Interaktive Zellen - manuelles Durchsuchen der Klassen
//        let classObject = currentClasses.first {
//            $0.row == row &&
//            $0.column == column &&
//            !$0.isArchived
//        }
//
//        let state: CellState = classObject != nil ? .filled : .empty
//
//        return GridCellData(
//            type: .interactive,
//            state: state,
//            text: classObject?.name ?? "",
//            secondaryText: classObject?.note ?? "",
//            row: row,
//            column: column,
//            classObject: classObject
//        )
//    }
//
//    private func handleCellTap(_ cellData: GridCellData) {
//        guard cellData.type == .interactive else { return }
//
//        print("DEBUG GridComponent: Zelle angeklickt: Reihe \(cellData.row), Spalte \(cellData.column)")
//
//        if cellData.state == .empty {
//            selectedCellRow = cellData.row
//            selectedCellColumn = cellData.column
//
//            print("DEBUG GridComponent: Öffne AddClassModal für Position: Reihe \(selectedCellRow), Spalte \(selectedCellColumn)")
//
//            showAddClassModal = true
//        } else if cellData.state == .filled {
//            if let classObj = cellData.classObject {
//                selectedClass = classObj
//
//                // Statt EditClassModal zu öffnen, zum Sitzplan wechseln
//                print("DEBUG GridComponent: Wechsle zum Sitzplan für Klasse: \(classObj.name)")
//
//                // Klassen-ID für Sitzplan in UserDefaults speichern
//                UserDefaults.standard.set(classObj.id.uuidString, forKey: "selectedClassForSeatingPlan")
//
//                // Zum Sitzplan-Tab wechseln
//                selectedTab = 2 // 2 ist der Index für den Sitzplan-Tab
//
//                // NICHT mehr das Modal öffnen:
//                // showEditClassModal = true
//            }
//        }
//    }
//
//    private func handleCellLongPress(_ cellData: GridCellData) {
//        guard cellData.type == .interactive && cellData.state == .filled else { return }
//
//        if let classObj = cellData.classObject {
//            selectedClass = classObj
//
//            print("DEBUG GridComponent: Öffne EditClassModal (Longpress) für Klasse: \(classObj.name)")
//
//            showEditClassModal = true
//        }
//    }
//}
//
//struct GridCell: View {
//    var data: GridCellData
//    var showDebugControls: Bool
//
//    // Standardinitialisierung für die neue Variable
//        init(data: GridCellData, showDebugControls: Bool = false) {
//            self.data = data
//            self.showDebugControls = showDebugControls
//        }
//
//    var body: some View {
//        ZStack {
//            Rectangle()
//                .fill(backgroundColor)
//                .frame(width: cellWidth, height: cellHeight)
//                .border(Color.gray.opacity(0.5), width: 0.5)
//
//            VStack {
//                if !data.text.isEmpty {
//                    Text(data.text)
//                        .font(.system(size: getFontSize()))
//                        .fontWeight(getFontWeight())
//                        .foregroundColor(textColor)
//                        .lineLimit(1)
//                        .truncationMode(.tail)
//                        .frame(width: cellWidth - 10, alignment: .center) // Feste Breite minus Padding
//                }
//
//                if !data.secondaryText.isEmpty {
//                    Text(data.secondaryText)
//                        .font(.system(size: 10))
//                        .foregroundColor(textColor.opacity(0.8))
//                        .lineLimit(1)
//                        .truncationMode(.tail)
//                        .frame(width: cellWidth - 10, alignment: .center) // Feste Breite minus Padding
//                }
//            }
//            .padding(5)
//            .frame(width: cellWidth, height: cellHeight) // Wichtig: Die gesamte VStack auf feste Größe beschränken
//        }
//        .overlay(
//            Group {
//                #if DEBUG
//                if showDebugControls {
//                    Text("\(data.row),\(data.column)")
//                        .font(.system(size: 8))
//                        .foregroundColor(.gray)
//                        .padding(2)
//                }
//                #endif
//            },
//            alignment: .bottomTrailing
//        )
//    }
//
//    private var backgroundColor: Color {
//        switch data.type {
//        case .unusable:
//            return Color.dividerGray
//        case .columnHeader, .rowHeader:
//            return Color.backgroundGray
//        case .interactive:
//            switch data.state {
//            case .empty:
//                return Color.white
//            case .filled:
//                return Color.gradeLight  // Verwende unser definiertes helles Blau
//            case .editing:
//                return Color.heroLight   // Verwende unser definiertes helles Orange
//            case .error:
//                return Color.red.opacity(0.3)
//            }
//        }
//    }
//
//    private var textColor: Color {
//        switch data.type {
//        case .unusable:
//            return .gray
//        case .columnHeader, .rowHeader:
//            return .primary
//        case .interactive:
//            return data.state == .filled ? .gradePrimary : .gray  // Blauer Text für gefüllte Zellen
//        }
//    }
//
//    private func getFontSize() -> CGFloat {
//        switch data.type {
//        case .columnHeader, .rowHeader:
//            return 16
//        case .interactive:
//            return 18
//        case .unusable:
//            return 12
//        }
//    }
//
//    private func getFontWeight() -> Font.Weight {
//        switch data.type {
//        case .columnHeader, .rowHeader:
//            return .bold
//        default:
//            return .regular
//        }
//    }
//
//    private var cellWidth: CGFloat {
//        switch data.type {
//        case .rowHeader:
//            return 45
//        case .unusable:
//            return 45
//        case .columnHeader:
//            return 110
//        case .interactive:
//            return 110
//        }
//    }
//
//    private var cellHeight: CGFloat {
//        switch data.type {
//        case .columnHeader:
//            return 40
//        case .unusable:
//            return 40
//        case .rowHeader:
//            return 65
//        case .interactive:
//            return 65
//        }
//    }
//}
