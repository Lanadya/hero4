//
//  TestAlertView.swift
//  hero4
//
//  Created by Nina Klee on 24.03.25.
//

import Foundation
import SwiftUI

struct TestAlertView: View {
    @State private var showAlert = false
    var body: some View {
        Button("Test Alert") {
            showAlert = true
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Hallo"), message: Text("Dies ist ein Test"), dismissButton: .default(Text("OK")))
        }
    }
}
