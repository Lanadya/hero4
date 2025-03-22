import Foundation

struct Rating: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var studentId: UUID
    var classId: UUID
    var date: Date
    var value: RatingValue?  // Optional, falls keine Bewertung (aber anwesend)
    var isAbsent: Bool       // Markiert Abwesenheit
    var isArchived: Bool
    var createdAt: Date

    init(id: UUID = UUID(),
         studentId: UUID,
         classId: UUID,
         date: Date = Date(),
         value: RatingValue? = nil,
         isAbsent: Bool = false,
         isArchived: Bool = false,
         createdAt: Date = Date()) {

        self.id = id
        self.studentId = studentId
        self.classId = classId
        self.date = date
        self.value = value
        self.isAbsent = isAbsent
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
