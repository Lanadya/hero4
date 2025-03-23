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

    var body: some View {
        NavigationView {
            List(classes) { classItem in
                Button(action: {
                    onClassSelected(classItem.id)
                }) {
                    Text(classItem.name)
                }
            }
            .navigationTitle("Klasse auswählen")
        }
    }
}
