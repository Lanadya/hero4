//
//  AppState.swift
//  hero4
//
//  Created by Nina Klee on 22.03.25.
//

import Foundation
import SwiftUI
import Combine

// A simple class to share state across the app
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var lastCreatedClassId: UUID?
    @Published var shouldNavigateToStudentsList = false
    @Published var shouldSelectClassInStudentsList = false

    // Call this after successfully creating a class
    func didCreateClass(_ classId: UUID) {
        self.lastCreatedClassId = classId
        self.shouldSelectClassInStudentsList = true
    }

    // Call this after selecting the class in the students list
    func didSelectClassInStudentsList() {
        self.shouldSelectClassInStudentsList = false
    }
}
