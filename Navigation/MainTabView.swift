import SwiftUI
import Combine

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var appState = AppState.shared

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
