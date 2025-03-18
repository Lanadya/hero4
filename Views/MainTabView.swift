import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

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

            // Verwendung der neuen, einfachen View
            SimpleSeatingView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Sitzplan", systemImage: "rectangle.grid.2x2")
                }
                .tag(2)

            Text("Ergebnisse (Wird noch implementiert)")
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
        .onAppear {
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
}
