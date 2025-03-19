import SwiftUI

struct EnhancedSeatingView: View {
    @StateObject private var viewModel = EnhancedSeatingViewModel()
    @Binding var selectedTab: Int
    @State private var showClassPicker = false
    @State private var editMode: Bool = false
    @State private var isFullscreen: Bool = false

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Header (nur wenn nicht im Vollbildmodus)
                    if !isFullscreen {
                        SP_HeaderView(
                            viewModel: viewModel,
                            showClassPicker: $showClassPicker,
                            editMode: $editMode,
                            isFullscreen: $isFullscreen
                        )
                    }

                    // Content area
                    SP_ContentView(
                        viewModel: viewModel,
                        selectedTab: $selectedTab,
                        showClassPicker: $showClassPicker,
                        editMode: editMode,
                        isFullscreen: isFullscreen
                    )
                }

                // Vollbildmodus-X in der oberen rechten Ecke (nur im Vollbildmodus)
                if isFullscreen {
                    SP_ExitButton(isFullscreen: $isFullscreen)
                }
            }
            .navigationBarTitle("Sitzplan", displayMode: .inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showClassPicker) {
                SP_ClassPickerView(viewModel: viewModel)
            }
            .onAppear {
                // Lade verfügbare Klassen
                viewModel.loadClasses()

                // Falls keine Klasse ausgewählt ist, wähle die erste
                if viewModel.selectedClass == nil && !viewModel.classes.isEmpty {
                    if let firstClass = viewModel.classes.first {
                        viewModel.selectClass(firstClass.id)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .statusBar(hidden: isFullscreen)
        // TabBar ausblenden im Vollbildmodus
        .onAppear {
            if isFullscreen {
                UITabBar.appearance().isHidden = true
            } else {
                UITabBar.appearance().isHidden = false
            }
        }
        .onChange(of: isFullscreen) { newValue in
            UITabBar.appearance().isHidden = newValue
        }
    }
}
