import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ClassesView()
                .tabItem {
                    Label("Klassen", systemImage: "calendar")
                }
                .tag(0)

            StudentsListView()
                .tabItem {
                    Label("Schüler", systemImage: "person.3")
                }
                .tag(1)

            Text("Sitzplan (Wird noch implementiert)")
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
    }
}
