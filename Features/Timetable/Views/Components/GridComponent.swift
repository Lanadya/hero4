import SwiftUI
import CorePackage
// Import the centralized color definitions from ColorExtensions.swift directly
// until proper module system is set up

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

struct GridCellData: Identifiable {
    let id = UUID()
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
    @State private var isLandscape: Bool = false
    @State private var showNotes: Bool = false
    @State private var needsScrolling: Bool = false
    
    // iPad-specific layout constants
    private let iPadMinCellWidth: CGFloat = 120
    private let iPadMaxCellWidth: CGFloat = 200
    private let iPadMinCellHeight: CGFloat = 60
    private let iPadMaxCellHeight: CGFloat = 80
    private let iPadHeaderHeight: CGFloat = 40
    
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
            VStack(spacing: 0) {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    grid
                        .padding()
                }
                
                #if DEBUG
                if showDebugControls {
                    debugInfo
                }
                #endif
                
                if viewModel.showError, let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                }
            }
            .onAppear {
                viewModel.loadClasses()
                updateLayout(for: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                updateLayout(for: newSize)
            }
            .onChange(of: viewModel.classes) { _, newClasses in
                currentClasses = newClasses
            }
        }
        .sheet(isPresented: $showAddClassModal) {
            AddClassView(
                row: max(1, min(12, selectedCellRow)),
                column: max(1, min(5, selectedCellColumn)),
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
    }
    
    private var grid: some View {
        VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<columns, id: \.self) { column in
                        let cellData = getCellData(row: row, column: column)
                        GridCell(data: cellData, showDebugControls: showDebugControls)
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
    
    private var debugInfo: some View {
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
        .padding(.bottom, 4)
    }
    
    private func errorView(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
            .padding()
    }
    
    private func updateLayout(for size: CGSize) {
        isLandscape = size.width > size.height
        let availableHeight = size.height - (showDebugControls ? 60 : 20)
        let maxRowHeight = (availableHeight - iPadHeaderHeight) / 12
        let interactiveCellWidth = (size.width - 50) / 5
        
        showNotes = isLandscape ?
            interactiveCellWidth >= iPadMinCellWidth && maxRowHeight >= iPadMinCellHeight :
            interactiveCellWidth >= iPadMinCellWidth * 0.8 && maxRowHeight >= iPadMinCellHeight
        
        needsScrolling = (iPadHeaderHeight + (maxRowHeight * 12)) > availableHeight
    }
    
    private func getCellData(row: Int, column: Int) -> GridCellData {
        if row == 0 && column == 0 {
            return GridCellData(type: .unusable, row: row, column: column)
        }
        
        if row == 0 {
            return GridCellData(type: .columnHeader, text: weekdays[column], row: row, column: column)
        }
        
        if column == 0 {
            return GridCellData(type: .rowHeader, text: "\(row)", row: row, column: column)
        }
        
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
        
        if cellData.state == .empty {
            selectedCellRow = cellData.row
            selectedCellColumn = cellData.column
            showAddClassModal = true
        } else if cellData.state == .filled {
            if let classObj = cellData.classObject {
                selectedClass = classObj
                UserDefaults.standard.set(classObj.id.uuidString, forKey: "selectedClassForSeatingPlan")
                selectedTab = 2
            }
        }
    }
    
    private func handleCellLongPress(_ cellData: GridCellData) {
        guard cellData.type == .interactive && cellData.state == .filled else { return }
        
        if let classObj = cellData.classObject {
            selectedClass = classObj
            showEditClassModal = true
        }
    }
}

struct GridCell: View {
    var data: GridCellData
    var showDebugControls: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .frame(width: cellWidth, height: cellHeight)
                .border(Color.gray.opacity(0.5), width: 0.5)
            
            VStack {
                if !data.text.isEmpty {
                    Text(data.text)
                        .font(.system(size: getFontSize()))
                        .fontWeight(getFontWeight())
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: cellWidth - 10, alignment: .center)
                }
                
                if !data.secondaryText.isEmpty {
                    Text(data.secondaryText)
                        .font(.system(size: 10))
                        .foregroundColor(textColor.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: cellWidth - 10, alignment: .center)
                }
            }
            .padding(5)
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
    
    private var backgroundColor: Color {
        switch data.type {
        case .unusable:
            return Color.dividerGray
        case .columnHeader, .rowHeader:
            return Color.backgroundGray
        case .interactive:
            switch data.state {
            case .empty:
                return Color.white
            case .filled:
                return Color.gradeLight
            case .editing:
                return Color.heroLight
            case .error:
                return Color.red.opacity(0.3)
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
            return data.state == .filled ? .gradePrimary : .gray
        }
    }
    
    private func getFontSize() -> CGFloat {
        switch data.type {
        case .columnHeader, .rowHeader:
            return 16
        case .interactive:
            return 18
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
        switch data.type {
        case .rowHeader, .unusable:
            return 45
        case .columnHeader, .interactive:
            return 110
        }
    }
    
    private var cellHeight: CGFloat {
        switch data.type {
        case .columnHeader, .unusable:
            return 40
        case .rowHeader, .interactive:
            return 65
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
