import SwiftUI
import Combine
import CorePackage
import GRDB

// Zugriff auf den BackupManager
// Diese Referenz stellt sicher, dass der BackupManager korrekt importiert wird
private let backupManager = BackupManager.shared

// BackupManager Referenz
extension BackupManager {
    // Referenz, um den BackupManager in diesem Modul zugänglich zu machen
}

// Custom import für Debug-Funktionalität
struct DebugViewImport {
    // Hilfsklasse für den Import
    static let debugView = { () -> Any.Type in
        return DebugView.self
    }
}

// Einfache Debug-View ohne komplexe Abhängigkeiten
fileprivate struct DebugView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Debug-Tools")
                    .font(.title)
                
                Divider()
                
                Button("Backup erstellen (nicht funktional)") {
                    message = "Diese Funktion ist noch nicht implementiert"
                }
                .buttonStyle(.borderedProminent)
                
                if !message.isEmpty {
                    Text(message)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .toolbar {
                Button("Schließen") {
                    dismiss()
                }
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var appState = AppState.shared
    @State private var showDebugView = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ClassesView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Klassen", systemImage: "calendar")
                    }
                    .tag(0)
                    .environmentObject(appState)

                StudentsListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Schüler", systemImage: "person.3")
                    }
                    .tag(1)
                    .environmentObject(appState)

                EnhancedSeatingView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Sitzplan", systemImage: "rectangle.grid.2x2")
                    }
                    .tag(2)
                    .environmentObject(appState)

                ResultsView()
                    .tabItem {
                        Label("Noten", systemImage: "list.bullet")
                    }
                    .tag(3)
                    .environmentObject(appState)

                ArchiveView()
                    .tabItem {
                        Label("Archiv", systemImage: "archivebox")
                    }
                    .tag(4)
                    .environmentObject(appState)
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                // Debug-Button - nur in der Entwicklung sichtbar
                                #if DEBUG
                                Button(action: {
                                    appState.activateDebugMode()
                                }) {
                                    Image(systemName: "ladybug.fill")
                                        .foregroundColor(.clear)
                                        .frame(width: 30, height: 30)
                                        .contentShape(Rectangle())
                                }
                                .padding(8)
                                #endif
                            }
                            Spacer()
                        }
                    )
            }
            .accentColor(Color.heroSecondary)
            .environmentObject(appState)
            .onChange(of: appState.shouldNavigateToStudentsList) { oldValue, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTab = 1
                        appState.shouldNavigateToStudentsList = false
                    }
                }
            }
            .onAppear {
                checkForNavigationRequests()
            }
            
            // Einfacher Ladeindikator, der auf appState.isAppBusy reagiert
            if appState.isAppBusy {
                VStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.trailing, 8)
                            .padding(.top, 4)
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $appState.showDebugView) {
            DebugView()
        }
    }

    private func checkForNavigationRequests() {
        if let navigateToStudents = UserDefaults.standard.object(forKey: "navigateToStudentsTab") as? Bool,
           navigateToStudents == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedTab = 1
                UserDefaults.standard.removeObject(forKey: "navigateToStudentsTab")
            }
        }
    }
}
