//
//  StudentRow.swift
//  hero4
//
//  Created by Nina Klee on 27.03.25.
//

import Foundation
import SwiftUI

struct StudentsRow: View {
    let student: Student
    let isSelected: Bool
    let editMode: EditMode
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Selection checkbox (only when in edit mode)
                if editMode == .active {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .padding(.trailing, 4)
                }

                // Student info
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.fullName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let notes = student.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Chevron (when not in edit mode)
                if editMode == .inactive {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
        // Falls im Bearbeitungsmodus, ignoriere die Klick-Geste für den gesamten Eintrag
        // nur das Checkbox-Symbol soll klickbar sein
        .allowsHitTesting(editMode == .inactive || (editMode == .active && isSelected == false))
    }
}
