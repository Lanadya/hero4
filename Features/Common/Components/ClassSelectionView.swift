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
    @Environment(\.dismiss) private var dismiss
    
    // iPad-specific layout constants
    private let iPadMinWidth: CGFloat = 400
    private let iPadMaxWidth: CGFloat = 600
    private let iPadMinHeight: CGFloat = 500

    var body: some View {
        NavigationStack {
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
                                .font(.headline)
                            Spacer()
                            if let note = classItem.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") {
                        if let cancel = onCancel {
                            cancel()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
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
        }
        .frame(minWidth: iPadMinWidth, maxWidth: iPadMaxWidth, minHeight: iPadMinHeight)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
