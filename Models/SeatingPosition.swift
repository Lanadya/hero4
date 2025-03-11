//
//  SeatingPosition.swift
//  hero4
//
//  Created by Nina Klee on 11.03.25.
//

import Foundation
import Foundation

struct SeatingPosition: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var studentId: UUID
    var classId: UUID
    var xPos: Int
    var yPos: Int

    init(id: UUID = UUID(),
         studentId: UUID,
         classId: UUID,
         xPos: Int,
         yPos: Int) {

        self.id = id
        self.studentId = studentId
        self.classId = classId
        self.xPos = xPos
        self.yPos = yPos
    }
}
