//
//  ClassSelectionView.swift
//  hero4
//
//  Created by Nina Klee on 22.03.25.
//

import Foundation
import SwiftUI

struct ClassSelectionView: View {
    let classes: [Class] // Angenommen, Class ist dein Modell mit id und name
    let onClassSelected: (UUID) -> Void // Callback für die Auswahl
    var onCancel: (() -> Void)? = nil  // Neue optionale onCancel-Funktion
    @State private var errorMessage: String? = nil  // Für Fehleranzeige
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                // Fehleranzeige hinzufügen
                if let error = errorMessage {
                    VStack(spacing: 10) {
                        Text("Fehler")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)

                        Text("Bitte wählen Sie eine andere Klasse oder passen Sie Ihre Auswahl an.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.white) // Hintergrundfarbe sicherstellen
                }

                List(classes) { classItem in
                    Button(action: {
                        onClassSelected(classItem.id)
                    }) {
                        HStack {
                            Text(classItem.name)
                            Spacer()
                            if let note = classItem.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                // Abbrechen-Button hinzufügen, wenn onCancel bereitgestellt wird
                if onCancel != nil {
                    Button("Abbrechen") {
                        onCancel?()
                    }
                    .padding()
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Klasse auswählen")
            .navigationBarItems(trailing: Button("Schließen") {
                if let cancel = onCancel {
                    cancel()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            })
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClassSelectionError"))) { notification in
                if let message = notification.userInfo?["message"] as? String {
                    errorMessage = message
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClassSelectionClearError"))) { _ in
                // Fehler zurücksetzen
                errorMessage = nil
            }
            .onAppear {
                // Beim Erscheinen des Modals auch den Fehler zurücksetzen
                errorMessage = nil
            }
            .navigationViewStyle(StackNavigationViewStyle()) // Erzwinge Vollbildmodus
            .frame(minWidth: 320, minHeight: 400) // Minimale Größe sicherstellen

        }
    }
}
