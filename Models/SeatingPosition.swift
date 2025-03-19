//
//  SeatingPosition.swift
//  hero4
//
//  Created by Nina Klee on 11.03.25.
//

import Foundation

struct SeatingPosition: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var studentId: UUID
    var classId: UUID
    var xPos: Int
    var yPos: Int
    var lastUpdated: Date
    var isCustomPosition: Bool  // Zeigt an, ob die Position manuell gesetzt wurde

    init(id: UUID = UUID(),
         studentId: UUID,
         classId: UUID,
         xPos: Int,
         yPos: Int,
         lastUpdated: Date = Date(),
         isCustomPosition: Bool = false) {

        self.id = id
        self.studentId = studentId
        self.classId = classId
        self.xPos = xPos
        self.yPos = yPos
        self.lastUpdated = lastUpdated
        self.isCustomPosition = isCustomPosition
    }
}
