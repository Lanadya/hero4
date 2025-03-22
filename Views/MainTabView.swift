import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            ClassesView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Klassen", systemImage: "calendar")
                }
                .tag(0)

            StudentsListView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Schüler", systemImage: "person.3")
                }
                .tag(1)

            // Hier verwenden wir jetzt die neue, verbesserte EnhancedSeatingView
            EnhancedSeatingView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Sitzplan", systemImage: "rectangle.grid.2x2")
                }
                .tag(2)

            // Die implementierte ResultsView verwenden
            ResultsView()
                .tabItem {
                    Label("Noten", systemImage: "list.bullet")
                }
                .tag(3)

            Text("Archiv (Wird noch implementiert)")
                .tabItem {
                    Label("Archiv", systemImage: "archivebox")
                }
                .tag(4)
        }
        .onChange(of: appState.shouldNavigateToStudentsList) { shouldNavigate in
            if shouldNavigate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedTab = 1 // Zur Schülerliste navigieren
                    appState.shouldNavigateToStudentsList = false
                }
            }
        }
        .onAppear {
            checkForNavigationRequests()
        }
    }

    private func checkForNavigationRequests() {
        // Prüfen, ob wir von einer Klassen-Erstellung kommen und zur Schülerliste wechseln sollen
        if let navigateToStudents = UserDefaults.standard.object(forKey: "navigateToStudentsTab") as? Bool,
           navigateToStudents == true {
            // Verzögerung für bessere Animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedTab = 1 // Zur Schülerliste wechseln
                UserDefaults.standard.removeObject(forKey: "navigateToStudentsTab")
            }
        }
    }
}
