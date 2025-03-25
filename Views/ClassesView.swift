import SwiftUI

struct ClassesView: View {
    @StateObject private var viewModel = TimetableViewModel()
    @State private var showDebugControls = false
    @Binding var selectedTab: Int
    @State private var showInfoDialog = false  // Only for the button-triggered info
    @State private var showFirstLaunchInfo = false  // Only for the first-launch overlay
    @State private var activeAlert: AlertType? = nil

    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    HeaderView(showInfoDialog: $showInfoDialog)
                    GridComponent(viewModel: viewModel, showDebugControls: $showDebugControls, selectedTab: $selectedTab)
                        .padding()
                    #if DEBUG
                    DebugControlsView(showDebugControls: $showDebugControls, viewModel: viewModel, activeAlert: $activeAlert)
                    #endif
                    Spacer()
                }

                // First launch overlay with the teal color you prefer
                if showFirstLaunchInfo {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .center, spacing: 16) {
                                Image(systemName: "hand.tap")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)

                                Text("Tippen Sie auf eine Zelle, um eine neue Klasse anzulegen")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.heroSecondary.opacity(0.9))
                            )
                            .shadow(radius: 8)
                            .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showFirstLaunchInfo = false
                    }
                }

                // Info dialog - only appears when the info button is pressed
                if showInfoDialog {
                    InfoDialogView(
                        isPresented: $showInfoDialog,
                        title: "Erste Schritte",
                        content: "• Tippen Sie auf eine leere Zelle, um eine neue Klasse anzulegen\n\n• Tippen Sie auf eine vorhandene Klasse, um direkt zum Sitzplan zu gelangen\n\n• Halten Sie eine Klasse länger gedrückt, um sie zu bearbeiten",
                        buttonText: "Schließen"
                    )
                }
            }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .info:
                    return Alert(
                        title: Text("App-Information"),
                        message: Text("GRADE Hero ist eine App zur Verwaltung mündlicher Noten. Tippen Sie auf eine leere Zelle, um eine neue Klasse hinzuzufügen."),
                        dismissButton: .default(Text("OK"))
                    )
                case .error(let errorMessage):
                    return Alert(
                        title: Text("Fehler"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarHidden(true)
            .onAppear {
                // First launch detection - now ONLY showing the overlay
                if !UserDefaults.standard.bool(forKey: "hasSeenIntroduction") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // ONLY show the first launch overlay, not both
                        showFirstLaunchInfo = true
                        // Do NOT set showInfoDialog = true here

                        // Mark as seen
                        UserDefaults.standard.set(true, forKey: "hasSeenIntroduction")
                        UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
                        UserDefaults.standard.set(true, forKey: "hasSeenOverlay")
                        UserDefaults.standard.set(true, forKey: "hasSeenHint")
                    }
                }

                if viewModel.showError, let errorMessage = viewModel.errorMessage {
                    activeAlert = .error(errorMessage)
                    viewModel.showError = false
                }
            }
            .onChange(of: viewModel.showError) { _, newValue in
                if newValue, let errorMessage = viewModel.errorMessage {
                    activeAlert = .error(errorMessage)
                    viewModel.showError = false
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadClasses()
        }
    }
}

// HeaderView remains the same
struct HeaderView: View {
    @Binding var showInfoDialog: Bool

    var body: some View {
        HStack {
            HStack(spacing: 0) {
                Text("GRADE")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.gradePrimary)
                Text("HERO")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.heroSecondary)
            }
            Spacer()
            Button(action: {
                showInfoDialog = true
            }) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.heroSecondary)
                    .padding(6)
                    .background(Color.heroSecondaryLight)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Debug controls remain the same
struct DebugControlsView: View {
    @Binding var showDebugControls: Bool
    @ObservedObject var viewModel: TimetableViewModel
    @Binding var activeAlert: AlertType?

    var body: some View {
        HStack {
            Button(action: {
                showDebugControls.toggle()
            }) {
                Image(systemName: showDebugControls ? "ladybug.fill" : "ladybug")
                    .font(.system(size: 16))
                    .foregroundColor(.gradePrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gradePrimaryLight)
                    .cornerRadius(8)
            }
            if showDebugControls {
                Button(action: {
                    viewModel.addSampleData()
                }) {
                    Text("Beispieldaten")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.heroSecondaryLight)
                        .foregroundColor(.heroSecondary)
                        .cornerRadius(8)
                }
                Button(action: {
                    viewModel.resetAllData()
                }) {
                    Text("Zurücksetzen")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentSandLight)
                        .foregroundColor(.accentSand)
                        .cornerRadius(8)
                }
                Button(action: {
                    activeAlert = .info
                }) {
                    Text("Info")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.heroSecondaryLight)
                        .foregroundColor(.heroSecondary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.bottom)
    }
}


