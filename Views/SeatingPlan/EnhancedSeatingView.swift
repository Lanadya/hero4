import SwiftUI

struct EnhancedSeatingView: View {
    @StateObject private var viewModel = EnhancedSeatingViewModel()
    @Binding var selectedTab: Int
    @State private var showClassPicker = false
    @State private var editMode = false
    @State private var isFullscreen = false
    @State private var showModeSwitchInfo = false

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

                // Info-Toast beim Moduswechsel
                if showModeSwitchInfo {
                    VStack {
                        Spacer().frame(height: 60)

                        HStack {
                            Image(systemName: editMode ? "arrow.up.and.down.and.arrow.left.and.right" : "pencil")
                                .foregroundColor(.white)
                            Text(editMode ? "Positioniere Schüler durch Ziehen" : "Tippe auf Buttons, um Noten zu vergeben")
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                        .transition(.move(edge: .top).combined(with: .opacity))

                        Spacer()
                    }
                    .zIndex(100)
                    .animation(.easeInOut, value: showModeSwitchInfo)
                    .onAppear {
                        // Info-Toast nach 3 Sekunden ausblenden
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showModeSwitchInfo = false
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Sitzplan", displayMode: .inline)
            .navigationBarHidden(true)
            .sheet(isPresented: $showClassPicker) {
                SeatingClassPicker(viewModel: viewModel)
            }
            .onAppear {
                // Verfügbare Klassen laden
                viewModel.loadClasses()

                // Falls keine Klasse ausgewählt ist, aber Klassen vorhanden sind, wähle die erste
                if viewModel.selectedClass == nil && !viewModel.classes.isEmpty {
                    viewModel.selectClass(viewModel.classes[0].id)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Seating Class Picker
// Diese Komponente ist speziell für den EnhancedSeatingViewModel, um Konflikte mit ClassPickerView zu vermeiden
struct SeatingClassPicker: View {
    @ObservedObject var viewModel: EnhancedSeatingViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.classes) { classObj in
                    Button(action: {
                        viewModel.selectClass(classObj.id)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(classObj.name)
                                    .font(.headline)

                                if let note = classObj.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            if viewModel.selectedClass?.id == classObj.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Klasse auswählen", displayMode: .inline)
            .navigationBarItems(trailing: Button("Fertig") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
