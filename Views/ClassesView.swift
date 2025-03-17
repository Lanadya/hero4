import SwiftUI

struct ClassesView: View {
    @StateObject private var viewModel = TimetableViewModel()
    @State private var showingInfoAlert = false
    @Binding var selectedTab: Int

    // Optionaler Parameter für selectedTab
    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("GRADE Hero Stundenplan")
                    .font(.title)
                    .padding(.top)

                GridComponent(viewModel: viewModel, selectedTab: $selectedTab)
                    .padding()

                // Debug-Buttons während der Entwicklung
                #if DEBUG
                HStack {
                    Button(action: {
                        viewModel.addSampleData()
                    }) {
                        Text("Beispieldaten")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        viewModel.resetAllData()
                    }) {
                        Text("Zurücksetzen")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        showingInfoAlert = true
                    }) {
                        Text("Info")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom)
                #endif

                Spacer()
            }
            .alert(isPresented: $showingInfoAlert) {
                Alert(
                    title: Text("App-Information"),
                    message: Text("GRADE Hero ist eine App zur Verwaltung mündlicher Noten. Tippen Sie auf eine leere Zelle, um eine neue Klasse hinzuzufügen."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(viewModel.errorMessage ?? "Unbekannter Fehler"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadClasses()
        }
    }
}