//import SwiftUI
//
//struct ClassesView: View {
//    @StateObject private var viewModel = TimetableViewModel()
//    @State private var showDebugControls = false
//    @Binding var selectedTab: Int
//
//    // Zustand für den benutzerdefinierten Info-Dialog
//    @State private var showInfoDialog = false
//
//    // Ein einziger Alert-Zustand für Fehler-Alerts
//    @State private var activeAlert: AlertType? = nil
//
//    // Optionaler Parameter für selectedTab
//    init(selectedTab: Binding<Int> = .constant(0)) {
//        self._selectedTab = selectedTab
//    }
//
//    var body: some View {
//        NavigationView {
//            ZStack {
//                VStack {
//                    // AKTUALISIERTER HEADER: GRADE HERO Titel mit deutlichem Info-Button
//                    HStack {
//                        // Haupttitel in zwei Farben für bessere Ästhetik
//                        HStack(spacing: 0) {
//                            Text("GRADE")
//                                .font(.system(size: 26, weight: .bold))
//                                .foregroundColor(.gradePrimary)
//                            Text("HERO")
//                                .font(.system(size: 26, weight: .bold))
//                                .foregroundColor(.heroSecondary)
//                        }
//
//                        Spacer()
//
//                        // Deutlich sichtbarer Info-Button
//                        Button(action: {
//                            showInfoDialog = true
//                        }) {
//                            Image(systemName: "info.circle.fill")
//                                .font(.system(size: 22))
//                                .foregroundColor(.heroSecondary)
//                                .padding(6)
//                                .background(.heroSecondaryLight)
//                                .clipShape(Circle())
//                        }
//                    }
//                    .padding(.horizontal)
//                    .padding(.vertical, 12)
//                    .background(Color.white)
//                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
//
//                    // BESTEHENDER CODE - Die GridComponent bleibt hier und wird nicht dupliziert
//                    GridComponent(viewModel: viewModel, showDebugControls: $showDebugControls, selectedTab: $selectedTab)
//                        .padding()
//
//                    // Debug-Buttons (bestehender Code mit Toggle)
//                    #if DEBUG
//                    HStack {
//                        Button(action: {
//                            showDebugControls.toggle()
//                        }) {
//                            Image(systemName: showDebugControls ? "ladybug.fill" : "ladybug")
//                                .font(.system(size: 16))
//                                .foregroundColor(.gray)
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 6)
//                                .background(Color.gray.opacity(0.1))
//                                .cornerRadius(8)
//                        }
//
//                        if showDebugControls {
//                            Button(action: {
//                                viewModel.addSampleData()
//                            }) {
//                                Text("Beispieldaten")
//                                    .font(.caption)
//                                    .padding(.horizontal, 12)
//                                    .padding(.vertical, 6)
//                                    .background(.heroSecondaryLight)
//                                    .cornerRadius(8)
//                            }
//
//                            Button(action: {
//                                viewModel.resetAllData()
//                            }) {
//                                Text("Zurücksetzen")
//                                    .font(.caption)
//                                    .padding(.horizontal, 12)
//                                    .padding(.vertical, 6)
//                                    .background(Color.red.opacity(0.1))
//                                    .cornerRadius(8)
//                            }
//
//                            Button(action: {
//                                activeAlert = .info
//                            }) {
//                                Text("Info")
//                                    .font(.caption)
//                                    .padding(.horizontal, 12)
//                                    .padding(.vertical, 6)
//                                    .background(Color.green.opacity(0.1))
//                                    .cornerRadius(8)
//                            }
//                        }
//                    }
//                    .padding(.bottom)
//                    #endif
//
//                    Spacer()
//                }
//
//                // Überlagert die gesamte View mit dem Info-Dialog wenn aktiv
//                if showInfoDialog {
//                    InfoDialogView(
//                        isPresented: $showInfoDialog,
//                        title: "Erste Schritte",
//                        content: "• Tippen Sie auf eine leere Zelle, um eine neue Klasse anzulegen\n\n• Tippen Sie auf eine vorhandene Klasse, um direkt zum Sitzplan zu gelangen\n\n• Halten Sie eine Klasse länger gedrückt, um sie zu bearbeiten",
//                        buttonText: "Schließen"
//                    )
//                }
//            }
//            .alert(item: $activeAlert) { alertType in
//                switch alertType {
//                case .info:
//                    return Alert(
//                        title: Text("App-Information"),
//                        message: Text("GRADE Hero ist eine App zur Verwaltung mündlicher Noten. Tippen Sie auf eine leere Zelle, um eine neue Klasse hinzuzufügen."),
//                        dismissButton: .default(Text("OK"))
//                    )
//                case .error(let errorMessage):
//                    return Alert(
//                        title: Text("Fehler"),
//                        message: Text(errorMessage),
//                        dismissButton: .default(Text("OK"))
//                    )
//                }
//            }
//            .navigationBarTitle("", displayMode: .inline)
//            .navigationBarHidden(true)
//            .onAppear {
//                // Prüfe, ob die App zum ersten Mal gestartet wird
//                if !UserDefaults.standard.bool(forKey: "hasSeenIntroduction") {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                        // Markiere, dass der Nutzer die Einführung gesehen hat
//                        UserDefaults.standard.set(true, forKey: "hasSeenIntroduction")
//                        // Zeige den Hilfe-Dialog
//                        showInfoDialog = true
//                    }
//
//                    // Deaktiviere andere konkurrierende Intros (falls vorhanden)
//                    // Wir setzen diese UserDefaults-Schlüssel, die möglicherweise für andere Intros verwendet werden
//                    UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
//                    UserDefaults.standard.set(true, forKey: "hasSeenOverlay")
//                    UserDefaults.standard.set(true, forKey: "hasSeenHint")
//                }
//
//                // Beobachter für Fehlermeldungen vom ViewModel hinzufügen
//                if viewModel.showError, let errorMessage = viewModel.errorMessage {
//                    activeAlert = .error(errorMessage)
//                    viewModel.showError = false
//                }
//            }
//            .onChange(of: viewModel.showError) { _, newValue in
//                if newValue, let errorMessage = viewModel.errorMessage {
//                    activeAlert = .error(errorMessage)
//                    viewModel.showError = false
//                }
//            }
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//        .onAppear {
//            viewModel.loadClasses()
//        }
//    }
//}
