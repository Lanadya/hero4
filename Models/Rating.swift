import Foundation

struct Rating: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var studentId: UUID
    var classId: UUID
    var date: Date
    var value: RatingValue?
    var isAbsent: Bool
    var isArchived: Bool
    var createdAt: Date
    var schoolYear: String  // Neues Feld für das Schuljahr

    init(id: UUID = UUID(),
         studentId: UUID,
         classId: UUID,
         date: Date = Date(),
         value: RatingValue? = nil,
         isAbsent: Bool = false,
         isArchived: Bool = false,
         createdAt: Date = Date(),
         schoolYear: String) {  // Konstruktor mit schoolYear erweitern

        self.id = id
        self.studentId = studentId
        self.classId = classId
        self.date = date
        self.value = value
        self.isAbsent = isAbsent
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.schoolYear = schoolYear
    }
}
