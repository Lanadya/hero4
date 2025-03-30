//
//  CompactClassListView.swift
//  hero4
//
//  Created by Nina Klee on 29.03.25.
//

import Foundation
import SwiftUI

struct CompactClassListView: View {
    // Required parameters
    let classes: [Class]
    let selectedClassId: UUID?
    let onClassSelected: (UUID) -> Void

    // Optional parameters
    var title: String = ""

    // Grouped classes by weekday
    private var classesByWeekday: [(weekday: String, classes: [Class])] {
        let weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]

        var result: [(weekday: String, classes: [Class])] = []

        for (index, weekday) in weekdays.enumerated() {
            let column = index + 1
            let classesForDay = classes.filter {
                $0.column == column && !$0.isArchived
            }.sorted { $0.row < $1.row }

            if !classesForDay.isEmpty {
                result.append((weekday: weekday, classes: classesForDay))
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            List {
                ForEach(classesByWeekday, id: \.weekday) { group in
                    Section(header: Text(group.weekday)) {
                        ForEach(group.classes) { classObj in
                            Button(action: {
                                onClassSelected(classObj.id)
                            }) {
                                HStack {
                                    Text(classObj.name)
                                        .foregroundColor(.primary)

                                    if let note = classObj.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    if selectedClassId == classObj.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
}
